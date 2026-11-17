import pandas as pd
from sqlalchemy import create_engine
from sqlalchemy.engine import URL
from getpass import getpass

# Load Excel data
df = pd.read_excel("data/task_2_data_ex.xlsx")

# Connect to MySQL
password = getpass("MySQL password: ")

url = URL.create(
    "mysql+pymysql",
    username="root",
    password=password,
    host="localhost",
    database="pandas_bom_task"
)

engine = create_engine(url)

# Upload data to MySQL
df.to_sql("bom_raw", engine, if_exists="replace", index=False)

print("Uploaded rows:", len(df))

engine.dispose()