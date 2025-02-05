# Define your list
amino_acids = [
    "ALA",
    "ARG",
    "ASN",
    "ASP",
    "CYS",
    "GLN",
    "GLU",
    "GLY",
    "HIS",
    "ILE",
    "LEU",
    "LYS",
    "MET",
    "PHE",
    "PRO",
    "SER",
    "THR",
    "TRP",
    "TYR",
    "VAL",
    "HOH"
]

# Specify the file path
pdb_path = '/data/PHO_WORK/selhajj1/QMMM/automation_Sarah/4eep_correct.pdb'  # Replace with your file path

# Initialize counters
total_lines = 0
green_lines = 0
red_lines = 0

# Read the file and check if elements in the 4th column are in your list
with open(pdb_path, 'r') as file:
    for line in file:
        total_lines += 1
        # Assuming columns are space-separated, modify the split() method accordingly
        columns = line.split()

        # Check if there are at least 4 columns
        if len(columns) >= 4:
            # Check if the element in the 4th column is in your list
            if columns[3] in amino_acids:
                print(f"Element {columns[3]} in the 4th column is in your list.")
                green_lines += 1
            else:
                print(f"The following residue was detected but not recognized: {columns[3]}. If this residue is not important, please delete it from your pdb.")
                red_lines += 1
        else:
            print(f"Invalid line format: {line.strip()}")

# Calculate percentages
percentage_green = (green_lines / total_lines) * 100 if total_lines > 0 else 0
percentage_red = (red_lines / total_lines) * 100 if total_lines > 0 else 0

# Print the counts and percentages
print(f"Total lines: {total_lines}")
print(f"Green lines (recognized residues): {green_lines} ({percentage_green:.2f}%)")
print(f"Red lines (unrecognized residues): {red_lines} ({percentage_red:.2f}%)")
