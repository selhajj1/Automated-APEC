from chemspipy import ChemSpider
import os
import pandas as pd
 
cs = ChemSpider('<API_KEY>')
 
# Define the list of molecules
molecules = [
    "methane",
    "propan-2-one",
    "2-acetyloxybenzoic acid",
    "pentanal"
]
 
 
# Create a directory to save the SDF files
output_dir = "ChemSpider_molecule_structures"
os.makedirs(output_dir, exist_ok=True)
 
 
# Initialize lists to store information
molecule_names = []
common_names = []
formulas = []
molecular_weights = []
smiles_list = []
 
for molecule in molecules:
    print('Trying for ', molecule)
    compound = cs.search(molecule)
    if compound:
        print(molecule + ' found in ChemSpider database. Downloading...')
        compound = compound[0]
        print(compound.molecular_formula)
        print(compound.molecular_weight)
        print(compound.smiles)
        molecule_names.append(molecule)
        common_names.append(compound.common_name)
        formulas.append(compound.molecular_formula)
        molecular_weights.append(compound.molecular_weight)
        smiles_list.append(compound.smiles)
         
         
        # Write SDF to file
        molfile = open(os.path.join(output_dir, f'{molecule}.mol'), 'w')
        molfile.write(compound.mol_3d)
        molfile.close()
 
 
        print(f'Downloaded structure for {molecule}')
    else:
        print(f'No information found for {molecule}')
 
# Create DataFrame
data = {
    'Molecule Name': molecule_names,
    'Common Name': common_names,
    'Formula': formulas,
    'Molecular Weight': molecular_weights,
    'SMILES': smiles_list
}
df = pd.DataFrame(data)
 
# Export DataFrame as CSV and Excel files
df.to_csv('molecule_info.csv', index=False)
df.to_excel('molecule_info.xlsx', index=False)
 
print('All structures downloaded and information saved successfully!')