#!/bin/bash

echo "Automated APEC-script: it do the first-MD-calculation of Step_0"
echo "APEC 3.0: written by Sarah Elhajj"
echo "Latest changes: July 2024"
module load vmd
CURRENT_DIR=$(pwd)
LOG_DIR="$CURRENT_DIR/logs/Step_0"
Project=$(grep 'project_name' "$CURRENT_DIR/parameters" | awk '{print $2}')
APEC_DATABASE="$CURRENT_DIR/databases/APEC_0.db"

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

initialize_run() {
    rm -r Step_0

    if [ ! -f "$APEC_DATABASE" ] || [ ! -s "$APEC_DATABASE" ]; then
        python init_db.py
    fi
}

polling_loop() {
    local script="$1"
    local -a success_msgs=("${!2}") # Indirect expansion for array of success messages
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

initialize_run

run_script "New_APEC.sh" "Folder Step_0 created! cd Step_0/, then ./NewStep.sh" && cd Step_0 || exit 1
sed -i 's/^Initial.*/Initial NO/' Infos.dat
run_script "NewStep.sh" "Continue executing: Solvent_box.sh" || exit 1

TIMEOUT=$((120 * 60 * 60))
INTERVAL=$((10))
Solvent_box_success_messages=("Steepest Descents converged to")
Solvent_box_files_to_check=("Dynamic/Minimization/output/md.log")
polling_loop "Solvent_box.sh" Solvent_box_success_messages[@] Solvent_box_files_to_check[@] || exit 1

TIMEOUT=$((120 * 60 * 60))
INTERVAL=$((10 * 60))

NVT_success_messages=("Finished")
NVT_files_to_check=("Dynamic/output/md.log")
polling_loop "MD_NVT.sh" NVT_success_messages[@] NVT_files_to_check[@] || exit 1

NVT_temperature_averaged=$(grep -A15 "A V E R A G E S" "Dynamic/output/md.log" | grep -A1 "Temperature" | tail -1 | awk '{print $5}')
NVT_temperature_original=$(grep 'NVT_production_temperature' "$CURRENT_DIR/parameters" | awk '{print $2}')
decimal_temperature=$(echo "$NVT_temperature_averaged" | awk '{printf "%.0f\n", $1}')
temperature_threshold=$(awk -v t="$NVT_temperature_original" 'BEGIN {print t + 10}')

if awk -v t1="$decimal_temperature" -v t2="$NVT_temperature_original" -v threshold="$temperature_threshold" 'BEGIN { exit !(t1 < t2 || (t1 >= t2 && t1 <= threshold)) }'; then
    echo "The temperature is less than NVT temperature or within 10 degrees above"
    python $CURRENT_DIR/update_status.py "MD_NVT.sh" PASSED $CURRENT_DIR
else
    echo "The temperature is greater than 10 degrees above the NVT temperature"
    python $CURRENT_DIR/update_status.py "MD_NVT.sh" FAILED $CURRENT_DIR
fi

system_total_charge_tolerance=0.005
system_total_charge_value=$(grep -i "System Total charge:" "$CURRENT_DIR/Step_0/Dynamic/output/md.log" | awk '{print $4}')
check_value_within_tolerance "$system_total_charge_value" "$system_total_charge_tolerance" "MD_NVT.sh"

python $CURRENT_DIR/update_status.py "MD_ASEC.sh" RUNNING $CURRENT_DIR

CHR=$(grep "\[" $CURRENT_DIR/Step_0/Dynamic/${Project}_box_sol.ndx | nl | grep "CHR" | head -1 | awk '{print $1 -1 }')
SOL=$(grep "\[" $CURRENT_DIR/Step_0/Dynamic/${Project}_box_sol.ndx | nl | grep "SOL" | head -1 | awk '{print $1 -1}')

cd $CURRENT_DIR/Step_0

# Save the output of MD_ASEC.sh to md_asec.log
./MD_ASEC.sh <<EOF >${LOG_DIR}/MD_ASEC.sh.log
$CHR
$SOL
$CHR
$SOL
EOF

python $CURRENT_DIR/update_status.py "MD_ASEC.sh" PASSED $CURRENT_DIR

echo "main_final.sh finished successfully, please run main2_final.sh"
