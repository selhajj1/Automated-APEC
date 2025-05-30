#!/bin/bash

# Define the input file
#Job=$(basename "$(find . -maxdepth 1 -type f -name '*.input' | head -n 1)" .input)
input_file=new_coordinates_tk.xyz

cp $input_file ${input_file}_bak

# Create a temporary output file
temp_file=$(mktemp)

# Initialize a counter to keep track of lines after the identified line
counter=0

# Read the input file line by line
while IFS= read -r line; do
    # Split the line into columns
    columns=($line)

    # Check if column 6 is 4004
    if [ "${columns[5]}" == "4004" ]; then
        # Modify the current line with specific spacing
        modified_line="  ${columns[0]}  ${columns[1]}    ${columns[2]}   ${columns[3]}   ${columns[4]}  ${columns[5]}  ${columns[6]}  ${columns[9]}"
        echo "$modified_line" >> "$temp_file"

        # Set the counter to 2 to modify the next two lines
        counter=2
    elif [ $counter -gt 0 ]; then
        # Modify the next two lines by deleting only the 7th column
        modified_line="  ${columns[0]}  ${columns[1]}    ${columns[2]}   ${columns[3]}   ${columns[4]}  ${columns[5]}"
        for ((i=7; i<${#columns[@]}; i++)); do
            modified_line="$modified_line  ${columns[i]}"
        done
        echo "$modified_line" >> "$temp_file"

        # Decrement the counter
        counter=$((counter - 1))
    else
        # If no modification is needed, write the line as is
        echo "$line" >> "$temp_file"
    fi
done < "$input_file"

# Overwrite the original input file with the modified content
mv "$temp_file" "$input_file"

echo "Modifications complete. The file '$input_file' has been updated."

