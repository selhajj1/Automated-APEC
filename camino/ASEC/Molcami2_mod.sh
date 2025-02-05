#!/bin/bash
#
# Retrieving information from Infos.dat
#
Project=`grep "Project" ../Infos.dat | awk '{ print $2 }'`
prm=`grep "Parameters" ../Infos.dat | awk '{ print $2 }'`
tinkerdir=`grep "Tinker" ../Infos.dat | awk '{ print $2 }'`
templatedir=`grep "Template" ../Infos.dat | awk '{ print $2 }'`
tempdir=`grep "tempdir" ../Infos.dat | awk '{ print $2 }'`
spin=`grep "Spin" ../Infos.dat | awk '{ print $2 }'`
CURRENT_DIR=$(pwd)
PARENT_DIR=$(dirname $CURRENT_DIR)
GRANDPARENT_DIR=$(dirname $PARENT_DIR)
flavin_model=$(grep 'flavin_model' "$GRANDPARENT_DIR/parameters" | awk '{print $2}') 

scf=${Project}_OptSCF

if [[ -f $scf/$scf.out ]]; then
   echo ""
   echo " *************************************************************"
   echo "                      Warning!"
   echo ""
   echo " $scf.out already exists. We are going to use it..."
   echo ""
   echo " *************************************************************"
   echo ""
else
   echo ""
   echo " Collecting the HF optimization from iRODS..."
   echo ""
   dir=`basename $tempdir`
   #iget -r /arctic/projects/CHEM9C4/$USER/$dir $scf
   #if [[ -f $scf/$dir/$scf.out ]]; then
      #mv $scf/$dir/* $scf
      #rm -r $scf/$dir
      #irm -r /arctic/projects/CHEM9C4/$USER/$dir
   #else
      #echo ""
      #echo "************************************************************************"
      #echo ""
      #echo " It seems the MD is still running or it did not finish properly"
      #echo ""
      #echo "************************************************************************"
      #echo ""
      #exit 0
   #fi
fi

#
# Instructions to the user
#
echo ""
echo " The current project is $Project. Checking the HF optimization..."
echo ""

#
# Grepping the Happy landing to check that the calculation ended up properly
#
if grep -q "Timing: Wall=" $scf/$scf.out; then
   echo " HF optimization ended successfully"
   echo ""
else
   echo " HF optimization still in progress. Terminating..."
   echo ""
   exit 0 
fi	

#
# Creation of the folder for CAS/3-21G single point and copy of all the files
# If the folder already exists, it finishes with an error message
#
new=${Project}_VDZP
if [ -d $new ]; then
   ./smooth_restart.sh $new "Do you want to re-run the QM/MM 3-21G single point? (y/n)" 5
   if [[ ! -f Infos.dat ]]; then
      mv no.Infos.dat Infos.dat
      exit 0
   fi
fi
mkdir ${new}
cp $scf/$scf.Final.xyz ${new}/${new}.xyz
cp $scf/$scf.key ${new}/${new}.key
cp $scf/${prm}.prm ${new}/
#cp $templatedir/modify-inp.vim ${new}/
#slurm
cp $templatedir/molcas.slurm.sh ${new}/molcas-job.sh
#cp $templatedir/molcas-job.sh ${new}/
cp $templatedir/ASEC/template_b3lyp_min ${new}/
cd ${new}/

#
# Editing the template for single point
#
sed -i "s|PARAMETRI|${prm}|" template_b3lyp_min

#
# Editing the submission script template for a CAS single point 
#

mv template_b3lyp_min $new.input




#Change Inputs for b3lyp optimiziation Calculation based on redox state
if [ "$flavin_model" = "Quinone" ]; then
    sed -i "s|spin=1|spin=1|" $new.input
    sed -i "s|charge=0|charge=0|" $new.input
    sed -i '/UHF/d' $new.input
elif [ "$flavin_model" = "Anionic-Semiquinone" ]; then
    sed -i "s|spin=1|spin=2|" $new.input
    sed -i "s|charge=0|charge=-1|" $new.input
elif  [ "$flavin_model" = "Neutral-Semiquinone" ]; then
    sed -i "s|spin=1|spin=2|" $new.input
    sed -i "s|charge=0|charge=0|" $new.input
elif  [ "$flavin_model" = "Anionic-Hydroquinone" ]; then
    sed -i "s|spin=1|spin=1|" $new.input
    sed -i "s|charge=0|charge=-1|" $new.input
    sed -i '/UHF/d' $new.input
elif  [ "$flavin_model" = "Neutral-Hydroquinone" ]; then
    sed -i "s|spin=1|spin=1|" $new.input
    sed -i "s|charge=0|charge=0|" $new.input
    sed -i '/UHF/d' $new.input
fi


 
sed -i "s|NOMEPROGETTO|${new}|" molcas-job.sh
no=$PWD
sed -i "s|NOMEDIRETTORI|${no}|" molcas-job.sh
sed -i "s|MEMTOT|23000|" molcas-job.sh
sed -i "s|MEMORIA|20000|" molcas-job.sh
sed -i "s|hh:00:00|120:00:00|" molcas-job.sh

#
# Submitting the CAS/3-21G single point
#
echo ""
echo " Submitting the CAS/ANO-L-VDZ single point now..."
echo ""
#sleep 1

#TMPFILE=`mktemp -d /scratch/photon_XXXXXX`
#../../update_infos.sh "tempdir" $TMPFILE ../../Infos.dat
#sed -i "s|TEMPFOLDER|$TMPFILE|g" molcas-job.sh
#cp -r * $TMPFILE
#current=$PWD
#cd $TMPFILE
sbatch molcas-job.sh
#cd $current

cd ..

cp $templatedir/ASEC/alter_orbital_mod.sh .
../update_infos.sh "Next_script" "finalPDB_mod.sh" ../Infos.dat

echo ""
echo "***************************************************************"
echo ""
echo " As soon as the b3lyp optimization is finished, run finalPDB_mod.sh"
echo ""
echo "***************************************************************"
echo ""
