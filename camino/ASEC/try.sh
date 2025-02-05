#!/bin/bash

CURRENT_DIR=$(pwd)

LOG_DIR="$CURRENT_DIR/logs/Step_0"
APEC_DATABASE="APEC.db"

run_script() {
    local script="$1"
    local log_file="$LOG_DIR/$script.log"
    local success_msg="$2"
    local retries="$3"
    python $CURRENT_DIR/update_status.py $script RUNNING

    retry=0
    while [ $retry -lt $retries ]; do
        ./$script >$log_file 2>&1
        if grep -i "$success_msg" $log_file; then
            python $CURRENT_DIR/update_status.py $script PASSED
            return 0
        else
            python $CURRENT_DIR/update_status.py $script FAILED
            ((retry++))
        fi
    done
    return 1
}

TIMEOUT=$((80 * 60 * 60))
INTERVAL=$((10 * 60))

polling_loop() {
    local script="$1"
    local log_file="$LOG_DIR/$script.log"
    local start_time=$(date +%s)
    local end_time=$((start_time + TIMEOUT))
    python $CURRENT_DIR/update_status.py $script RUNNING
    ./$script > $log_file 2>&1
    local username=$(whoami)

    while [[ $(date +%s) -lt $end_time ]]; do
        local output=$(squeue -u "$username")
        if echo "$output" | grep -q "$username"; then
            echo "The username '$username' was found in the output of squeue."
            sleep $INTERVAL
        else
            if [ $# -eq 3 ]; then
                local out_file="$2"          
                local success_msg="$3"      
                if grep -i "$success_msg" "$out_file"; then
                    python $CURRENT_DIR/update_status.py $script PASSED
                    return 0
                else
                    python $CURRENT_DIR/update_status.py $script FAILED
                    return 1
                fi
            fi
            python $CURRENT_DIR/update_status.py $script PASSED
            return 0
        fi
    done
    python $CURRENT_DIR/update_status.py $script FAILED
    return 1
}

 cd Step_0
# python $CURRENT_DIR/update_status.py MD_ASEC.sh RUNNING
#  ./MD_ASEC.sh
# python $CURRENT_DIR/update_status.py MD_ASEC.sh PASSED

# run_script "MD_2_QMMM.sh" "Now run Molcami_OptSCF.sh to start the QM/MM calculations" 1 || exit 1
# run_script "Molcami_OptSCF.sh" "Run ASEC.sh to generate the final coordinate file and submitt" 1 || exit 1
# polling_loop "ASEC.sh" || exit 1
polling_loop "calculations/Molcami2_mod.sh" || exit 1
polling_loop "1st_to_2nd_mod.sh" "/calculations/*_VDZP_Opt/*_VDZP_Opt.out" "Happy landing!" || exit 1