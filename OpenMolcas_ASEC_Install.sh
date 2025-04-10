#!/bin/bash

#
#  Before running this script be sure cmaker is working
#

cont="b"
while [[ $cont != "y" && $cont != "n" ]]; do
   echo ""
   echo " OpenMolcas-Tinker will be downloaded and installed here:"
   echo "$PWD"
   echo ""
   echo "Is it ok? (y/n)"
   read cont
done

#
# It is not recommended to use very recent gcc-gfortran compiler.
# Openmolcas is a wrapper which contains old fortran codes
#
#module load Compilers/cmake3.9.2i
#module load GCC/4.8.5
module load GCCcore/6.4.0 
module load CMake/3.9.4-GCCcore-6.4.0 

if [[ $cont == "n" ]]; then
   exit 0
fi
if [[ -d "OpenMolcas" ]]; then
   echo "OpenMolcas folder exists"
   exit 0
fi
if [[ -d "build" ]]; then
   echo "build folder exists"
   exit 0
fi
#
# Download latest OpenMolcas
#

git clone https://gitlab.com/Molcas/OpenMolcas.git
cd OpenMolcas
git submodule update --init External/lapack

#
# A few changes to source code needed for APEC
#

sed -i "s/      nMax=100/      nMax=10000/" src/slapaf_util/box.f
sed -i "/Logical IfOpened/a\ \ \ \ \ \ Logical Do_ESPF" src/rasscf/rasscf.f
sed -i "/ but consider extending it to other cases/a\ \ \ \ \ \ call DecideOnESPF(Do_ESPF)" src/rasscf/rasscf.f
sed -i "/call DecideOnESPF(Do_ESPF)/a\ \ \ \ \ \ !write(LF,*) ' |rasscf> DecideOnESPF == ',Do_ESPF" src/rasscf/rasscf.f
cd ..

#alternatively, if you already have a specific version of OpenMolcas downloaded as a tar file:
#tar -xvzf OpenMolcas.tar.gz

mkdir build
cd build
#
# We are using our local python because the version in the nodes did not have the pyparsing module installed.
# Also to avoid future changes in the modules.
#
cmake -DPYTHON_EXECUTABLE:FILEPATH=/userapp/APEC_GOZEM/Python-3.6.2/bin/python3 ../OpenMolcas
#cmake ../OpenMolcas
make

cp ../get_tinker_Openmolcas sbin/get_tinker
cp ../OpenMolcas/Tools/patch2tinker/patch_tinker-6.3.3.diff sbin
#This last line requires that OpenMolcas was installed successfully at this path:
bin/pymolcas get_tinker

