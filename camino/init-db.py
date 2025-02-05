import sqlite3
import os
entries = os.listdir(".")
# Find and sort step directories
step_dirs = [d for d in entries if os.path.isdir(d) and d.startswith("Step")]
step_dirs.sort(key=lambda x: int(x.split('_')[1]))
latest_folder = step_dirs[-1] if step_dirs else None

step = 0
if latest_folder is None:
    step = 0
else:
    file_path = os.path.join(latest_folder, "Infos.dat")

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
# Connect to a database (or create one if it doesn't exist)
conn = sqlite3.connect(f"{current_directory}/databases/APEC_{step}.db")
c = conn.cursor()
# Create a new table
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

if step == 0:
    c.execute(
        "INSERT INTO APEC_STATUS (SCRIPT) VALUES ('New_APEC.sh'), ('NewStep.sh'), ('Solvent_box.sh'), ('MD_NPT.sh'), ('MD_NVT.sh'), ('MD_ASEC.sh'), ('MD_2_QMMM.sh'), ('Molcami_OptSCF.sh'), ('ASEC.sh'), ('Molcami2_mod.sh'), ('1st_to_2nd_mod.sh'), ('2nd_to_3rd_mod.sh'), ('sp_to_opt_VDZP_mod.sh'), ('finalPDB_mod.sh'), ('fitting_ESPF.sh'),('Next_Iteration.sh')"
    )
elif step == 1:
    c.execute(
        "INSERT INTO APEC_STATUS (SCRIPT) VALUES ('MD_NVT.sh'),('MD_ASEC.sh'),('MD_2_QMMM.sh'),('Molcami_direct_CASSCF.sh'),('ASEC_direct_CASSCF.sh'),('finalPDB_mod.sh'),('fitting_ESPF.sh'),('Next_Iteration.sh')"
    )
elif step == 2:
    c.execute(
        "INSERT INTO APEC_STATUS (SCRIPT) VALUES ('MD_NVT.sh'),('MD_ASEC.sh'),('MD_2_QMMM.sh'),('Molcami_direct_CASSCF.sh'),('ASEC_direct_CASSCF.sh'),('finalPDB_mod.sh'),('fitting_ESPF.sh'),('Next_Iteration.sh')"
    )

c.execute("SELECT * FROM APEC_STATUS")
rows = c.fetchall()

for row in rows:
    print(row)


# Commit changes and close connection

conn.commit()
conn.close()
