import sys
import sqlite3
import os

script_name = sys.argv[1]
status = sys.argv[2].upper()
current_file_path = sys.argv[3].strip()

print(current_file_path)

entries = os.listdir(current_file_path)
print(entries)
# Find and sort step directories
step_dirs = [d for d in entries if d.startswith("Step")]
print(step_dirs)
step_dirs.sort(key=lambda x: int(x.split('_')[1]))
latest_folder = step_dirs[-1] if step_dirs else None

step = 0
print(step_dirs)
if latest_folder is None:
    step = 0
else:
    file_path = os.path.join(current_file_path, latest_folder, "Infos.dat")
    print(file_path)
    if not os.path.exists(file_path):
        step = 0
    else:
        with open(file_path, "r") as file:
            for line in file:
                columns = line.strip().split()

                if len(columns) > 1 and columns[0] == "Step":
                    step = int(columns[1].strip())
                    break

current_directory = os.path.dirname(os.path.abspath(__file__))
db_file = f"{current_directory}/databases/APEC_{step}.db"

if not os.path.exists(db_file) or os.path.getsize(db_file) == 0:
    conn = sqlite3.connect(f"{current_directory}/databases/APEC_{step-1}.db")
else:
    conn = sqlite3.connect(db_file)
c = conn.cursor()

if status == "RUNNING":
    c.execute(
        "UPDATE APEC_STATUS SET STATUS = 'RUNNING', RETRIES = RETRIES + 1, START_DATE = datetime('now') WHERE SCRIPT = ?",
        (script_name,),
    )
elif status == "PASSED":
    c.execute(
        "UPDATE APEC_STATUS SET STATUS = 'PASSED', END_DATE = datetime('now'), TIME_TAKEN = (julianday(datetime('now')) - julianday(START_DATE)) * 1440 WHERE SCRIPT = ?",
        (script_name,),
    )
elif status == "FAILED":
    c.execute(
        "UPDATE APEC_STATUS SET STATUS = 'FAILED', RETRIES = RETRIES + 1, END_DATE = datetime('now'), TIME_TAKEN = (julianday(datetime('now')) - julianday(START_DATE)) * 1440 WHERE SCRIPT = ?",
        (script_name,),
    )

conn.commit()
conn.close()

