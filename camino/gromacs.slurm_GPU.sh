#!/bin/bash
#SBATCH -J NOMEPROGETTO
#SBATCH -N 1
#SBATCH -n 16
#SBATCH -t 120:00:00
#SBATCH --mem=16G
#SBATCH -p qGPU120
#SBATCH --gres=gpu:V100:1
#SBATCH -A CHEM9C4
#SBATCH -e %J.err
#SBATCH -o %J.out
#SBATCH --exclude=acidsgcn002,acidsgcn010,acidsgcn011,acidsgcn012
#--------------------------------------------------------------#

# Load modules
module load gromacs/2024.4-gpu

# Set environment variables
export Project=$SLURM_JOB_NAME
#export WorkDir=/scratch/users/$USER/$SLURM_JOBID
export WorkDir=/dev/shm/$USER/$SLURM_JOBID
export InpDir=NOMEDIRETTORI
export outdir=NOMEDIRETTORI/output

# Record job details
echo $SLURM_JOB_NODELIST > $InpDir/nodename
echo $SLURM_JOBID > $InpDir/jobid

# Create output and working directories
mkdir $outdir
mkdir -p $WorkDir

#-------------------------------------------------------------#
# Start job
#-------------------------------------------------------------#

# Copy input files to working directory
cp $InpDir/* $WorkDir
cd $WorkDir

#Run
gmx mdrun -nt 16 -s $Project.tpr -o $Project.trr -x $Project.xtc -c final-$Project.gro -nb gpu

# Copy results to output directory and clean up
cp $WorkDir/* $outdir/
rm -r $WorkDir
