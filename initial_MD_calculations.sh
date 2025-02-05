    #!/bin/bash

    echo "Automated APEC-script: it do the first-MD-calculation of Step_0"
    echo "APEC 3.0: written by Sarah Elhajj"
    echo "Latest changes: July 2024"
    module load vmd
    CURRENT_DIR=$(pwd)
    LOG_DIR="$CURRENT_DIR/logs/Step_0"
    Project=$(grep 'project_name' "$CURRENT_DIR/parameters" | awk '{print $2}')
    APEC_DATABASE="$CURRENT_DIR/databases/APEC_0.db"
    PARAM_FILE="$CURRENT_DIR/parameters"

    run_script() {
        local script="$1"
        local log_file="$LOG_DIR/$script.log"
        local success_msg="$2"

        

        retry=0
        while [ $retry -lt 2 ]; do
            ./$script >$log_file 2>&1
            if grep -i "$success_msg" $log_file; then
            
                return 0
            else
                
                ((retry++))
            fi
        done
        return 1
    }

    initialize_run() {
        rm -r Step_0

    }

    polling_loop() {
        local script="$1"
        local -a success_msgs=("${!2}") # Indirect expansion for array of success messages
        local -a files_to_check=("${!3}") # Indirect expansion for array of files
        local log_file="$LOG_DIR/$script.log"
        local start_time=$(date +%s)
        local end_time=$((start_time + TIMEOUT))
        local conditions_met=($(printf '0%.s' "${success_msgs[@]}")) # Array to keep track of which conditions are met


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
            
                echo "All conditions met, exiting loop."
                return 0
            else
                echo "Not all conditions met, waiting for next check..."
                sleep $INTERVAL
            fi
        done

        
        return 1
    }


    initialize_run

    run_script "New_APEC.sh" "Folder Step_0 created! cd Step_0/, then ./NewStep.sh" && cd Step_0 || exit 1
    run_script "NewStep.sh" "Continue executing: Solvent_box.sh" || exit 1

    TIMEOUT=$((120 * 60 * 60))
    INTERVAL=$((10))
    Solvent_box_success_messages=("Steepest Descents converged to")
    Solvent_box_files_to_check=("Dynamic/Minimization/output/md.log")
    polling_loop "Solvent_box.sh" Solvent_box_success_messages[@] Solvent_box_files_to_check[@] || exit 1

    TIMEOUT=$((120 * 60 * 60))
    INTERVAL=$((10 * 60))
    NPT_success_messages=("Finished")
    NPT_files_to_check=("Dynamic/Sim_NPT/output/md.log")
    polling_loop "MD_NPT.sh" NPT_success_messages[@] NPT_files_to_check[@] || exit 1

    NPT_temperature_averaged=$(grep -A15 "A V E R A G E S" "Dynamic/Sim_NPT/output/md.log" | grep -A1 "Temperature" | tail -1 | awk '{print $5}')
    NPT_temperature_original=$(grep 'NPT_production_temperature' "$CURRENT_DIR/parameters" | awk '{print $2}')
    decimal_temperature=$(echo "$NPT_temperature_averaged" | awk '{printf "%.4f\n", $1}')

    if awk -v t1="$decimal_temperature" -v t2="$NPT_temperature_original" 'BEGIN { exit !(t1 < t2) }'; then
        echo "The temperature is less than NPT temperature"
        
    else
        echo "The temperature is equal to or greater than NPT temperature"
        
    fi

    cd $CURRENT_DIR/Step_0/Dynamic/Sim_NPT/output

    OUTPUT_FILE="gmx_energy_output.txt"  # Replace with your actual file name
    module load gromacs/2024.4-cpu
    sleep 300
    echo 22 | gmx energy -f ener.edr  > $OUTPUT_FILE

    VOLUME=$(grep "Volume" "$OUTPUT_FILE" | tail -n 1 | awk '{print $2}')

    # Check if volume was extracted correctly
    if [ -z "$VOLUME" ]; then
        echo "Error: Could not extract volume from the output file."
        exit 1
    fi

    # Step 2: Calculate the cubic box size (V^(1/3))
    BOX_SIZE=$(awk -v volume="$VOLUME" 'BEGIN {print volume^(1/3)}')

    # Step 3: Print the results
    echo "Average Volume (V): $VOLUME nm^3"
    echo "Cubic Box Size (V^(1/3)): $BOX_SIZE nm"
    sed -i.bak "s/^\(size_cubicbox \).*/\1$BOX_SIZE/" "$PARAM_FILE"
    mv $CURRENT_DIR/Step_0/ $CURRENT_DIR/initial-Step_0
