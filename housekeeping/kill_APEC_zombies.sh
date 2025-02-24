#!/bin/bash
FILE_LIST='filelist.txt'
NOW=$(date +%s)
AGE=$((2*24*60*60))
username=$(whoami)
while IFS= read -r line
do
    for pid in $(pgrep -f -u "$username" "$line" ) 
    do
        start_time=$(ps -o lstart= -p "$pid" | awk '{print $3, $2, $5, $4}')
        start_time_seconds=$(date -d "$start_time" +%s)
        duration=$((NOW - start_time_seconds))
        if [ "$duration" -ge "$AGE" ]; then
            echo "Killing process $pid that has been running for more than 2 days."
            kill "$pid" 
        else
            echo "Process $pid has not been running for more than 2 days."
        fi
    done
done < "$FILE_LIST"
