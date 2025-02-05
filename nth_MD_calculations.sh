#!/bin/bash
echo "Automated APEC-script: it does the nth-MD-calculation in an iterated way: Step_1 --> Step_5"
echo "APEC 2.0: written by Sarah Elhajj"
echo "Latest changes: July 2024"
module load vmd
# Current working directory
CURRENT_DIR=$(pwd)
step_id=$1

# Retrieve project name from parameters file
Project=$(grep 'project_name' "$CURRENT_DIR/parameters" | awk '{print $2}')

# Log directory setup
LOG_DIR="$CURRENT_DIR/logs/Step_${step_id}"
mkdir -p $LOG_DIR

# Database setup
APEC_DATABASE="$CURRENT_DIR/databases/APEC_${step_id}.db"

# Function to run a script and log its status
run_script() {
    local script="$1"
    local log_file="$LOG_DIR/$script.log"
    local success_msg="$2"
    python $CURRENT_DIR/update_status.py $script RUNNING $CURRENT_DIR
    retry=0
    while [ $retry -lt 2 ]; do
        ./$script >$log_file 2>&1
        if grep -i "$success_msg" $log_file; then
            python $CURRENT_DIR/update_status.py $script PASSED $CURRENT_DIR
            return 0
        else
            python $CURRENT_DIR/update_status.py $script FAILED $CURRENT_DIR
            ((retry++))
        fi
    done
    return 1
}

# Function to initialize the run
initialize_run() {

    if [ ! -f "$APEC_DATABASE" ] || [ ! -s "$APEC_DATABASE" ]; then
        python init_db.py
    fi
}

# Function for a polling loop to check script conditions
polling_loop() {
    local script="$1"
    local -a success_msgs=("${!2}")   # Indirect expansion for array of success messages
    local -a files_to_check=("${!3}") # Indirect expansion for array of files
    local log_file="$LOG_DIR/$script.log"
    local start_time=$(date +%s)
    local end_time=$((start_time + TIMEOUT))
    local conditions_met=($(printf '0%.s' "${success_msgs[@]}")) # Array to keep track of which conditions are met
    python $CURRENT_DIR/update_status.py $script RUNNING $CURRENT_DIR
    ./$script >$log_file 2>&1
    while [[ $(date +%s) -lt $end_time ]]; do
        local all_conditions_met=true
        for i in "${!success_msgs[@]}"; do # Loop over indices
            if [[ "${conditions_met[$i]}" -eq 0 ]] && grep -qi "${success_msgs[$i]}" "${files_to_check[$i]}"; then
                conditions_met[$i]=1 # Mark condition as met
                echo "Condition met: ${success_msgs[$i]}"
            fi
            if [[ "${conditions_met[$i]}" -eq 0 ]]; then
                all_conditions_met=false
            fi
        done
        if $all_conditions_met; then
            python $CURRENT_DIR/update_status.py $script PASSED $CURRENT_DIR
            echo "All conditions met, exiting loop."
            return 0
        else
            echo "Not all conditions met, waiting for next check..."
            sleep $INTERVAL
        fi
    done
    python $CURRENT_DIR/update_status.py $script FAILED $CURRENT_DIR
    return 1
}

check_value_within_tolerance() {
    local value=$1
    local tolerance=$2
    local script_name=$3

    if [[ "$value" == "0.000" ]]; then
        python $CURRENT_DIR/update_status.py "$script_name" PASSED $CURRENT_DIR
    else
        if awk "BEGIN {exit !($value >= -$tolerance && $value <= $tolerance)}"; then
            python $CURRENT_DIR/update_status.py "$script_name" PASSED $CURRENT_DIR
        else
            if awk "BEGIN {exit !($value > $tolerance)}"; then
                echo "The system total charge value is greater than the tolerance range"
            else
                echo "The system total charge value is less than the negative tolerance range"
            fi
            python $CURRENT_DIR/update_status.py "$script_name" FAILED $CURRENT_DIR
        fi
    fi
}

# Initialize run
initialize_run

# Change directory to step specific folder
cd $CURRENT_DIR/Step_${step_id}

# Timeout and interval setup
TIMEOUT=$((120 * 60 * 60))
INTERVAL=$((10 * 60))

# Success messages and files to check for NVT
NVT_success_messages=("Finished")
NVT_files_to_check=("Dynamic/output/md.log")

# Execute polling loop for MD_NVT.sh
polling_loop "MD_NVT.sh" NVT_success_messages[@] NVT_files_to_check[@] || exit 1

# Temperature checks for NVT
NVT_temperature_averaged=$(grep -A15 "A V E R A G E S" "Dynamic/output/md.log" | grep -A1 "Temperature" | tail -1 | awk '{print $5}')
NVT_temperature_original=$(grep 'NVT_production_temperature' "$CURRENT_DIR/parameters" | awk '{print $2}')
decimal_temperature=$(echo "$NVT_temperature_averaged" | awk '{printf "%.0f\n", $1}')
temperature_threshold=$(awk -v t="$NVT_temperature_original" 'BEGIN {print t + 10}')

# Temperature threshold check
if awk -v t1="$decimal_temperature" -v t2="$NVT_temperature_original" -v threshold="$temperature_threshold" 'BEGIN { exit !(t1 < t2 || (t1 >= t2 && t1 <= threshold)) }'; then
    echo "The temperature is less than NVT temperature or within 10 degrees above"
    python $CURRENT_DIR/update_status.py "MD_NVT.sh" PASSED $CURRENT_DIR
else
    echo "The temperature is greater than 10 degrees above the NVT temperature"
    python $CURRENT_DIR/update_status.py "MD_NVT.sh" FAILED $CURRENT_DIR
fi

system_total_charge_tolerance=0.005
system_total_charge_value=$(grep -i "System Total charge:" "$CURRENT_DIR/Step_${step_id}/Dynamic/output/md.log" | awk '{print $4}')
check_value_within_tolerance "$system_total_charge_value_1" "$system_total_charge_tolerance" "MD_NVT.sh"

# Update status for MD_ASEC.sh
python $CURRENT_DIR/update_status.py "MD_ASEC.sh" RUNNING $CURRENT_DIR

# Get CHR and SOL values
CHR=$(grep "\[" $CURRENT_DIR/Step_${step_id}/Dynamic/${Project}_box_sol.ndx | nl | grep "CHR" | head -1 | awk '{print $1 -1 }')
SOL=$(grep "\[" $CURRENT_DIR/Step_${step_id}/Dynamic/${Project}_box_sol.ndx | nl | grep "SOL" | head -1 | awk '{print $1 -1}')

# Change directory for MD_ASEC.sh execution
cd $CURRENT_DIR/Step_${step_id}

# Execute MD_ASEC.sh and save output to log
./MD_ASEC.sh <<EOF >${LOG_DIR}/MD_ASEC.sh.log
$CHR
$SOL
$CHR
$SOL
EOF

# Update status for MD_ASEC.sh
python $CURRENT_DIR/update_status.py "MD_ASEC.sh" PASSED $CURRENT_DIR
