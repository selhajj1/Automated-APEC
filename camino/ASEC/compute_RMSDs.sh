#!/bin/bash
#Jacopo D'Ascenzi (JDA): I keep the gropath pointing explictly to gro24.4 since you remember there's that DOWSER issue being compatible only with gro19. After DOWSER, we immediately switch to full gro24.4

chromo=`grep "chromo_FF_name" ../../../parameters | awk '{ print $2 }'`
Project=`grep "Project" ../../Infos.dat | awk '{ print $2 }'`
gropath=`grep "GroPath" ../../Infos.dat | awk '{ print $2 }'`
module load gromacs/2024.4-cpu
gropath=/sysapps/ubuntu-applications/gromacs/2024.4-cpu/gromacs-2024.4/install/bin/

#4 is the index for the backbone (in this very very case we are treating)
echo 4 4 | gmx rms -f ${Project}_box_sol.xtc -s ${Project}_box_sol.tpr -dt 100 -o rms_backbone.xvg


#Now compute the RMSD of neighborhoods of the chromophore in a radius of 6 Angstrom
cp ${Project}_box_sol.ndx ${Project}_box_sol_tmp.ndx
cp ${Project}_box_sol.ndx ${Project}_box_sol_rms.ndx

echo "not resname SOL NA CL and same resid as within 6 of resname $chromo" > select
gmx select -f ${Project}_box_sol.xtc -s ${Project}_box_sol.tpr -select -on ${Project}_box_sol_tmp.ndx -e 0 < select
grep -A 999999 not_resname ${Project}_box_sol_tmp.ndx >> ${Project}_box_sol_rms.ndx
rm ${Project}_box_sol_tmp.ndx

#RMSD computed on the new group defined in the ndx file
echo 3 21 | gmx rms -f ${Project}_box_sol.xtc -s ${Project}_box_sol.tpr -n ${Project}_box_sol_rms.ndx -dt 100  -o rms_cavity.xvg
rm \#*

./plot_RMSDs.py
