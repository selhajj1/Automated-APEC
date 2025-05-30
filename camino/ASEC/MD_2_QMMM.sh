#!/bin/bash
#
# Retrieving information from Infos.dat
#
Project=`grep "Project" Infos.dat | awk '{ print $2 }'`
templatedir=`grep "Template" Infos.dat | awk '{ print $2 }'`
gropath=`grep "GroPath" Infos.dat | awk '{ print $2 }'`
tinkerdir=`grep "Tinker" Infos.dat | awk '{ print $2 }'`
prm=`grep "Parameters" Infos.dat | awk '{ print $2 }'`
Step=`grep "Step" Infos.dat | awk '{ print $2 }'`
solvent=`grep "SolventBox" Infos.dat | awk '{ print $2 }'`
chromophore=`grep "chromophore" Infos.dat | awk '{ print $2 }'`

module load gromacs/2024.4-cpu
gropath=/sysapps/ubuntu-applications/gromacs/2024.4-cpu/gromacs-2024.4/install/bin/ #JDA: Do all with gro24



echo ""
echo " 

This is the second step in which I prepare my MD results for APEC-QMMM calculations. 

In this script, I translate my outputs from Molecular Dynamics to a format relevant to QMMM calculations. 
I use Tinker-OpenMolcas for QMMM calculations and Gromacs for MD, and, because the software both require 
specific formatting to carry out my intended calculations, I will be converting between them at different 
points henceforth. 

Here I will convert the MD outputs to Tinker-OpenMolcas format.

I will:

a. Select the Gromacs file containing the configuration from Molecular Dynamics closest to the average.

b. Remove the frozen chromophore from this file, because tinker does not recognize it in the current format.

c. Convert the file from the Gromacs (.gro) format to Tinker(.xyz), by going from .gro to .pdb then 
from .pdb to .xyz.

d. Use the chromophore coordinates in the file selected in (a) above, the atom types in the CHR_chain.xyz 
file provided at the start of the protocol and the protein Tinker(.xyz) file from (c) to create a combined 
QM/MM description in .xyz format. 

e. Using a tool in Tinker (xyzedit), I will add connectivities (i.e. information about which atom is 
connected to which) to the combined QMMM .xyz file from (d). 


NOTE:

1. To do step (d), I need a description of chromophore atoms, which are not usually available in Tinker. This is already provided 
   using atom types from AMBER. If there’s any error related to this, refer to Amber99sb.prm.

2. If I am in Step_0, I start the QMMM optimizations in the next script by running Molcami_OptSCF.sh. 
   If I am in Step_1 or later, the next script to run is Molcami_direct_b3lyp.sh.   

"







#
# The folder conversion is created to convert gro into pdb into Tinker xyz
#
echo " Converting Best_Config.gro into $Project-final.pdb,"
echo " to get atom selections and the xyz file"
echo ""

declare -A force

#########################################################################
# Please modify here any time new chromophore with new atom types is used
# NC, C, O, ... correspond to the gromacs atom types, while =1022, =3, ...
# correspond to the corresponding atom type in TINKER format.
#########################################################################
force=( ["P"]=1235 ["H"]=4 ["HA"]=14 ["HC"]=14 ["H2"]=14 ["H1"]=6 ["HO"]=64 ["H5"]=175 ["O"]=5 ["OH"]=63 ["OS"]=1239 ["O2"]=1236 ["Nstar"]=1017 ["NC"]=1022 ["NA"]=1022 ["NB"]=193 ["N2"]=299 ["CK"]=1021  ["CB"]=149 ["CQ"]=1023 ["CA"]=115 ["CT"]=2 ["CM"]=115 ["C"]=3 )

mkdir conversion/
if [[ $Step -eq 0 ]]; then
   procedure=2
  # procedure=0
  # while  [[ $procedure -ne 1 && $procedure -ne 2 ]]; do
  #        echo " Now, select the procedure to follow in this initial step"
  #        echo ""
  #        echo " 1) Standard QM/MM Opt. You will get the closest configuration to the average"
  #        echo "    with the Solvent box and select a cavity for performing a standard QM/MM optimization."
  #        echo "    In the next step, the 20 A ASEC configuration will be generated for starting the"
  #        echo "    Free Energy Geometry Optimization."
  #        echo " 2) ASEC Opt. You will generate from the begining the ASEC configuration of the 20 A shell"
  #        echo "    for starting the Free Energy Geometry Optimization of the chromophore. The convergence"
  #        echo "    along the iterative procedure using this option may be slower."
  #        echo ""
  #        read procedure
  # done
   if [[ $procedure -eq 1 ]]; then
      ./update_infos.sh "Init_procedure" "QMMM" Infos.dat
      cp MD_ASEC/Best_Config_full.gro conversion/final-$Project.gro

      cd conversion/

#
# Conversion from gromacs to tinker. The chromophore CHR needs to be removed
# from the gro file because it is not recognized by tinker. So, the chromophore
# will be added to the tinker file separated.
#
      cp final-$Project.gro back-$Project.gro
      numchr=`grep -c "CHR " final-$Project.gro`
      tot=`head -n2 final-$Project.gro | tail -n1 | awk '{ print $1 }'`
      sed -i "/CHR /d" final-$Project.gro
      head -n $(($tot-$numchr+3)) final-$Project.gro | tail -n $(($tot-$numchr+1)) > temp
      head -n1 final-$Project.gro > last
      echo " $(($tot-$numchr))" >> last
      cat last temp > final-$Project.gro

#
# editconf convert it to PDB and pdb-format-new fixes the format to
# allow Tinker reading
#
      cp $templatedir/ASEC/pdb-format-new_mod.sh .
      #cp $templatedir/pdb-format-new.sh .
      $gropath/gmx editconf -f final-${Project}.gro -o final-$Project.pdb -label A
      ./pdb-format-new_mod.sh final-$Project.pdb

      mv final-tk.pdb $Project-tk.pdb

#
# If PRO is a terminal residue (N-terminal or residue 1) the extra hydrogen is labeled in 
# GROMACS as H2, being H1 and H2 the hydrogens bonded to the N. But in TINKER
# (specifically in the pdbxyz) these hydrogens are labeled as H2 and H3. So, it will be relabeled.
# This is also performed in MD_ASEC.sh and here whene need it.
#      sed -i "s/ATOM      2  H2  PRO A   1 /ATOM      2  H3  PRO A   1 /" $Project-tk.pdb
#      sed -i "s/ATOM      2  H1  PRO A   1 /ATOM      2  H2  PRO A   1 /" $Project-tk.pdb
#
      $tinkerdir/pdbxyz $Project-tk.pdb << EOF
ALL
../$prm
EOF

#
# Preparing the files for the following step
#
      ../update_infos.sh "CavityFile" "NO" ../Infos.dat
      backb=5
      while  [[ $backb -ne 0 && $backb -ne 1 ]]; do
             echo ""
             echo " Please type 1 if you want to relax the backbone of the cavity, 0 otherwise"
             echo ""
             echo ""
             read backb
      done
      ../update_infos.sh "BackBoneMD" $backb ../Infos.dat

      answer=0
      while  [[ $answer -ne 4 && $answer -ne 6 && $answer -ne 8 ]]; do
             echo ""
             echo " Now, select the distance for defining the cavity of the chromophore (4,6 or 8)"
             echo ""
             echo ""
             read answer
      done
      ../update_infos.sh "RadiusMD" $answer ../Infos.dat

      tot=`head -n1 $Project-tk.xyz | awk '{ print $1 }'`
      echo "$(($tot+$numchr))" > top
      head -n $(($tot+1)) $Project-tk.xyz | tail -n $tot >> top

#
# Converting the coordinates of the chromophore from gro to tinker xyz
# It is multiplied by 10 due to the conversion from nm to A
#
      grep "CHR " back-$Project.gro > $chromophore.gro
      first=`grep -m1 -n 'CHR ' back-$Project.gro | cut -d : -f 1`
      cp ../Chromophore/$chromophore.xyz chromo.xyz
      sed -i "s/\*,/star/g" chromo.xyz
      for i in $(eval echo "{1..$numchr}"); do
         if [[ $(($first+$i-1)) -le 9999 ]]; then
            att=`head -n $(($i+2)) chromo.xyz | tail -n1 | awk '{ print $5 }'`
            att=${force[$att]}
            x=`head -n $i $chromophore.gro | tail -n1 | awk '{ print $4 }'`
            x=$(echo "scale=2; ($x*10.0)" | bc)
            y=`head -n $i $chromophore.gro | tail -n1 | awk '{ print $5 }'`
            y=$(echo "scale=2; ($y*10.0)" | bc)
            z=`head -n $i $chromophore.gro | tail -n1 | awk '{ print $6 }'`
            z=$(echo "scale=2; ($z*10.0)" | bc)
            head -n $i $chromophore.gro | tail -n1 | awk -v var1="$(($tot+$i))" -v var2="$att" -v x=$x -v y=$y -v z=$z '{ print "  "var1"  "$2"   "x"       "y"       "z"     "var2 }' >> top
         else
            att=`head -n $(($i+2)) chromo.xyz | tail -n1 | awk '{ print $5 }'`
            att=${force[$att]}
            x=`head -n $i $chromophore.gro | tail -n1 | awk '{ print $3 }'`
            x=$(echo "scale=2; ($x*10.0)" | bc)
            y=`head -n $i $chromophore.gro | tail -n1 | awk '{ print $4 }'`
            y=$(echo "scale=2; ($y*10.0)" | bc)
            z=`head -n $i $chromophore.gro | tail -n1 | awk '{ print $5 }'`
            z=$(echo "scale=2; ($z*10.0)" | bc)
            head -n $i $chromophore.gro | tail -n1 | awk -v var1="$(($tot+$i))" -v var2="$att" -v x=$x -v y=$y -v z=$z '{ print "  "var1"  "$2"   "x"       "y"       "z"     "var2 }' >> top
         fi
      done
#
# Generating the final tinker xyz of the whole system
#
      echo "" >> top
      mv $Project-tk.xyz $Project-tk_noCHR.xyz
      mv top $Project-tk.xyz

#
# Generating the connectivities based in distance
#
      $tinkerdir/xyzedit $Project-tk.xyz << EOF
../$prm
7
EOF
      rm chromo.xyz
      mv $Project-tk.xyz_2 $Project-tk.xyz
      
      cp $Project-tk.xyz ../
      cd ..
   #   cp $templatedir/keymaker.sh .
   #   ./keymaker.sh $Project-tk $prm.prm
      cp $templatedir/Molcami_SCF.sh .
      cp $templatedir/ASEC/Update_chromo.sh .

      echo ""
      echo ""
      echo " ***********************************************************"
      echo ""
      echo " Now run Molcami_SCF.sh to start the QM/MM calculations."
      echo " Follow the steps for the QM/MM geometry optimization, then"
      echo " run Update_chromo.sh after the last pdb file were generated"
      echo " for starting ASEC"
      echo ""
      echo " ***********************************************************"
      echo ""
   else 
# From this point ASEC will be performed from Step = 0
#
# Conversion from gromacs to tinker. The chromophore CHR need to be removed
# from the gro file because it is not recognized by tinker. So, the chromophore
# will be added to the tinker file separated.
#

      ./update_infos.sh "Init_procedure" "ASEC" Infos.dat
      cp MD_ASEC/Best_Config.gro conversion/final-$Project.gro

      cd conversion/

      cp final-$Project.gro back-$Project.gro
      numchr=`grep -c "CHR " final-$Project.gro`
      tot=`head -n2 final-$Project.gro | tail -n1 | awk '{ print $1 }'`
      sed -i "/CHR /d" final-$Project.gro
      head -n $(($tot-$numchr+3)) final-$Project.gro | tail -n $(($tot-$numchr+1)) > temp
      head -n1 final-$Project.gro > last
      echo " $(($tot-$numchr))" >> last
      cat last temp > final-$Project.gro

      sed -i "s/HOH/SOL/g" final-$Project.gro

#
# editconf convert it to PDB and pdb-format-new fixes the format to
# allow Tinker reading#
      cp $templatedir/ASEC/pdb-format-new_mod.sh .
      #cp $templatedir/pdb-format-new.sh .
      $gropath/gmx editconf -f final-${Project}.gro -o final-$Project.pdb -label A
      ./pdb-format-new_mod.sh final-$Project.pdb

      mv final-tk.pdb $Project-tk.pdb
#      sed -i "s/ATOM      2  H2  PRO A   1 /ATOM      2  H3  PRO A   1 /" $Project-tk.pdb
#      sed -i "s/ATOM      2  H1  PRO A   1 /ATOM      2  H2  PRO A   1 /" $Project-tk.pdb
      $tinkerdir/pdbxyz $Project-tk.pdb << EOF
ALL
../$prm
EOF

#
# Converting the coordinates of the chromophore from gro to tinker xyz
# It is multiplied by 10 due to the conversion from nm to A
#
      tot=`head -n1 $Project-tk.xyz | awk '{ print $1 }'`
      echo "$(($tot+$numchr))" > top
      head -n $(($tot+1)) $Project-tk.xyz | tail -n $tot >> top

      grep "CHR " back-$Project.gro > $chromophore.gro
      first=`grep -m1 -n 'CHR ' back-$Project.gro | cut -d : -f 1`
      cp ../Chromophore/$chromophore.xyz chromo.xyz
      sed -i "s/\*/star/g" chromo.xyz
      for i in $(eval echo "{1..$numchr}"); do
         if [[ $(($first+$i-1)) -le 9999 ]]; then
            att=`head -n $(($i+2)) chromo.xyz | tail -n1 | awk '{ print $5 }'`
            att=${force[$att]}
            x=`head -n $i $chromophore.gro | tail -n1 | awk '{ print $4 }'`
            x=$(echo "scale=2; ($x*10.0)" | bc)
            y=`head -n $i $chromophore.gro | tail -n1 | awk '{ print $5 }'`
            y=$(echo "scale=2; ($y*10.0)" | bc)
            z=`head -n $i $chromophore.gro | tail -n1 | awk '{ print $6 }'`
            z=$(echo "scale=2; ($z*10.0)" | bc)
            head -n $i $chromophore.gro | tail -n1 | awk -v var1="$(($tot+$i))" -v var2="$att" -v x=$x -v y=$y -v z=$z '{ print "  "var1"  "$2"   "x"       "y"       "z"     "var2 }' >> top
         else
            att=`head -n $(($i+2)) chromo.xyz | tail -n1 | awk '{ print $5 }'`
            att=${force[$att]}
            x=`head -n $i $chromophore.gro | tail -n1 | awk '{ print $3 }'`
            x=$(echo "scale=2; ($x*10.0)" | bc)
            y=`head -n $i $chromophore.gro | tail -n1 | awk '{ print $4 }'`
            y=$(echo "scale=2; ($y*10.0)" | bc)
            z=`head -n $i $chromophore.gro | tail -n1 | awk '{ print $5 }'`
            z=$(echo "scale=2; ($z*10.0)" | bc)
            head -n $i $chromophore.gro | tail -n1 | awk -v var1="$(($tot+$i))" -v var2="$att" -v x=$x -v y=$y -v z=$z '{ print "  "var1"  "$2"   "x"       "y"       "z"     "var2 }' >> top
         fi
      done
      echo "" >> top
      mv $Project-tk.xyz $Project-tk_noCHR.xyz
      mv top $Project-tk.xyz

#
# Generating the connectivities based in distance
#
      $tinkerdir/xyzedit $Project-tk.xyz << EOF
../$prm
7
EOF
      rm chromo.xyz

      echo "########################################################################"
      echo ""
      echo " It is normal the code to show 0 conectivities of the chromophore above."
      echo " Indeed, the conectivities are being added now based on distace"
      echo ""
      echo "########################################################################"

      mv $Project-tk.xyz_2 $Project-tk.xyz

#
# Preparing the files for the following step
#
      cp $Project-tk.xyz ../
      cd ..

      modo=1
    #  modo=0
    #  while  [[ $modo -ne 1 && $modo -ne 2 ]]; do
    #         echo " Now, select what kind of procedure"
    #         echo ""
    #         echo " 1) Optimizing from SCF Optg"
    #         echo " 2) Optimizing directly from CASSCF"
    #         echo ""
    #         read modo
    #  done

      if [[ $modo -eq 1 ]]; then
         cp $templatedir/ASEC/Molcami_OptSCF.sh .
         ./update_infos.sh "Next_script" "Molcami_OptSCF.sh" Infos.dat
         echo "**********************************************************"
         echo ""
         echo " Now run Molcami_OptSCF.sh to start the QM/MM calculations"
         echo ""
         echo "**********************************************************"
      else
         modo2=0
         while  [[ $modo2 -ne 1 && $modo2 -ne 2 ]]; do
                echo " Now, select what kind of optimization"
                echo ""
                echo " 1) Minimun Optimization"
                echo " 2) TS Optimization"
                echo ""
                read modo2
         done

         if [[ $modo2 -eq 1 ]]; then
            ./update_infos.sh "Stationary" "MIN" Infos.dat
            cp $templatedir/ASEC/Molcami_SP.sh .
            ./update_infos.sh "Next_script" "Molcami_SP.sh" Infos.dat
            echo ""
            echo "******************************************************"
            echo ""
            echo " Now run Molcami_SP.sh to start the QM/MM calculations"
            echo ""
            echo "******************************************************"
            echo ""
         else
            ./update_infos.sh "Stationary" "TS" Infos.dat
            cp $templatedir/ASEC/Molcami_direct_b3lyp.sh .
            ./update_infos.sh "Next_script" "Molcami_direct_b3lyp.sh" Infos.dat
            echo ""
            echo "*****************************************************************"
            echo ""
            echo " Now run Molcami_direct_b3lyp.sh to start the QM/MM calculations"
            echo ""
            echo "*****************************************************************"
         fi         
      fi
   fi

else 
# 
# from this point it corresponds to Step != 0
#
   cp MD_ASEC/Best_Config.gro conversion/final-$Project.gro

   cd conversion/

#
# Conversion from gromacs to tinker. The chromophore CHR need to be removed
# from the gro file because it is not recognized by tinker. So, the chromophore
# will be added to the tinker file separated.
#

   cp final-$Project.gro back-$Project.gro
   numchr=`grep -c "CHR " final-$Project.gro`
   tot=`head -n2 final-$Project.gro | tail -n1 | awk '{ print $1 }'`
   sed -i "/CHR /d" final-$Project.gro
   head -n $(($tot-$numchr+3)) final-$Project.gro | tail -n $(($tot-$numchr+1)) > temp
   head -n1 final-$Project.gro > last
   echo " $(($tot-$numchr))" >> last
   cat last temp > final-$Project.gro

   sed -i "s/HOH/SOL/g" final-$Project.gro

#
# editconf convert it to PDB and pdb-format-new fixes the format to
# allow Tinker reading
#
   cp $templatedir/ASEC/pdb-format-new_mod.sh .
   #cp $templatedir/pdb-format-new.sh .
   $gropath/gmx editconf -f final-${Project}.gro -o final-$Project.pdb -label A
   ./pdb-format-new_mod.sh final-$Project.pdb

   mv final-tk.pdb $Project-tk.pdb
#         sed -i "s/ATOM      2  H2  PRO A   1 /ATOM      2  H3  PRO A   1 /" $Project-tk.pdb
#         sed -i "s/ATOM      2  H1  PRO A   1 /ATOM      2  H2  PRO A   1 /" $Project-tk.pdb
   $tinkerdir/pdbxyz $Project-tk.pdb << EOF
ALL
../$prm
EOF

#
# Converting the coordinates of the chromophore from gro to tinker xyz
# It is multiplied by 10 due to the conversion from nm to A
#
   tot=`head -n1 $Project-tk.xyz | awk '{ print $1 }'`
   echo "$(($tot+$numchr))" > top
   head -n $(($tot+1)) $Project-tk.xyz | tail -n $tot >> top

   grep "CHR " back-$Project.gro > $chromophore.gro
   first=`grep -m1 -n 'CHR ' back-$Project.gro | cut -d : -f 1`
   cp ../Chromophore/$chromophore.xyz chromo.xyz
   sed -i "s/\*/star/g" chromo.xyz
   for i in $(eval echo "{1..$numchr}"); do
      if [[ $(($first+$i-1)) -le 9999 ]]; then
         att=`head -n $(($i+2)) chromo.xyz | tail -n1 | awk '{ print $5 }'`
         att=${force[$att]}
         x=`head -n $i $chromophore.gro | tail -n1 | awk '{ print $4 }'`
         x=$(echo "scale=2; ($x*10.0)" | bc)
         y=`head -n $i $chromophore.gro | tail -n1 | awk '{ print $5 }'`
         y=$(echo "scale=2; ($y*10.0)" | bc)
         z=`head -n $i $chromophore.gro | tail -n1 | awk '{ print $6 }'`
         z=$(echo "scale=2; ($z*10.0)" | bc)
         head -n $i $chromophore.gro | tail -n1 | awk -v var1="$(($tot+$i))" -v var2="$att" -v x=$x -v y=$y -v z=$z '{ print "  "var1"  "$2"   "x"       "y"       "z"     "var2 }' >> top
      else
         att=`head -n $(($i+2)) chromo.xyz | tail -n1 | awk '{ print $5 }'`
         att=${force[$att]}
         x=`head -n $i $chromophore.gro | tail -n1 | awk '{ print $3 }'`
         x=$(echo "scale=2; ($x*10.0)" | bc)
         y=`head -n $i $chromophore.gro | tail -n1 | awk '{ print $4 }'`
         y=$(echo "scale=2; ($y*10.0)" | bc)
         z=`head -n $i $chromophore.gro | tail -n1 | awk '{ print $5 }'`
         z=$(echo "scale=2; ($z*10.0)" | bc)
         head -n $i $chromophore.gro | tail -n1 | awk -v var1="$(($tot+$i))" -v var2="$att" -v x=$x -v y=$y -v z=$z '{ print "  "var1"  "$2"   "x"       "y"       "z"     "var2 }' >> top
      fi
   done

#
# Generating the tinker xyz file for the whole system
#
   echo "" >> top
   mv $Project-tk.xyz $Project-tk_noCHR.xyz
   mv top $Project-tk.xyz
#
# Generating the connectivities based in distance
#
   $tinkerdir/xyzedit $Project-tk.xyz << EOF
../$prm
7
EOF

   echo "########################################################################"
   echo ""
   echo " It is normal the code to show 0 conectivities of the chromophore above."
   echo " Indeed, the conectivities are being added now based on distace"
   echo ""
   echo "########################################################################"

   mv $Project-tk.xyz_2 $Project-tk.xyz

   cp $Project-tk.xyz ../
   cd ..

   cp $templatedir/ASEC/Molcami_direct_b3lyp.sh .
   ./update_infos.sh "Next_script" "Molcami_direct_b3lyp.sh" Infos.dat
   echo "*****************************************************************"
   echo ""
   echo " Now run Molcami_direct_b3lyp.sh to start the QM/MM calculations"
   echo ""
   echo "*****************************************************************"
fi
