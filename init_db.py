import os
import sqlite3

entries = os.listdir(".")

# Find and sort step directories
step = 0
step_dirs = [d for d in entries if d.startswith("Step_")]
if len(step_dirs) != 0:
    step_dirs.sort(key=lambda x: int(x.split("_")[1]))
    step = step_dirs[-1].split("_")[1]
else:
    step = 0

print(f"Creating APEC_{step} Database")

current_directory = os.path.dirname(os.path.abspath(__file__))

conn = sqlite3.connect(f"{current_directory}/databases/APEC_{step}.db")

c = conn.cursor()

c.execute(
    """
CREATE TABLE IF NOT EXISTS APEC_STATUS (
    ID INTEGER PRIMARY KEY,
    SCRIPT TEXT NOT NULL,
    STATUS TEXT DEFAULT "NOT_RUN",
    RETRIES DEFAULT 0,
    START_DATE DATE,
    END_DATE date,
    TIME_TAKEN INTEGER
)
"""
)

# Check if data already exists
c.execute("SELECT COUNT(*) FROM APEC_STATUS")
count = c.fetchone()[0]

if count == 0:
    print(f"Adding scripts for Step {step}")
    if int(step) == 0:
        c.execute(
            """
            INSERT INTO APEC_STATUS (SCRIPT) VALUES 
            ('New_APEC.sh'), 
            ('NewStep.sh'), 
            ('Solvent_box.sh'), 
            ('MD_NVT.sh'), 
            ('MD_ASEC.sh'), 
            ('MD_2_QMMM.sh'), 
            ('Molcami_OptSCF.sh'), 
            ('ASEC.sh'), 
            ('finalPDB_mod.sh'), 
            ('fitting_ESPF.sh'),
            ('Next_Iteration.sh')
            """
        )
    elif int(step) > 0:
        c.execute(
            """
            INSERT INTO APEC_STATUS (SCRIPT) VALUES 
            ('MD_NVT.sh'),
            ('MD_ASEC.sh'),
            ('MD_2_QMMM.sh'),
            ('Molcami_direct_b3lyp.sh'),
            ('ASEC_direct_b3lyp.sh'),
            ('finalPDB_mod.sh'),
            ('fitting_ESPF.sh'),
            ('Next_Iteration.sh')
            """
        )
else:
    print("Data already exists, skipping insertion.")

rows = c.fetchall()

for row in rows:
    print(row)

conn.commit()
conn.close()
