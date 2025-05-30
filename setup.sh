#!/bin/bash

read -p "Enter the project name: " project_name

if [ ! -d "$project_name" ]; then
    mkdir "$project_name"
    echo "Folder '$project_name' created."
else
    echo "Folder '$project_name' already exists."
fi

cd "$project_name" && echo "Now in folder '$project_name'"
# Step 1: Clone APEC code
git clone https://github.com/selhajj1/Automated-APEC.git || { echo "Failed to clone repository"; exit 1; }
echo "step 1 done"

# Step 2: Loading the needed python version
module load python/3.13.3 || { echo "Failed to load Python module"; exit 1; }
echo "step 2 done"

python3 -m pip install virtualenv
# Step 3: Create a virtual environment in the project directory using virtualenv
cd Automated-APEC || { echo "Failed to change directory"; exit 1; }
echo "step 3a done"
mkdir -p logs/Step_0
env_name="APEC_$(whoami)_$(date +%s)"
virtualenv "$env_name" || { echo "Failed to create virtual environment"; exit 1; }
echo "step 3b done"

# Step 4: Activate the virtual environment
source "$env_name/bin/activate" || { echo "Failed to activate virtual environment"; exit 1; }
echo "step 4 done"

# Step 5: Install Python packages from requirements.txt
pip install -r requirements.txt || { echo "Failed to install Python packages"; exit 1; }
echo "step 5 done"

# Optional: If you want to deactivate the virtual environment when the script is done
# deactivate
