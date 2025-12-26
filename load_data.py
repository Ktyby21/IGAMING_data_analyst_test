import os   
import pathlib
import csv
from dotenv import load_dotenv
import psycopg

load_dotenv()

BASE_DIR = pathlib.Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
SCHEMA_PATH = DATA_DIR / "schema.sql"

CSV_TO_TABLE = {
    "users.csv":"users",
    "sessions.csv":"sessions",
    "events.csv":"events",
    "ab_tests.csv":"ab_tests",
}

def sniff_delimiter(path: pathlib.Path) -> str:
    sample = path.read_text(encoding="utf-8",errors= "ignore")[:4096]
    try:
        dialect = csv.Sniffer().sniff(sample, delimiters=[",",";","\t","|"])
        return dialect.delimiter
    except Exception:
        return ","

def main() -> None:
    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        raise RuntimeError("DATABASE_URL не найден. Создай .env и укажи строку подключения.")

    schema_sql = SCHEMA_PATH.read_text(encoding="utf-8")

    with psycopg.connect(db_url) as conn:
        conn.execute("SET client_min_messages TO WARNING;")
        conn.execute(schema_sql)
        conn.commit()
        print("✅ schema.sql применён")

        for csv_name, table in CSV_TO_TABLE.items():
            csv_path = DATA_DIR / csv_name
            if not csv_path.exists():
                print(f"⚠️ пропущен {csv_name} (нет файла)")
                continue

            delim = sniff_delimiter(csv_path)
            copy_sql = f"COPY {table} FROM STDIN WITH (FORMAT CSV, HEADER TRUE, DELIMITER '{delim}')"

            with conn.cursor() as cur, csv_path.open("r", encoding="utf-8",errors="ignore") as f:
                with cur.copy(copy_sql) as copy:
                    for line in f:
                        copy.write(line)
            conn.commit()
            print(f"✅ загружено {csv_name} -> {table} (delimiter='{delim}')")
    print("🎉 Готово")

if __name__ == "__main__":
    main()
