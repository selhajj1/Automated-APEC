# Define your list
amino_acids = [
    "ALA", "ARG", "ASN", "ASP", "CYS", "GLN", "GLU", "GLY", "HIS", "ILE", "LEU", "LYS", "MET", "PHE", "PRO",
    "SER", "THR", "TRP", "TYR", "VAL", "HOH"
]

# Specify the file path
pdb_path = '/data/PHO_WORK/selhajj1/QMMM/automation_Sarah/1n9lAPEC.pdb'  # Replace with your file path

# Initialize counters
total_lines = 0
green_lines = 0
red_lines = 0

line_number = 0  # Initialize line_number before the try block

try:
    # Read the file and check if elements in the 4th column are in your list
    with open(pdb_path, 'r') as file:
        for line_number, line in enumerate(file, start=1):
            total_lines += 1
            # Assuming columns are space-separated, modify the split() method accordingly
            columns = line.split()

            # Check if there are at least 4 columns
            if len(columns) >= 4:
                # Check if the element in the 4th column is in your list
                if columns[3] in amino_acids:
                    green_lines += 1
                else:
                    print(f"Red line (unrecognized residue) in line {line_number}: {line.strip()} {' '.join(columns[3:]) if len(columns) >= 4 else ''}")
                    red_lines += 1
            else:
                print(f"Invalid line format in line {line_number}: {line.strip()}")

    # Calculate percentages
    percentage_green = (green_lines / total_lines) * 100 if total_lines > 0 else 0
    percentage_red = (red_lines / total_lines) * 100 if total_lines > 0 else 0

    # Print the counts and percentages
    print(f"Total lines: {total_lines}")
    print(f"Green lines (recognized residues): {green_lines} ({percentage_green:.2f}%)")
    print(f"Red lines (unrecognized residues): {red_lines} ({percentage_red:.2f}%)")

except FileNotFoundError:
    print(f"File not found: {pdb_path}")
except Exception as e:
    print(f"An error occurred: {e}")
