import pandas as pd
from sqlalchemy import create_engine
from dotenv import load_dotenv
import os  

load_dotenv()
db_url = os.getenv("DATABASE_URL")
engine = create_engine(db_url)

ab_test = pd.read_sql_query("SELECT * FROM ab_tests;", engine)
events = pd.read_sql_query("SELECT * FROM events;", engine)
sessions = pd.read_sql_query("SELECT * FROM sessions;", engine)
users = pd.read_sql_query("SELECT * FROM users;", engine)

# # 26. Приведи типы дат/времени, проверь пропуски, сделай базовый EDA (describe + распределения amounts).

users["registration_date"] = pd.to_datetime(users["registration_date"], errors="coerce")
events["event_time"] = pd.to_datetime(events["event_time"], errors="coerce")
sessions["session_start"] = pd.to_datetime(sessions["session_start"], errors="coerce")
sessions["session_end"] = pd.to_datetime(sessions["session_end"], errors="coerce")
print("---ab_test---\n",ab_test.dtypes)
print("---events---\n",events.dtypes)
print("---sessions---\n",sessions.dtypes)
print("---users---\n",users.dtypes)

def missing_report(df, name):
    m = df.isna().sum().sort_values(ascending = False)
    m = m[m>0]
    print(f"\n {name}: missing values")
    if len(m) == 0:
        print("No missing values")
    else:
        print(m)

print(missing_report(users, "users"))
print(missing_report(events,"events"))
print(missing_report(sessions,"sessions"))
print(missing_report(ab_test,"ab_test"))

print(sessions["revenue"].describe())
print(events["amount"].describe())
print(events.groupby("event_type")["amount"].describe())

# 27. Собери **daily KPI-таблицу**: `date, DAU, purchases_sum, deposits_sum, revenue_sum, ARPDAU`.

dau = sessions.groupby(sessions["session_start"].dt.date)["user_id"].nunique().reset_index(name="unique_users")
print(dau)
# 28. Построй графики:

# * DAU по дням
# * revenue по дням
# * rolling 7d revenue (поверх)

# 29. Cohort retention в pandas (heatmap): когорты по неделям регистрации, retention по неделям жизни.
# 30. Посчитай по каждому user_id: `first_session_date`, `first_purchase_date`, `days_to_first_purchase`.
# 31. Сравни метрики по странам: DAU, ARPDAU, payer conversion (таблица + bar chart).
# 32. Построй “фанель” в pandas: registration → session → purchase (конверсия по источникам).
