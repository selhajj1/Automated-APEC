#!/bin/bash

# Function to convert timestamp to Unix timestamp
timestamp_to_unix() {
    date -d "$1" +"%s"
}

# Function to calculate time difference
calculate_time_difference() {
    start_timestamp=$(timestamp_to_unix "$1")
    stop_timestamp=$(timestamp_to_unix "$2")

    time_difference=$((stop_timestamp - start_timestamp))
    echo "Time difference for $3: $time_difference seconds"

    # Return the time difference for further calculations
    echo "$time_difference"
}

# Example usage with specified timestamp format
start_time_file1="Fri Oct 20 09:55:50 2023"
stop_time_file1="Fri Oct 20 11:52:38 2023"

start_time_file2="Fri Oct 20 18:21:57 2023"
stop_time_file2="Sun Oct 22 17:38:24 2023"

start_time_file3="Mon Oct 23 16:49:30 2023"
stop_time_file3="Mon Oct 23 29:35:16 2023"

start_time_file4="Tue Oct 24 13:43:16 2023"
stop_time_file4="Thu Oct 26 16:53:02 2023"

# Calculate time differences for each file
time_diff_file1=$(calculate_time_difference "$start_time_file1" "$stop_time_file1" "File 1")
time_diff_file2=$(calculate_time_difference "$start_time_file2" "$stop_time_file2" "File 2")
time_diff_file3=$(calculate_time_difference "$start_time_file3" "$stop_time_file3" "File 3")
time_diff_file4=$(calculate_time_difference "$start_time_file4" "$stop_time_file4" "File 4")

# Calculate total time difference
total_time_difference=$((time_diff_file1 + time_diff_file2 + time_diff_file3 + time_diff_file4))
echo "Total time difference for all files: $total_time_difference seconds"
