#!/bin/bash
#
Project=`grep "Project" ../Infos.dat | awk '{ print $2 }'`
prm=`grep "Parameters" ../Infos.dat | awk '{ print $2 }'`
tinkerdir=`grep "Tinker" ../Infos.dat | awk '{ print $2 }'`
templatedir=`grep "Template" ../Infos.dat | awk '{ print $2 }'`
numatoms=`grep "numatoms" ../Infos.dat | awk '{ print $2 }'`
Step=`grep "Step" ../Infos.dat | awk '{ print $2 }'`
qmcharge=`grep "QM_Charge" ../Infos.dat | awk '{ print $2 }'`
actspace=`grep "Active_space" ../Infos.dat | awk '{ print $2 }'`
actelec=`grep "Active_electrons" ../Infos.dat | awk '{ print $2 }'`
spin=`grep "Spin" ../Infos.dat | awk '{ print $2 }'`
actorb=`grep "Active_orbitals" ../Infos.dat | awk '{ print $2 }'`
inactorb=`grep "Inactive_orbitals" ../Infos.dat | awk '{ print $2 }'`
ci=`grep "CI" ../Infos.dat | awk '{ print $2 }'`
ciroots=`grep "CIRoots" ../Infos.dat | awk '{ print $2 }'`


mkdir CASPT2_ipea_025
mkdir CASPT2_ipea_0
#mkdir CASPT2_ipea_0/CASSCF_3_States

Project_new=${Project}_VDZP_Opt

cp $templatedir/ASEC/template_CASPT2 .


#Modify Molcas Input

      sed -i "s|spin=1|spin=$spin|" template_CASPT2
      sed -i "s|nActEl=10 0 0|nActEl=$actelec 0 0|" template_CASPT2
      sed -i "s|Inactive=62|Inactive=$inactorb|" template_CASPT2
      sed -i "s|Ras2=10|Ras2=$actorb|" template_CASPT2

   if [[ $qmcharge -lt 0 ]]; then
    
      sed -i "/*&SCF/d" template_CASPT2
      sed -i "/lamorok/a  &SCF" template_CASPT2
      sed -i "/&SCF/a \ UHF"template_CASPT2
      sed -i "s|*  charge = 0|  charge = $qmcharge|" template_CASPT2

   fi

   if [[ $ci == 'custom' ]] ; then
   cistring=""
         for i in $( seq 1  $ciroots ) ; do
            cistring+="$i "
         done
      sed -i '' "s|ciroot=8 8 1|ciroot=$ciroots $ciroots 1|" template_CASPT2
      sed -i '' "s|1 8|1 $ciroots|" template_CASPT2
      sed -i '' "s|1 2 3 4 5 6 7 8|$cistring|" template_CASPT2
      sed -i '' "s|multi = 8|multi = $ciroots|" template_CASPT2   

   fi



#Copy Input to New Directories

cp template_CASPT2 CASPT2_ipea_025/${Project}_CASPT2_025.input
cp template_CASPT2 CASPT2_ipea_0/${Project}_CASPT2_0.input

rm template_CASPT2

sed -i "s/ipea = 0.25/ipea = 0.0/g" CASPT2_ipea_0/${Project}_CASPT2_0.input
sed -i "s|PARAMETER|${prm}|" CASPT2_ipea_025/${Project}_CASPT2_025.input
sed -i "s|PARAMETER|${prm}|" CASPT2_ipea_0/${Project}_CASPT2_0.input


cp $Project_new/$Project_new.key CASPT2_ipea_025/${Project}_CASPT2_025.key
cp $Project_new/$Project_new.key CASPT2_ipea_0/${Project}_CASPT2_0.key

cp $Project_new/$Project_new.xyz CASPT2_ipea_025/${Project}_CASPT2_025.xyz
cp $Project_new/$Project_new.xyz CASPT2_ipea_0/${Project}_CASPT2_0.xyz

cp $Project_new/$prm.prm CASPT2_ipea_025
cp $Project_new/$prm.prm CASPT2_ipea_0

cp $Project_new/$Project_new.JobIph CASPT2_ipea_025/${Project}_CASPT2_025.JobIph
cp $Project_new/$Project_new.JobIph CASPT2_ipea_0/${Project}_CASPT2_0.JobIph

#slurm
cp $Project_new/molcas-job.sh CASPT2_ipea_025
cp $Project_new/molcas-job.sh CASPT2_ipea_0
sed -i "s/NOMEPROGETTO/$Project/" CASPT2_ipea_025/molcas-job.sh
sed -i "s/NOMEPROGETTO/$Project/" CASPT2_ipea_0/molcas-job.sh
sed -i "s/MEMTOT/23000/" CASPT2_ipea_025/molcas-job.sh
sed -i "s/MEMTOT/23000/" CASPT2_ipea_0/molcas-job.sh
sed -i "s/MEMORIA/20000/" CASPT2_ipea_025/molcas-job.sh
sed -i "s/MEMORIA/20000/" CASPT2_ipea_0/molcas-job.sh
sed -i "s/walltime=140/walltime=230/" CASPT2_ipea_025/molcas-job.sh
sed -i "s/walltime=140/walltime=230/" CASPT2_ipea_0/molcas-job.sh

sed -i "s/export Project=.*/export Project=${Project}_CASPT2_025/g" CASPT2_ipea_025/molcas-job.sh
sed -i "s/export Project=.*/export Project=${Project}_CASPT2_0/g" CASPT2_ipea_0/molcas-job.sh

#
# Submiting the job
#
cd CASPT2_ipea_025
#TMPFILE=`mktemp -d /scratch/photon_CASPT2_XXXXXX`
#../../update_infos.sh "CASPT2_iRODS" $TMPFILE ../../Infos.dat
#sed -i "s|TEMPFOLDER|$TMPFILE|g" molcas-job.sh
#cp -r * $TMPFILE
#current=$PWD
#cd $TMPFILE
sbatch molcas-job.sh
#cd $current
cd ..

cd CASPT2_ipea_0
sbatch molcas-job.sh
cd ../
#cd ../../
#cp $templatedir/ASEC/Energies_CAV_TINKER.sh .

