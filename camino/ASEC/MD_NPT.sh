#!/bin/bash
#
# Reading information from Infos.dat
#

Project=`grep "Project" Infos.dat | awk '{ print $2 }'`
prm=`grep "Parameters" Infos.dat | awk '{ print $2 }'`
templatedir=`grep "Template" Infos.dat | awk '{ print $2 }'`
tinkerdir=`grep "Tinker" Infos.dat | awk '{ print $2 }'`
gropath=`grep "GroPath" Infos.dat | awk '{ print $2 }'`
multichain=`grep "MultChain" Infos.dat | awk '{ print $2 }'`
step=`grep "Step" Infos.dat | awk '{ print $2 }'`
charge=`grep "Init_Charge" Infos.dat | awk '{ print $2 }'`
relaxpr=`grep "Relax_protein" Infos.dat | awk '{ print $2 }'`
moldy=`grep "MD_ensemble" Infos.dat | awk '{ print $2 }'`
amber=`grep "AMBER" Infos.dat | awk '{ print $2 }'`
CURRENT_DIR=$(pwd)
PARENT_DIR=$(dirname $CURRENT_DIR)

module load gromacs/2024.4-cpu #JDA modification. As a consequence, modification at line 288, too

cd Dynamic

#
# Colecting the files needed to run the NPT molecular Dynamics
#

if [[ $step -eq 0 ]]; then
   if [[ $moldy == "NVT" ]]; then
      mkdir Sim_NPT
      cp $templatedir/ASEC/dynamic_sol_NPT.mdp Sim_NPT
      cp Minimization/output/final-${Project}_box_sol.gro Sim_NPT/${Project}_box_sol.gro
      cp Minimization/${Project}_box_sol.ndx Sim_NPT
      cp Minimization/*.itp Sim_NPT
      cp Minimization/${Project}_box_sol.top Sim_NPT
      cp -r Minimization/$amber.ff Sim_NPT
      cp Minimization/residuetypes.dat Sim_NPT
#      cp ../new_charges Sim_NPT
      cd Sim_NPT

# The ESPF charges need to be updated here
#
#      base=`grep -n "; residue   1 CHR rtp CHR" ${Project}_Other_chain_A2.itp | cut -d : -f 1`
#      numchr=`grep -c " 1    CHR " ${Project}_Other_chain_A2.itp`
#      for i in $(seq 1 $numchr); do
#         charge=`head -n $(($base+$i)) ${Project}_Other_chain_A2.itp | tail -n1 | awk '{ print $7 }'`
#         newcharge=`head -n $i new_charges | tail -n1 | awk '{ print $1 }'`
#         sed -i "$(($i+$base))s/$charge/$newcharge/" ${Project}_Other_chain_A2.itp
#      done
   else
      echo "re-do this section ..."
      exit 0
#      cp $templatedir/ASEC/dynamic_sol_NPT.mdp .
#      cp Minimization/output/final-${Project}_box_sol.gro ${Project}_box_sol.gro
#      cp Minimization/*.itp .
#      cp Minimization/${Project}_box_sol.ndx .
#      cp Minimization/${Project}_box_sol.top .
   fi
fi

if [[ $relaxpr == y ]]; then
   sed -i "s/;freezegrps = GroupDyna/freezegrps = GroupDyna/g" dynamic_sol_NPT.mdp
   sed -i "s/;freezedim = Y Y Y/freezedim = Y Y Y/g" dynamic_sol_NPT.mdp
else
   sed -i "s/;freezegrps = non-Water/freezegrps = non-Water/g" dynamic_sol_NPT.mdp
   sed -i "s/;freezedim = Y Y Y/freezedim = Y Y Y/g" dynamic_sol_NPT.mdp
fi
#else
#   cd Dynamic
#   sed -i "s/;freezegrps = GroupDyna/freezegrps = GroupDyna/g" dynamic_sol_NPT.mdp
#   sed -i "s/;freezedim = Y Y Y/freezedim = Y Y Y/g" dynamic_sol_NPT.mdp
#fi

#
# Defining parameters for the MD
#

echo ""
echo ""
echo "********************************************************************"
echo ""
echo " What is the PRODUCTION TEMPERATURE of the NPT simulation? (Kelvin)"
echo ""

# read tempmd

tempmd=$(grep 'NPT_production_temperature' "$PARENT_DIR/parameters" | awk '{print $2}')
echo ""

#echo " Do you want to heat the system before the MD production run? (y/n)"
#echo
#read risposta

risposta="y"

if [[ $risposta == y ]]; then
   echo ""
   echo " How long is the HEATING PHASE? (ps). Normally use 300."
   echo ""
#    read timeheat
    timeheat=$(grep 'NPT_heating_phase_time' "$PARENT_DIR/parameters" | awk '{print $2}')
   echo ""
   echo " How long is the EQUILIBRATION PHASE? (ps). Normally use 2000."
   echo ""
#    read timequi
    timequi=$(grep 'equilibration_phase' "$PARENT_DIR/parameters" | awk '{print $2}')
   echo ""
else
   timeheat=0
   timequi=0
fi

echo " How long is the production phase? (ps). Normally 0."
echo " We do not need production data at this time."

# read timeprod

timeprod=$(grep 'NPT_production_phase_time' "$PARENT_DIR/parameters" | awk '{print $2}')
echo ""
dt=$(grep "dt                      =" dynamic_sol_NPT.mdp | awk '{ print $3 }')
if [[ $risposta == y ]]; then
   heat_chunk=$(echo "($timeheat/$dt)" | bc)
   equi_chunk=$(echo "($timequi/$dt)" | bc)
   prod_chunk=$(echo "($timeprod/$dt)" | bc)
   numsteps=$(($heat_chunk+$equi_chunk+$prod_chunk))
   sed -i "s/TIME1/$timeheat/" dynamic_sol_NPT.mdp
   sed -i "s/TEMP1/$tempmd/g" dynamic_sol_NPT.mdp
else
   numsteps=$(echo "($timeprod/$dt)" | bc)
   sed -i "s/annealing/;annealing/" dynamic_sol_NPT.mdp
   sed -i "s/;gen_vel/gen_vel/" dynamic_sol_NPT.mdp
   sed -i "s/;gen_temp/gen_temp/" dynamic_sol_NPT.mdp
#   sed -i "s/;gen_temp/gen_temp/" dynamic.mdp
   sed -i "s/ref_t = 0/;ref_t = 0/" dynamic_sol_NPT.mdp
   sed -i "s/;ref_t = TEMP1/ref_t = TEMP1/" dynamic_sol_NPT.mdp
   sed -i "s/TEMP1/$tempmd/g" dynamic_sol_NPT.mdp
fi

sed -i "s/PASSI/$numsteps/" dynamic_sol_NPT.mdp

#
# Run in the CPUs or GPUs
#

gpu="b"
while [[ $gpu != "y" && $gpu != "n" ]]; do
   echo ""
   echo ""
   echo " Do you want to use the GPUs to compute the dynamics? (y/n)"
   echo ""
#    read gpu
    gpu=$(grep 'GPU_use' "$PARENT_DIR/parameters" | awk '{print $2}')
done

if [[ $gpu == y"" ]]; then
   cp $templatedir/gromacs.slurm_GPU.sh gromacs.sh
else
   cp $templatedir/gromacs.slurm.sh gromacs.sh
fi

gropath=/sysapps/ubuntu-applications/gromacs/2024.4-cpu/gromacs-2024.4/install/bin/ #JDA: Do all with gro24
$gropath/gmx grompp -maxwarn 2 -f dynamic_sol_NPT.mdp -c ${Project}_box_sol.gro -n ${Project}_box_sol.ndx -p ${Project}_box_sol.top -o ${Project}_box_sol.tpr

sed -i "s|NOMEPROGETTO|${Project}_box_sol|" gromacs.sh
sed -i "s|NOMEDIRETTORI|$PWD|" gromacs.sh
sed -i "s|GROPATH|$gropath|" gromacs.sh

#TMPFILE=`mktemp -d /scratch/photon_XXXXXX`

#../../update_infos.sh "tempdir" $TMPFILE ../../Infos.dat
#sed -i "s|TEMPFOLDER|$TMPFILE|" gromacs.sh
#cp -r * $TMPFILE
#current=$PWD
#cd $TMPFILE
sbatch gromacs.sh
#cd $current

#
# Message to user
#

if [[ $moldy == "NVT" ]]; then
   cd ../../
   cp $templatedir/ASEC/MD_NVT.sh .
   cp $templatedir/Analysis_MD.sh .
   echo ""
   echo "**************************************************************"
   echo ""
   echo " Wait for the NPT molecular dynamics to end then run MD_NVT.sh"
   echo ""
   echo "**************************************************************"
   ./update_infos.sh "Heat_NPT" $timeheat Infos.dat
   ./update_infos.sh "Equi_NPT" $timequi Infos.dat
   ./update_infos.sh "Prod_NPT" $timeprod Infos.dat
   ./update_infos.sh "Next_script" "MD_NVT.sh" Infos.dat
else
   cd ../
   cp $templatedir/ASEC/MD_ASEC.sh .
   cp $templatedir/Analysis_MD.sh .
   echo ""
   echo "***************************************************************"
   echo ""
   echo " Wait for the NPT molecular dynamics to end then run MD_ASEC.sh"
   echo ""
   echo "***************************************************************"
   ./update_infos.sh "HeatMD" $timeheat Infos.dat
   ./update_infos.sh "EquiMD" $timequi Infos.dat
   ./update_infos.sh "ProdMD" $timeprod Infos.dat
   ./update_infos.sh "Next_script" "MD_ASEC.sh" Infos.dat
fi
