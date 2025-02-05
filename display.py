from termcolor import colored

import sqlite3

import os


entries = os.listdir(".")


# Find and sort step directories
step = 0
step_dirs = [d for d in entries if d.startswith("Step_")]
if len(step_dirs) != 0:
    step_dirs.sort(key=lambda x: int(x.split("_")[1]))
    step = step_dirs[-1].split("_")[1]
else:
    step = 0

current_directory = os.path.dirname(os.path.abspath(__file__))

print(f"Current step: {step}")

db_file = f"{current_directory}/databases/APEC_0.db"

conn = sqlite3.connect(db_file)

cursor = conn.cursor()

cursor.execute(
    "SELECT SCRIPT, STATUS, RETRIES, START_DATE, END_DATE, TIME_TAKEN FROM  'APEC_STATUS' "
)

rows = cursor.fetchall()
conn.close()

print(
    "{:<30} {:<10} {:<10} {:<20} {:<20} {:<20}".format(
        "SCRIPT", "STATUS", "RETRIES", "START_DATE", "END_DATE", "TIME_TAKEN(mins)"
    )
)

for row in rows:
    script, status, retries, start_date, end_date, time_taken = [
        "" if x is None else x for x in row
    ]

    formatted_row = "{:<30} {:<10} {:<10} {:<20} {:<20} {:<20}".format(
        script,
        status,
        retries,
        start_date,
        end_date,
        round(0 if time_taken == "" else time_taken, 2),
    )

    if status == "PASSED":
        color = "green"

    elif status == "FAILED":
        color = "red"

    elif status == "RUNNING":
        color = "yellow"

    else:
        color = "grey"

    print(colored(formatted_row, color))
