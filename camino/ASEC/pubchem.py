# Imports
import pubchempy as pcp
import os
import pandas as pd
import requests
 
# List of compounds to download
molecules = ['acetone', 'benzene', 'ethanol', 'methane', 'propane']
 
# Create output directories
sdf_dir = 'structures_sdf'
 
os.makedirs(sdf_dir, exist_ok=True)
 
# Lists to store properties
names = []
formulas = []
weights = []
 
# Function to download SDF
def get_sdf(cid):
    url = f'https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/{cid}/SDF?record_type=3d'
 
    response = requests.get(url)
    return response.text
 
# Loop through compounds
for mol in molecules:
 
    # Get PubChem data
    compound = pcp.get_compounds(mol, 'name')[0]
 
    names.append(compound.iupac_name)
    formulas.append(compound.molecular_formula)
    weights.append(compound.molecular_weight)
 
    # Download structures
    sdf = get_sdf(compound.cid)
 
    with open(f'{sdf_dir}/{mol}.sdf', 'w') as f:
        f.write(sdf)
 
# Create dataframe
data = {'Name': names,
'Formula': formulas,
'Weight': weights}
 
df = pd.DataFrame(data)
 
# Export CSV
df.to_csv('compounds.csv', index=False)
print(df)