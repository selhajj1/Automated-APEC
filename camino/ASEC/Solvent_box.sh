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
chromophore=`grep "chromophore" Infos.dat | awk '{ print $2 }'`
dimer=`grep "Dimer" Infos.dat | awk '{ print $2 }'`
amber=`grep "AMBER" Infos.dat | awk '{ print $2 }'`
initial=$(grep "Initial" Infos.dat | awk '{ print $2 }')

CURRENT_DIR=$(pwd)
PARENT_DIR=$(dirname $CURRENT_DIR)
module load vmd
module load gromacs/2024.4-cpu #JDA modification: after the whole pdb preparation done with gro19 (switching to 24 during that is buggy: probably clashes with its previous step in DOWSER), we obtain a .pdb file which is then converted to a gro file. Now, that gro file will be gro24 and we'll proceed with gro24 from now. I checked that `gmx pdb2gmx -f gromacs19_grofile.gro -o new_grofile.gro' command returns exactly the same gro file. Consequence of this is the modification at lines 137,138

#
# Having parametrized the charges of the chromophore using the ESPF model
# we can go back to the Minimize_${Project} folder to continue with the
# energy minimization
#
# Retrieving the pdb of the chromophore and rtp file
#
cd Minimize_${Project}
rm -rf $amber.ff *.itp *.top $Project.gro
cp ../Chromophore/${chromophore}.pdb .
cp -r $templatedir/$amber.ff .
cd $amber.ff/


option=0
while [[ $option -ne 1 && $option -ne 2 && $option -ne 3 && $option -ne 4 && $option -ne 5 ]]; do
   echo ""
   echo " Please select the Flavin model to use:"
   echo ""
   echo " 1) Quinone"
   echo " 2) Anionic-Semiquinone"
   echo " 3) Neutral-Semiquinone"
   echo " 4) Anionic-Hydroquinone"
   echo " 5) Neutral-Hydroquinone"
  echo ""
#    read option
flavin_model=$(grep 'flavin_model' "$PARENT_DIR/parameters" | awk '{print $2}')
if [ "$flavin_model" = "Quinone" ]; then
    option=1
elif [ "$flavin_model" = "Anionic-Semiquinone" ]; then
    option=2
elif  [ "$flavin_model" = "Neutral-Semiquinone" ]; then
    option=3
elif  [ "$flavin_model" = "Anionic-Hydroquinone" ]; then
    option=4
elif  [ "$flavin_model" = "Neutral-Hydroquinone" ]; then
    option=5
fi

done
../../update_infos.sh "Redox" $option ../../Infos.dat

fmnfad="NONE"
while [[ $fmnfad != "FMN" && $fmnfad != "FAD" ]]; do
   echo ""
   echo " Please select if the tail corresponds to FMN or FAD (just type FMN or FAD)"
   echo ""
   echo ""
#    read fmnfad
    fmnfad=$(grep 'tail' "$PARENT_DIR/parameters" | awk '{print $2}')
done
../../update_infos.sh "Tail" $fmnfad ../../Infos.dat

fmnfad="FMN"

if [[ $fmnfad == "FMN" ]]; then
	if [[ $option -eq 1 ]]; then
  	 cp $templatedir/ASEC/manchester_FMN_rtp new_rtp
	fi
	if [[ $option -eq 2 ]]; then
  	 cp $templatedir/ASEC/manchester_FMN-_rtp new_rtp
	fi
	if [[ $option -eq 3 ]]; then
   	 cp $templatedir/ASEC/manchester_FMNH_rtp new_rtp
	fi
	if [[ $option -eq 4 ]]; then
   	 cp $templatedir/ASEC/manchester_FMNH-_rtp new_rtp
	fi
	if [[ $option -eq 5 ]]; then
   	 cp $templatedir/ASEC/manchester_FMNH2_rtp new_rtp
	fi
# else
	# if [[ $option -eq 1 ]]; then
   #       cp /data/PHO_WORK/sajagbe2/QMMM/LOVCalculations/FAD/2pd7/Quinone/FAD_rtp new_rtp
	# fi
   #      if [[ $option -eq 2 ]]; then
   #      fi
   #      if [[ $option -eq 3 ]]; then
   #      fi
   #      if [[ $option -eq 4 ]]; then
   #      fi
   #      if [[ $option -eq 5 ]]; then
   #      fi	  
 

fi

#cp ../../ESPF_charges/new_rtp .
cat new_rtp >> aminoacids.rtp
# rm ffbonded.itp
# cp ../../../ffbonded.itp .

cd ..
#
# Modifying the pdb file to put the chromophore between the protein and the waters
#
wat=`grep "DOWSER_wat" ../Infos.dat | awk '{ print $2 }'`
nwat=$(($wat+$wat+$wat))
if [[ $nwat -gt 0 ]]; then
   numchromo=`grep -c " CHR " ${chromophore}.pdb`
   lineas=`wc -l $Project.pdb | awk '{ print $1 }'`
   head -n $(($lineas-$nwat)) $Project.pdb > proteina
   tail -n $nwat $Project.pdb > tempwat
   cat ${chromophore}.pdb >> proteina
   head -n $(($lineas+$numchromo-$nwat)) proteina > proteina2
   cat tempwat >> proteina2
   mv proteina2 $Project.pdb
   rm proteina
else
   cat ${chromophore}.pdb >> $Project.pdb
fi

#
# pdb2gmx is the Gromacs utility for generating gro files and topologies
#
#Next line is JDA modification
gropath=/sysapps/ubuntu-applications/gromacs/2024.4-cpu/gromacs-2024.4/install/bin/
$gropath/gmx pdb2gmx -f $Project.pdb -o $Project.gro -p $Project.top -ff $amber -water tip3p 1> grolog # Previously: ' 2> grolog ', now changed to 1 to properly grep 'Writing coordinate file...' in the following grolog
checkgro=`grep 'Writing coordinate file...' grolog`
   if [[ -z $checkgro ]]; then
      echo " An error occurred during the execution of pdb2gmx. Please look into grolog file"
      echo " No further operation performed. Aborting..."
      echo ""
      exit 0
   else
      echo " new.gro and its topology were successfully generated"
      echo ""
      rm grolog
   fi

#JDA: moved the part of solvation and neutralization

echo " ****************************************************************"
echo ""
echo " The protein will be embbeded in a solvent box. Then it will be" 
echo " energetically minimized relaxing also the backbone." 
echo ""
echo " ****************************************************************"
sleep 10

echo " ****************************************************************"
echo ""
echo " Please define the size of the cubic box in nanometers (i.e 7.0)."
echo " For a single proteins 7.0 is normally ok."
echo " For a dimer, maybe 10.0 is fine"
echo ""
echo " ********"
box_shape=$(grep 'box_shape' "$PARENT_DIR/parameters" | awk '{print $2}')
edge_dist=$(grep 'edge_dist' "$PARENT_DIR/parameters" | awk '{print $2}')
box=$(grep 'size_cubicbox' "$PARENT_DIR/parameters" | awk '{print $2}')

mkdir Box
cp -r $amber.ff *.itp $Project.top residuetypes.dat Box
cp $Project.gro Box
cd Box

if [[ $initial == "YES" ]]; then
   $gropath/gmx editconf -f $Project.gro -bt $box_shape -d $edge_dist -o ${Project}_box_init.gro -c
else
   $gropath/gmx editconf -f $Project.gro -bt $box_shape -box $box $box $box -o ${Project}_box_init.gro -c
fi
$gropath/gmx solvate -cp ${Project}_box_init.gro -cs spc216.gro -o ${Project}_box_sol_init.gro -p $Project.top >& genbox.out

#
# Excluding the water molecules from the solvent box that can be added
# very close to the protein (like in cavities). Otherwise, it lead to
# problems during the energy minimization).
# The water molecules added to fill the box are labeled as SOL, while the ones coming from dowser are HOH.
# This avoids the possibility of removing internal waters originally coming from the pdb.
#
cp ${Project}_box_sol_init.gro Interm.gro

selection="((same residue as all within 0.5 of protein) and resname SOL) or ((same residue as all within 2 of resname CHR) and resname SOL)"

# TCL script for VMD: open file, apply selection, save the serial numbers into a file
#
echo -e "mol new Interm.gro" > removewat.tcl
echo -e "mol delrep 0 top" >> removewat.tcl
line1="set sele [ atomselect top \"$selection\" ]"
echo -e "$line1" >> removewat.tcl
echo -e 'set numbers [$sele get serial]' >> removewat.tcl
line2="set filename Interwat"
echo -e "$line2" >> removewat.tcl
echo -e 'set fileId [open $filename "w"]' >> removewat.tcl
echo -e 'puts -nonewline $fileId $numbers' >> removewat.tcl
echo -e 'close $fileId' >> removewat.tcl
echo -e "exit" >> removewat.tcl
vmd -e removewat.tcl -dispdev text
rm removewat.tcl
echo ""
echo ""
echo " Please wait ..."

#
# Excluding those waters from the gro file
#
cp Interm.gro Interm_yoe.gro

numinit=`head -n2 $Project.gro | tail -n1 | awk '{ print $1 }'`
col=`awk '{print NF}' Interwat`
cont=0
for i in $(eval echo "{1..$col}")
do
   rem=`expr $i % 3`
   indx=`awk -v j=$i '{ print $j }' Interwat`
   if [[ $indx -gt $numinit ]]; then
      cont=$(($cont+1))
      if [[ $rem -eq 1 ]]; then
         sed -i "/  OW$indx /d" Interm.gro
         sed -i "/  OW $indx /d" Interm.gro
         sed -i "/  OW  $indx /d" Interm.gro
         sed -i "/  OW   $indx /d" Interm.gro
         sed -i "/  OW    $indx /d" Interm.gro
      else
         if [[ $rem -eq 2 ]]; then
            sed -i "/ HW1$indx /d" Interm.gro
            sed -i "/ HW1 $indx /d" Interm.gro
            sed -i "/ HW1  $indx /d" Interm.gro
            sed -i "/ HW1   $indx /d" Interm.gro
            sed -i "/ HW1    $indx /d" Interm.gro
         else
            sed -i "/ HW2$indx /d" Interm.gro
            sed -i "/ HW2 $indx /d" Interm.gro
            sed -i "/ HW2  $indx /d" Interm.gro
            sed -i "/ HW2   $indx /d" Interm.gro
            sed -i "/ HW2    $indx /d" Interm.gro
         fi
      fi
   fi
done

numatm=`head -n2 Interm.gro | tail -n1 | awk '{ print $1 }'`
newnum=$(($numatm-$cont))
head -n1 Interm.gro > ${Project}_box_sol.gro
echo "$newnum" >> ${Project}_box_sol.gro
tail -n$(($numatm-$cont+1)) Interm.gro >> ${Project}_box_sol.gro

addwat=`tail -n1 ${Project}.top | awk '{ print $2 }'`
wattop=$((($addwat*3-$cont)/3))

lines=`wc -l ${Project}.top | awk '{ print $1 }'`
cp ${Project}.top tempo
head -n$(($lines-1)) tempo > ${Project}_box_sol.top
echo -e "SOL              $wattop" >> ${Project}_box_sol.top
rm tempo

touch ions.mdp #JDA: merely for adding ions

$gropath/gmx grompp -f ions.mdp -c ${Project}_box_sol.gro -p ${Project}_box_sol.top -o ions.tpr

#
# Adding ions to the Solvent Box for neutralizing the total charge of the system
# (see self explaning echoes)
#

#JDA: initialize conc reading process with a random neg value
conc=-1
while [[ $conc -lt 0 ]]; do

   if [[ $charge -ne 0 ]]; then
      echo ""
      echo " *******"
      echo "  The total charge of the system is ${charge}, which will be"
      echo "  neutralized by adding Na or Cl ions."
      echo "  But, if you want to add extra NaCl to the system"
      echo "  to mimic the experimental conditions, please specify the conc"
      echo "  to add (e.g.: 0.1), which will be in [M] units."
      echo "  Type \"0\" otherwise. Values as 0.0 or string not accepted."
      echo ""
   #  read selected salt conc
      conc=$(grep 'conc_NaCl' "$PARENT_DIR/parameters"| awk '{print $2}')
   fi

   if [[ $charge -eq 0 ]]; then
      echo ""
      echo " *******"
      echo "  The total charge of the system is ZERO, no Na or Cl ions"
      echo "  will be added to neutralize the system."
      echo "  But, if you want to add extra NaCl to the system"
      echo "  to mimic the experimental conditions, please specify the conc"
      echo "  to add (e.g.: 0.1), which will be in [M] units."
      echo "  Type \"0\" otherwise. Values as 0.0 or string not accepted."
      echo ""
   #  read selected salt conc
      conc=$(grep 'conc_NaCl' "$PARENT_DIR/parameters"| awk '{print $2}')
   fi
done


if [[ $charge -ne 0 || $conc -ne 0 ]]; then

   mkdir Add_Ion
   mv ions.tpr ${Project}_box_sol.top ${Project}_box_sol.gro Add_Ion
   cd Add_Ion
   numpro=`head -n2 ../$Project.gro | tail -n1 | awk '{ print $1 }'`

#
# This while is used to ensure that the ions will not be added inside the proteins
#
   res=0
   seed=111
   count=0
   while [[ $res -eq 0 ]]; do
      replace=0
      replacectl=0

      if [[ -f back_${Project}_box_sol.top ]]; then
         cp back_${Project}_box_sol.top ${Project}_box_sol.top
      else
         cp ${Project}_box_sol.top back_${Project}_box_sol.top
      fi
      
      if [[ $charge -lt 0 ]]; then
         pcharge=$(echo "-1*$charge" | bc)
         ../../../update_infos.sh "Additional_NAs_added" "$pcharge" ../../../Infos.dat
      elif  [[ $charge -gt 0 ]]; then
         ../../../update_infos.sh "Additional_CLs_added" "$charge" ../../../Infos.dat
      fi
      ../../../update_infos.sh "Added_NaCl_conc" "$conc" ../../../Infos.dat

      $gropath/gmx genion -seed $seed -s ions.tpr -p ${Project}_box_sol.top -nname CL -nq -1 -pname NA -pq 1 -neutral -conc $conc -o ${Project}_box_sol_ion.gro 2> addedions << EOF
SOL
EOF
      lin=`grep -c "Replacing solvent molecule" addedions`
      for i in $(eval echo "{1..$lin}")
      do
         replace=`grep "Replacing solvent molecule" addedions | head -n $i | tail -n1 | awk '{ print $6 }' | sed 's/[^0-9]//g'`
      if [[ $replace -le $numpro ]]; then
         replacectl=$(($replacectl+1))
      fi
      done
      
      
#
#  This while is to ensure that the SOL group has been selected by "genion" code for placing the ions.
#
      soll=b
      while [[ $soll != "y" && $soll != "n" ]]; do
         echo ""
         echo " Was selected the \"SOL\" group for adding the ions? (y/n)"
         echo ""
        #  read soll
        soll=$(grep 'SOL' "$PARENT_DIR/parameters" | awk '{print $2}')
         if [[ $soll == "n" ]]; then
            echo ""
            echo " Modify this script in order to sellect the right"
            echo " number of the \"SOL\" group"
            echo " Terminating ..."
            echo ""
            exit 0
         fi
      done

      if [[ $replacectl -eq 0 ]]; then
         res=10

         cp ${Project}_box_sol_ion.gro ../../${Project}_box_sol.gro
         cp ${Project}_box_sol.top ../../${Project}_box_sol.top

         cd ..
      else
         seed=$(($seed+3))
      fi
   done
fi

if [[ $conc -eq 0 && $conc -eq 0 ]]; then
   ../../../update_infos.sh "Added_NaCL" 0 ../../../Infos.dat
fi

cd ..

#JDA: first mini. All frozen but SOL and Ions
mkdir mini_solvent
mv EM_solv_ions.mdp ${Project}_box_sol.gro mini_solvent
cp -r $amber.ff ${Project}_box_sol.top *itp mini_solvent
cd mini_solvent

#select all but SOL+IONS, which will be frozen in 1st mini
echo '!"Water_and_ions"' > choices.txt
echo 'q' >> choices.txt
$gropath/gmx make_ndx -f ${Project}_box_sol.gro -o ${Project}_box_sol.ndx < choices.txt
grep -n 'OW' ${Project}_box_sol.gro | cut -d : -f 1 > temporal
awk '$1=$1-2' temporal > oxywat
echo "[ Group1 ]" >> ${Project}_box_sol.ndx
cat oxywat >> ${Project}_box_sol.ndx
rm oxywat choices.txt


backb=0
echo " *******"
echo ""
echo " An energy minimization of the protein side-chains and"
echo " hydrogens of the chromophore will be performed along"
echo " with solvent molecules (those decided to move and ions."
echo " The backbone won't relaxed for the moment."
echo ""
echo " *******"
echo ""
sleep 10

cp $templatedir/ASEC/ndx-maker_mod.sh .
./ndx-maker_mod.sh ${Project}_box_sol 5 $backb

conver=10
iter=1
while [[ conver -ne 0 ]]; do
   $gropath/gmx grompp -f EM_solv_ions.mdp -c ${Project}_box_sol.gro -n ${Project}_box_sol.ndx -p ${Project}_box_sol.top -o ${Project}_box_sol.tpr -maxwarn 1

   echo ""
   echo " Please wait, minimizing, batch $iter of 1000 steps"
   echo ""

   $gropath/gmx mdrun -s ${Project}_box_sol.tpr -o ${Project}_box_sol.trr -x ${Project}_box_sol.xtc -c final-$Project.gro 2> grolog

   echo '0' > choices.txt
   echo 'q' >> choices.txt
   $gropath/gmx trjconv -pbc nojump -f final-${Project}.gro -s ${Project}_box_sol.gro -o ${Project}_No_jump.gro < choices.txt


   if grep -q "Steepest Descents did not converge to Fmax" md.log; then
      mkdir Iter_$iter
      mv ener.edr ${Project}_box_sol.gro final-$Project.gro ${Project}_box_sol.tpr ${Project}_box_sol.trr md.log mdout.mdp Iter_$iter
      cp ${Project}_No_jump.gro Iter_$iter
      mv ${Project}_No_jump.gro ${Project}_box_sol.gro
      iter=$(($iter+1))
   else
      if grep -q "Steepest Descents converged to" md.log; then
         conver=0
         echo ""
         echo " MM energy minimization seems to finish properly."
         echo ""
         mv final-$Project.gro backup_final-$Project.gro
         cp ${Project}_No_jump.gro final-$Project.gro
      else
         echo ""
         echo " There is a problem with the energy minimization. Please check it."
         echo ""
         ans="b"
         while [[ $ans != "y" && $ans != "n" ]]; do
            echo "******************************************************************"
            echo ""
            echo " Do you still want to continue? (y/n)"
            echo ""
            echo "******************************************************************"
            read ans
         done
         if [[ $ans == "n" ]]; then
            exit 0
         else
            conver=0
            mv final-$Project.gro backup_final-$Project.gro
            cp ${Project}_No_jump.gro final-$Project.gro
         fi
      fi
   fi
done

mv final-$Project.gro ../${Project}_box_sol.gro
cd ..

#Second mini. All frozen but solv, ions, side chains and Hs
echo '2' > choices.txt
echo 'q' >> choices.txt
$gropath/gmx make_ndx -f ${Project}_box_sol.gro -o ${Project}_box_sol.ndx < choices.txt
grep -n 'OW' ${Project}_box_sol.gro | cut -d : -f 1 > temporal
awk '$1=$1-2' temporal > oxywat
echo "[ Group1 ]" >> ${Project}_box_sol.ndx
cat oxywat >> ${Project}_box_sol.ndx
rm oxywat choices.txt


backb=0
echo " *******"
echo ""
echo " An energy minimization of the protein side-chains and"
echo " hydrogens of the chromophore will be performed along"
echo " with solvent molecules (those decided to move and ions."
echo " The backbone won't relaxed for the moment."
echo ""
echo " *******"
echo ""
sleep 10

cp $templatedir/ASEC/ndx-maker_mod.sh .
./ndx-maker_mod.sh ${Project}_box_sol 5 $backb

#
# Runing the MM side chains energy minimization in the loging node.
# In order to do this we divided the minimization steps in batches
# of 1000 steps. Otherwise it would be killed by the system
#
conver=10
iter=1
while [[ conver -ne 0 ]]; do
   $gropath/gmx grompp -f standard-EM.mdp -c ${Project}_box_sol.gro -n ${Project}_box_sol.ndx -p ${Project}_box_sol.top -o ${Project}_box_sol.tpr -maxwarn 1

   echo ""
   echo " Please wait, minimizing, batch $iter of 1000 steps"
   echo ""

   $gropath/gmx mdrun -s ${Project}_box_sol.tpr -o ${Project}_box_sol.trr -x ${Project}_box_sol.xtc -c final-$Project.gro 2> grolog

   echo '0' > choices.txt
   echo 'q' >> choices.txt
   $gropath/gmx trjconv -pbc nojump -f final-${Project}.gro -s ${Project}_box_sol.gro -o ${Project}_No_jump.gro < choices.txt


   if grep -q "Steepest Descents did not converge to Fmax" md.log; then
      mkdir Iter_$iter
      mv ener.edr ${Project}_box_sol.gro final-$Project.gro ${Project}_box_sol.tpr ${Project}_box_sol.trr md.log mdout.mdp Iter_$iter
      cp ${Project}_No_jump.gro Iter_$iter
      mv ${Project}_No_jump.gro ${Project}_box_sol.gro
      iter=$(($iter+1))
   else
      if grep -q "Steepest Descents converged to" md.log; then
         conver=0
         echo ""
         echo " MM energy minimization seems to finish properly."
         echo ""
         mv final-$Project.gro backup_final-$Project.gro
         cp ${Project}_No_jump.gro final-$Project.gro
      else
         echo ""
         echo " There is a problem with the energy minimization. Please check it."
         echo ""
         ans="b"
         while [[ $ans != "y" && $ans != "n" ]]; do
            echo "******************************************************************"
            echo ""
            echo " Do you still want to continue? (y/n)"
            echo ""
            echo "******************************************************************"
            read ans
         done
         if [[ $ans == "n" ]]; then
            exit 0
         else
            conver=0
            mv final-$Project.gro backup_final-$Project.gro
            cp ${Project}_No_jump.gro final-$Project.gro
         fi
      fi
   fi
done

mkdir -p ../Dynamic/Minimization

cp -r $amber.ff *.itp residuetypes.dat ${Project}_box_sol.gro ${Project}_box_sol.top ../Dynamic/Minimization
cp ${Project}_box_sol.top ../Dynamic/Minimization/${Project}_box_sol.top


cd ..

#
# Defining the "GroupDyna" group of the ndx file to be fixed during the
# MM energy minimization
#
chratoms=`head -n1 Chromophore/$chromophore.xyz | awk '{ print $1 }'`

relaxpr="y"
./update_infos.sh "Relax_protein" "$relaxpr" Infos.dat

if [[ $relaxpr == "y" ]]; then
   relaxbb="y"
#   while [[ $relaxbb != y && $relaxbb != n ]]; do
#      echo ""
#      echo " Relax backbone? (y/n)"
#      echo ""
#      read relaxbb
#   done
   ./update_infos.sh "Relax_backbone" "$relaxbb" Infos.dat
else
   ./update_infos.sh "Relax_backbone" "n" Infos.dat 
fi

cd Dynamic/Minimization
cp $templatedir/ASEC/min_sol.mdp .

if [[ $relaxpr == y ]]; then
   if [[ $relaxbb == n ]]; then
      selection="backbone or (resname CHR and not hydrogen)"
      # TCL script for VMD: open file, apply selection, save the serial numbers into a file
      #
      echo -e "mol new ${Project}_box_sol.gro type gro" > ndxsel.tcl
      echo -e "mol delrep 0 top" >> ndxsel.tcl
      riga1="set babbeo [ atomselect top \"$selection\" ]"
      echo -e "$riga1" >> ndxsel.tcl
      echo -e 'set noah [$babbeo get serial]' >> ndxsel.tcl
      riga3="set filename dinabb"
      echo -e "$riga3" >> ndxsel.tcl
      echo -e 'set fileId [open $filename "w"]' >> ndxsel.tcl
      echo -e 'puts -nonewline $fileId $noah' >> ndxsel.tcl
      echo -e 'close $fileId' >> ndxsel.tcl
      echo -e "exit" >> ndxsel.tcl
      vmd -e ndxsel.tcl -dispdev text

      num=`awk '{print NF}' dinabb`
      for i in $(eval echo "{1..$num}")
      do
        awk -v j=$i '{ print $j }' dinabb >> dina
      done
   else
#
# Selecting the atoms of the chromophore plus the fixed and LQ, LM
# to be fixed during the MD
#
      grep -n 'CHR ' ${Project}_box_sol.gro | cut -d : -f 1 > temporal1
      awk '$1=$1-2' temporal1 > dina
      rm -f dina2
      for i in $(eval echo "{1..$chratoms}"); do
         atmtype=`head -n $(($i+2)) ../../Chromophore/$chromophore.xyz | tail -n1 | awk '{ print $6 }'`
         if [[ $atmtype == "QM" || $atmtype == "MM" || $atmtype == "LM" || $atmtype == "LQ" ]]; then
            head -n $i dina | tail -n1 | awk '{ print $1 }' >> dina2
         fi
      done
      mv dina2 dina
      num=`grep -c "CHR " ${Project}_box_sol.gro | awk '{ print $1 }'`
   fi
   if [[ $dimer == "YES" ]]; then
      chrnum=`grep -c "CHR " ${Project}_box_sol.gro | awk '{ print $1 }'`
      head -n $(($num-$chrnum+$chrnum/2)) dina > dinadimer
      mv dinadimer dina
   fi
fi

# Preparing and running the 2nd part of the MM energy minimization
# First generate the new ndx freezing the chromo, then modify the mdp and then run
tr '\n' ' ' < dina > dyna
echo ":set tw=75" > shiftline.vim
echo ":normal gqw" >> shiftline.vim
echo ":x" >> shiftline.vim
vim -es dyna < shiftline.vim
echo q | gmx make_ndx -f ${Project}_box_sol.gro -o ${Project}_box_sol.ndx
echo [ GroupDyna ] >> ${Project}_box_sol.ndx
cat dyna >> ${Project}_box_sol.ndx
rm dyna dina

if [[ $initial == "YES" ]]; then
   sed -i "s/freezegrps = GroupDyna/;freezegrps = GroupDyna/g" min_sol.mdp
   sed -i "s/freezedim = Y Y Y/;freezedim = Y Y Y/g" min_sol.mdp
fi

conver=10
iter=1
if [[ $dimer == "YES" ]]; then
   sed -i "s/emtol                   = 100/emtol                   = 120/" min_sol.mdp
fi

$gropath/gmx grompp -f min_sol.mdp -c ${Project}_box_sol.gro -n ${Project}_box_sol.ndx -p ${Project}_box_sol.top -o ${Project}_box_sol.tpr -maxwarn 1

cp $templatedir/gromacs.slurm_GPU.sh gromacs.sh
sed -i "s|NOMEPROGETTO|${Project}_box_sol|" gromacs.sh
sed -i "s|NOMEDIRETTORI|$PWD|" gromacs.sh
sed -i "s|GROPATH|$gropath|" gromacs.sh
#Sarah Elhajj edits
#TMPFILE=`mktemp -d /scratch/photon_XXXXXX`
#../../update_infos.sh "tempdir" $TMPFILE ../../Infos.dat
#sed -i "s|TEMPFOLDER|$TMPFILE|" gromacs.sh
#cp -r * $TMPFILE
#current=$PWD
#cd $TMPFILE
chmod a+r $CURRENT_DIR/Minimize_$Project/Box/Add_Ion/${Project}_box_sol.top
chmod a+r $CURRENT_DIR/Dynamic/Minimization/${Project}_box_sol.top
#sbatch molcas-job.sh | awk '{print $4}' > jobid 
#cd $current
# Initialize variables
max_attempts=12 # 2 hours / 10 minutes = 12 attempts
interval=600   # 10 minutes in seconds
attempt=1
job_submitted=false
while [ $attempt -le $max_attempts ]; do
  # Submit the job and capture the output
  output=$(sbatch gromacs.sh)
  echo $output
   
  # Check if the "Submitted batch job" message is in the output
  if echo "$output" | grep -q "Submitted batch job"; then
    echo "$output" | awk '{print $4}' > jobid
    echo "Job successfully submitted on attempt $attempt."
    job_submitted=true
    break
  else
    echo "Attempt $attempt: Job submission failed. Retrying in 10 minutes..."
  fi
   
  # Wait for 10 minutes before retrying
  sleep $interval
  ((attempt++))
done
# Check if the job was never submitted
if [ "$job_submitted" = false ]; then
  echo "Job submission failed after $max_attempts attempts."
  exit 1
fi
#cd $current
cd ../../
#SH edits
if [[ $initial == "YES" ]]; then
   cp $templatedir/ASEC/MD_NPT.sh .
   ./update_infos.sh "Next_script" "MD_NPT.sh" Infos.dat
   ./update_infos.sh "MD_ensemble" "NVT" Infos.dat
else
   cp $templatedir/ASEC/MD_NVT.sh .
   ./update_infos.sh "Next_script" "MD_NVT.sh" Infos.dat
   ./update_infos.sh "MD_ensemble" "NVT" Infos.dat
fi
