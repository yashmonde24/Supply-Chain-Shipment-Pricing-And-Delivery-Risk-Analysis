
import os
import re
import pandas as pd
from sqlalchemy import create_engine, text
from google import genai
from google.genai import types
from dotenv import load_dotenv 
from pathlib import Path
import time

loaded = load_dotenv(override=True)

# Connect Database and Load Data 
 
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")
DB_NAME = os.getenv("DB_NAME")

engine = create_engine(
    f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)

# LLM Connection 

client = genai.Client()  # reads GEMINI_API_KEY from environment
MODEL = "gemini-3.5-flash-lite" # LLM model name 

response = client.models.generate_content(
    model="gemini-3.5-flash-lite" \
    "",
    contents="Hello! Confirm that you can read this request.",
)

print("API Check Response:", response.text)

time.sleep(2) # Time Delay (2) : Pause after startup check so initial quota resets


TABLE_NAME = "clean_shipment_pricing" # Table name , exists in Database

# Fetch Schema from Database 

def get_table_schema(table_name: str) -> str:
    query = text("""
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_name = :table_name
        ORDER BY ordinal_position;
    """)
    with engine.connect() as conn:
        result = conn.execute(query, {"table_name": table_name})
        columns = result.fetchall()
    schema_lines = [f"  - {col} ({dtype})" for col, dtype in columns]
    return f"Table: {table_name}\nColumns:\n" + "\n".join(schema_lines)


# Generate SQL query from natural language question 

def generate_sql(question: str, schema: str) -> str:
    system_prompt = f"""You are a PostgreSQL expert. Given a table schema and a
question, write ONE PostgreSQL SELECT query that answers it.

{schema}

Rules:
- Output ONLY the SQL query, no explanation, no markdown code fences.
- ONLY generate SELECT statements. Never DROP, DELETE, UPDATE, INSERT, ALTER, TRUNCATE, GRANT, or CREATE.
- Always add a LIMIT clause (default 20) unless the question asks for an aggregate (COUNT, AVG, SUM) that returns one row.
- Use column names exactly as given in the schema.
"""
    response = client.models.generate_content(
        model=MODEL,
        config=types.GenerateContentConfig(
            system_instruction=system_prompt,
            temperature=0.0,  # deterministic SQL generation, not creative writing
            max_output_tokens=500,
        ),
        contents=question,
    )
    sql = response.text.strip()
    # Strip markdown fences if the model adds them despite instructions
    sql = re.sub(r"^```sql\s*|\s*```$", "", sql, flags=re.MULTILINE).strip()
    return sql


# Validation  Layer : 

# - Validate the SQL before running it. 
# - Don't trust the LLM blindly. 
# - It re-checks the query text regardless of what the system prompt asked for.

BLOCKED_KEYWORDS = [
    "DROP", "DELETE", "UPDATE", "INSERT", "ALTER", "TRUNCATE",
    "GRANT", "REVOKE", "CREATE", "EXECUTE", "CALL", ";--", "/*"
]

def validate_sql(sql: str) -> tuple[bool, str]:
    sql_upper = sql.upper().strip()

    if not sql_upper.startswith("SELECT"):
        return False, "Rejected: query does not start with SELECT."

    for keyword in BLOCKED_KEYWORDS:
        if keyword in sql_upper:
            return False, f"Rejected: query contains blocked keyword '{keyword}'."

    # Reject multiple statements (semicolon followed by more content)
    if sql.strip().rstrip(";").count(";") > 0 :
        return False, "Rejected: multiple statements not allowed."

    return True, "OK"

# Execute the validated query

def run_query(sql: str) -> pd.DataFrame:
    with engine.connect() as conn:
        return pd.read_sql(text(sql), conn)


# Summarize the result in plain English

def summarize_result(question: str, result_df: pd.DataFrame) -> str:
    if result_df.empty:
        return "No results found for that question."

    result_text = result_df.head(20).to_string(index=False)
    response = client.models.generate_content(
        model=MODEL,
        config=types.GenerateContentConfig(
            system_instruction="Answer the user's question in 2-2 plain-Eh sentences based only on the query result data given. Do not invent numbers not present in the data.",
            temperature=0.2,
            max_output_tokens=300,
        ),
        contents=f"Question: {question}\n\nQuery result:\n{result_text}",
    )
    return response.text.strip()


#  Full pipeline: question in, answer out

def ask(question: str, verbose: bool = True) -> dict:
    schema = get_table_schema(TABLE_NAME)
    sql = generate_sql(question, schema)

    is_valid, reason = validate_sql(sql)
    if not is_valid:
        if verbose:
            print(f"Generated SQL blocked: {reason}\nSQL was: {sql}")
        return {"question": question, "sql": sql, "valid": False, "reason": reason}

    if verbose:
        print(f"\nGenerated SQL:\n{sql}\n")

    result_df = run_query(sql)

    time.sleep(2) # Time Delay (2) : Pause before sending results back to Gemini for summarization


    answer = summarize_result(question, result_df)

    if verbose:
        print(f"Answer: {answer}\n")
        print("Underlying data:")
        print(result_df.head(10).to_string(index=False))

    return {"question": question, "sql": sql, "valid": True, "answer": answer, "data": result_df}


# Interactive CLI

if __name__ == "__main__":

    print("Supply Chain Data Assistant — ask a question in plain English.")
    print("Type 'quit' to exit.\n")
    print("Example: 'Which vendor has the worst on-time delivery rate in Nigeria?'\n")

    while True:
        user_question = input("Your question: ").strip()
        if user_question.lower() in ("quit", "exit"):
            break
        if not user_question:
            continue
        try:
            ask(user_question)
        except Exception as e:
            print(f"Error: {e}")

        time.sleep(2) # Time Delay (3) : Pause before accepting the next user command
        print("-" * 60)