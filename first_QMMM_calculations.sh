#!/bin/bash

echo "Automated APEC-script: it does the first-QMMM-calculation of Step_0"
echo "APEC 3.0: written by Sarah Elhajj"
echo "Latest changes: July 2024"

module load vmd

# Get the current directory
CURRENT_DIR=$(pwd)

# Extract project name from 'parameters' file
Project=$(grep 'project_name' "$CURRENT_DIR/parameters" | awk '{print $2}')

# Define the log directory
LOG_DIR="$CURRENT_DIR/logs/Step_0"

# Function to run a script and handle retries
run_script() {
    local script="$1"
    local log_file="$LOG_DIR/$script.log"
    local success_msg="$2"
    local retries="$3"
    python "$CURRENT_DIR/update_status.py" "$script" RUNNING $CURRENT_DIR
    local retry=0

    while [ $retry -lt $retries ]; do
        chmod +x $script
        ./"$script" >"$log_file" 2>&1
        if grep -iq "$success_msg" "$log_file"; then
            python "$CURRENT_DIR/update_status.py" "$script" PASSED $CURRENT_DIR
            return 0
        else
            python "$CURRENT_DIR/update_status.py" "$script" FAILED $CURRENT_DIR
            ((retry++))
        fi
    done
    return 1
}

# Define timeout and polling interval
TIMEOUT=$((120 * 60 * 60))
INTERVAL=$((10 * 60))

# Function to poll a script's execution
polling_loop() {
    local script="$1"
    local log_file="$LOG_DIR/$script.log"
    local start_time=$(date +%s)
    local end_time=$((start_time + TIMEOUT))
    python "$CURRENT_DIR/update_status.py" "$script" RUNNING $CURRENT_DIR
    chmod +x $script
    ./"$script" >"$log_file" 2>&1
    sleep 60
    local jobid="$(cat $2)"
    local username=$(whoami)

    while [[ $(date +%s) -lt $end_time ]]; do
        local output=$(squeue -u "$username")
        if echo "$output" | grep "$username" | grep -q "$jobid"; then
            echo "The username '$username' was found in the output of squeue."
            sleep "$INTERVAL"
        else
            if [ $# -eq 4 ]; then
                local out_file="$3"
                local success_msg="$4"
                if grep -iq "$success_msg" "$out_file"; then
                    python "$CURRENT_DIR/update_status.py" "$script" PASSED $CURRENT_DIR
                    return 0
                else
                    python "$CURRENT_DIR/update_status.py" "$script" FAILED $CURRENT_DIR
                    return 1
                fi
            fi
            python "$CURRENT_DIR/update_status.py" "$script" PASSED $CURRENT_DIR
            return 0
        fi
    done
    python "$CURRENT_DIR/update_status.py" "$script" FAILED $CURRENT_DIR
    return 1
}

restart_after_5_days() {
    local extension=$1
    local script=$2
    python "$CURRENT_DIR/update_status.py" "$script" RUNNING $CURRENT_DIR
    cd "${Project}_${extension}"
    local try_counter=0

    while [ $try_counter -lt 5 ]; do
        mkdir -p "try$try_counter"
        mv ./* "try$try_counter/" 2>/dev/null # Suppress errors for when moving into same directory
        cd "try$try_counter"
        latest_file=$(ls -1v ${Project}_${extension}.Final.xyz_* | tail -n 1)
        cp "$latest_file" "../${Project}_${extension}.xyz"
        cp amber99sb.prm molcas-job.sh "${Project}_${extension}.input" "${Project}_${extension}.Espf.Data" "${Project}_${extension}.key" ../
        cd ..
        sbatch molcas-job.sh | awk '{print $4}' >jobid
        local jobid="$(cat jobid)"
        local username=$(whoami)
        local INTERVAL=60
        local TIMEOUT=432000

        local start_time=$(date +%s)
        while true; do
            local current_time=$(date +%s)
            local elapsed=$((current_time - start_time))

            if [ "$elapsed" -ge "$TIMEOUT" ]; then
                echo "The script has timed out after 5 days."
                break
            fi
            
            local output=$(squeue -u "$username")
            if [[ $output == *"JOBID"* ]]; then
                echo "JOBID found, proceeding..."
                if echo "$output" | grep "$username" | grep -q "$jobid"; then
                    echo "The job ID '$jobid' was found in the output of squeue."
                    sleep "$INTERVAL"
                else
                    sleep 300
                    local out_file="$CURRENT_DIR/Step_0/calculations/${Project}_${extension}/${Project}_${extension}.out"
                    
                    if [ ! -f "$out_file" ]; then
                        echo "something is wrong: Output file $out_file not found. Exiting..."
                        exit 1
                    fi
                    if grep -iq "Happy landing!" "$out_file"; then
                        python "$CURRENT_DIR/update_status.py" "$script" PASSED $CURRENT_DIR
                        return 0 # Successful exit
                    else
                        echo "Try $try_counter failed. Moving to next try..."
                        break
                    fi
                  

                fi
            else
                echo "JOBID not found, sleeping for 2 minutes..."
                sleep 120
            fi
        done

        cd $CURRENT_DIR/Step_0/calculations/${Project}_${extension}
        ((try_counter++))
    done
}
    
# Change to the 'Step_0' directory
cd $CURRENT_DIR/Step_0

# Run the scripts with error handling
run_script "MD_2_QMMM.sh" "Now run Molcami_OptSCF.sh to start the QM/MM calculations" 1 || exit 1
run_script "Molcami_OptSCF.sh" "Run ASEC.sh to generate the final coordinate file and submit" 1 || exit 1

# Poll the 'ASEC.sh' script
polling_loop "ASEC.sh" "$CURRENT_DIR/Step_0/calculations/${Project}_VDZP_Opt/jobid"

# Check for convergence in the calculations
cd $CURRENT_DIR/Step_0/calculations
if [ -f "${Project}_VDZP_Opt/${Project}_VDZP_Opt.out" ]; then
    if grep -iq "Happy landing!" "$CURRENT_DIR/Step_0/calculations/${Project}_VDZP_Opt/${Project}_VDZP_Opt.out"; then
        python "$CURRENT_DIR/update_status.py" "ASEC.sh" PASSED $CURRENT_DIR
    else
        restart_after_5_days VDZP_Opt ASEC.sh
    fi
else
    restart_after_5_days VDZP_Opt ASEC.sh
fi

cd $CURRENT_DIR/Step_0/calculations
# Continue with more scripts
run_script "finalPDB_mod.sh" "Continue with: fitting_ESPF.sh" 1 || exit 1
run_script "fitting_ESPF.sh" "Go to the main folder and continue with: Next_Iteration.sh" 1 || exit 1

cd $CURRENT_DIR/Step_0
run_script "Next_Iteration.sh" "Go to Step_1 and continue with \"MD_NVT.sh\"" 1 || exit 1
