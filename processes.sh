#!/bin/bash

# Get the current directory
current_dir=$(pwd)
user=$(echo $USER | cut -c 1-6)

# Get the list of PIDs for the current user
pids=$(ps -ef | grep $user | grep ".sh" | grep -v "processes.sh" | grep -v grep | awk '{print $2}')

# Function to check if a process is under the current directory
check_and_kill() {
    local pid=$1
    local process_dir=$(pwdx $pid 2>/dev/null | awk -F': ' '{print $2}')
   
    if [[ "$process_dir" == "$current_dir"* ]]; then
        echo "Killing process $pid running in $process_dir"
        kill $pid
    fi
}

# Iterate over each PID and check if it should be killed
for pid in $pids; do
    check_and_kill $pid
done

echo "All processes running under $current_dir have been killed."
