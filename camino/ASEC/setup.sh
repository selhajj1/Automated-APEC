#!/bin/bash

# Step 1: Clone LAL code
git clone https://github.com/APEC-GSU/APEC-automation.git

# Step 2: Create a virtual environment in the project directory
cd APEC-automation
python3 -m venv APEC

# Step 3: Install Python packages from requirements.txt
source APEC/bin/activate
pip install -r requirements.txt

# Step 4: Activate virtual environment
echo "Virtual environment activated. To deactivate, run 'deactivate'."

