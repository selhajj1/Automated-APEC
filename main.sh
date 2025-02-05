#!/bin/bash
echo ""
echo ""
echo ""
echo ""
echo "*****************************************************************************************************"
echo "*****************************************************************************************************"
echo ""
echo "          *         ******     *******      ***            ********  *******    *****                "
echo "         ***       **    **    **         **   **          **        **        **   **               "
echo "        ** **      **    **    **        **                **        **       **                     "
echo "       **   **     ******      ******    **         ***    ******    ******   **  *****              "
echo "      *********    **          **        **                **        **       **     **              "
echo "     **       **   **          **         **   **          **        **        **   **               "
echo "    **         **  **          *******      ***            **        *******    *****                "
echo ""
echo "                            Version 2.0: APEC-FEG for Flavoproteins-Automated version                "
echo ""
echo ""
echo "                                                                 Written by: Yoelvis Orozco-Gonzalez "
echo "               with contributions by: M. Pabel Kabir, Paulami Ghosh, Stephen Ajagbe, Jacopo D'Ascenzi"
echo "                                            revamped and automated by:  Sarah Elhajj and Samer Gozem "                          
echo "                                                                 Gozem Lab, Georgia State University "
echo "                                                                       Latest version, Febraury 2025 " 
echo "*****************************************************************************************************"
echo "*****************************************************************************************************"
echo ""
echo ""
echo ""
module load vmd
# Create logs and processes directories if they don't exist

if [ -d "databases" ] && [ "$(ls -A databases)" ]; then
    rm -rf databases/*
fi

if [ -d "logs" ] && [ "$(ls -A logs)" ]; then
    rm -rf logs/*
fi

if [ -d "processes" ] && [ "$(ls -A processes)" ]; then
    rm -rf processes/*
fi

mkdir -p logs
mkdir -p processes
mkdir -p databases

wait_for_script() {
    local pid_file=$1

    sleep 20
    while ps -p $(<"$pid_file") >/dev/null 2>&1; do
        sleep 20
    done
}
mkdir -p logs/Step_0

./initial_MD_calculations.sh >logs/initial_MD_calculations.log 2>&1 &
echo $! >processes/initial_MD_calculations.pid
wait_for_script "processes/initial_MD_calculations.pid" 

mv logs/Step_0 logs/initial-Step_0

mkdir -p logs/Step_0

./first_MD_calculations.sh >logs/first_MD_calculations.log 2>&1 &
echo $! >processes/first_MD_calculations.pid
wait_for_script "processes/first_MD_calculations.pid" 

./first_QMMM_calculations.sh >logs/first_QMMM_calculations.log 2>&1 &
echo $! >processes/first_QMMM_calculations.pid
wait_for_script "processes/first_QMMM_calculations.pid" 

for i in $(seq 1 5); do

    mkdir -p logs/Step_${i}

    ./nth_MD_calculations.sh $i >logs/${i}_MD_calculations.log 2>&1 &
    echo $! >processes/${i}_MD_calculations.pid
    wait_for_script "processes/${i}_MD_calculations.pid"

    ./nth_QMMM_calculations.sh $i >logs/${i}_QMMM_calculations.log 2>&1 &
    echo $! >processes/${i}_QMMM_calculations.pid
    wait_for_script "processes/${i}_QMMM_calculations.pid"
done

echo "All scripts have completed."
