#!/bin/bash
#SBATCH -J NOMEPROGETTO
#SBATCH -N 1
#SBATCH -n 8
#SBATCH -t hh:00:00
#SBATCH --mem=MEMTOTMB 
#SBATCH -p qCPUCache
#SBATCH -A CHEM9r4
#SBATCH --exclude=acidscn029,acidscn028,acidscn013,acidscn012
#--------------------------------------------------------------#
#cd $SLURM_SUBMIT_DIR
#--------------------------------------------------------------#
# Molcas settings 
#--------------------------------------------------------------#
module load openmolcas/24.06
export MOLCAS_MEM=MEMORIAMB
export MOLCAS_MOLDEN=ON
export MOLCAS_PRINT=normal
export TINKER=/sysapps/ubuntu-applications/openmolcas/22.10/build/tinker-6.3.3/bin
export WorkDir=/cache/users/$USER/$SLURM_JOBID
export InpDir=$PWD
export Project=$SLURM_JOB_NAME
#--------------------------------------------------------------#
#  Change the Project!!!
#--------------------------------------------------------------#
mkdir -p $WorkDir
echo $SLURM_JOB_NODELIST > $InpDir/nodename
echo $SLURM_JOB_ID > $InpDir/jobid
#--------------------------------------------------------------#
# Copy of the files - obsolete
#--------------------------------------------------------------#
#cp $InpDir/$Project.xyz $WorkDir/$Project.xyz
#cp $InpDir/$Project.key $WorkDir/$Project.key
#cp $InpDir/*.prm $WorkDir/
#--------------------------------------------------------------#
# Start job
#--------------------------------------------------------------#
cp $InpDir/* $WorkDir
cd $WorkDir
/sysapps/ubuntu-applications/openmolcas/git-24.06/install/pymolcas $WorkDir/$Project.input >$WorkDir/$Project.out 2>$WorkDir/$Project.err
rm $WorkDir/*.OrdInt
cp $WorkDir/* $InpDir
rm -r $WorkDir

