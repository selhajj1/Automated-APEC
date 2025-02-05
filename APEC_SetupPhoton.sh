templatedir='/userapp/APEC_Spr2023/New_APEC/template'

echo "

Is your PDB local or on the PDB Databank Server?

1. Local (i.e. in the same directory as this script)
2. PDB Databank Server

"
read pbdLocation

if [ $pbdLocation -eq 1 ]; then

      echo "
      
      What is the name of your PDB file? (Exclude the .pdb extension)"
      read pdbName
           echo  ""
      echo "            Found $pdbName.pdb. " 


elif [ $pbdLocation -eq 2 ]; then
      echo ""
      echo "
      
      What is the PDB ID of your PDB file? "
      read pdbName

      #Download PDB from Protein Data Bank
      wget https://files.rcsb.org/download/$pdbName.pdb

      if [[ ! -f $pdbName.pdb ]]; then 
         echo ""
         echo "PDB file not found."
         echo ""
         echo "Please download manually."
         echo ""
         exit 0
      fi
      echo  ""
      echo "            Found and Downloaded $pdbName.pdb. " 

else
   echo "Enter a valid number."
   exit 0
fi


awk '{ if ($1 == "ATOM") { print } else if ($1 == "TER") { print } else if ($1 == "HETATM"){print}}' $pdbName.pdb > ${pdbName}Clean.pdb
rm $pdbName.pdb


Chains=()

while read p; do 
      chain=`echo "$p" | awk -vFS="" '{print $22}'`
      if [[ "${Chains[@]}" =~ $chain ]]; then
               :
      else
         # echo "Nuh Huh"
         Chains+=("$chain")
      fi

      # echo "${Chains[*]}"
done < ${pdbName}Clean.pdb

NoOfChains=${#Chains[@]}

if (( $NoOfChains > 0 )); then
   echo "
   
   "


   echo This protein has $NoOfChains chain[s]: 
   for key in "${!Chains[@]}"
   do
      echo "$(( $key + 1 )): ${Chains[$key]}"
   done

   if [ $NoOfChains -eq 1 ] ; then
        echo "
   
            "
         echo "Therefore, I will use chain A."
         egrep "^.{21}A" ${pdbName}Clean.pdb > ${pdbName}Monomer.pdb

   else
      echo "
      Which would you like to use? (Enter Alphabet)
      "
      read input

      ChainChoice=`echo $input | awk '{print toupper($0)}'`
      echo $ChainChoice

      if [[ "${Chains[@]}" =~ $ChainChoice ]]; then
         egrep "^.{21}$ChainChoice" ${pdbName}Clean.pdb > ${pdbName}Monomer.pdb
         rm ${pdbName}Clean.pdb
      else
         exit
      fi


   fi
fi

#Extracting the chromophore
   
  

extractChromophore () {
   #Figuring out the Flavin Variant
   flavinVariant=`egrep -h "FMN|FAD" ${pdbName}Monomer.pdb | grep "HETATM" | awk '{print $4;exit}'`
   
   #Search for Flavin Variant in cleaned up PDB, print the atom label and xyz coordinates to flavin.xyz  
   grep -E "$flavinVariant" ${pdbName}Monomer.pdb | grep "HETATM" | awk '{print $(NF) "\t" $(NF-5) "\t" $(NF-4) "\t" $(NF-3)}' > flavin.xyz                                                                 

   ##Count lines in flavin.xyz
   lines=`wc flavin.xyz | awk '{print $1}'`

   #Echo this number into CHR.xyz (xyz files always start with the number of atoms in the file.)
      echo "${lines}" > CHR.xyz 

   #And the second line in every xyz file is always a comment, echo an empty string to this line. 
      echo "" >> CHR.xyz 

   #copy flavin.xyz content into CHR.xyz
   cat flavin.xyz >> CHR.xyz

   #To Prepare Monomer file
   #Search for lines Containing Flavin Variant in PDB and echo them into fl.xyz
   grep -E "$flavinVariant" ${pdbName}Monomer.pdb | grep "HETATM" | awk '{print}' > fl.xyz 
   
   #Remove the lines in fl.xyz found in ${pdbName}Monomer.pdb 
   grep -vf fl.xyz ${pdbName}Monomer.pdb > ${pdbName}APEC.pdb
   
 
  
   #Remove Intermediate Setup Files
   rm flavin.xyz fl.xyz ${pdbName}Monomer.pdb 
   
}

extractChromophore


   echo " "
   echo "" 
   echo ""
   echo " "
   echo " Extracted $flavinVariant from $pdbName.pdb."
   echo ""
   echo " "
   echo ""
   echo " "

echo "***************************************************************

               Hydrogenating The Chromophore

***************************************************************

"


#Convert Chromphore to Mol2 
obabel -ixyz CHR.xyz -omol2 -0 CHR.mol2 > CHR.mol2

# Remove default connectivities and save to Final.mol2
sed -n '/BOND/q;p' CHR.mol2 > CHRFinal.mol2


echo "

What oxidation state do you want to run calculations on?

1. Quinone
2. Anionic Semiquinone
3. Neutral Semiquinone
4. Anionic Hydroquinone 
5. Neutral Hydroquinone 

Enter 1, 2, 3, 4, or 5.

"

read oxidationState

if [ $oxidationState -eq 1 ] || [ $oxidationState -eq 2 ]; then
      oxid=""
elif [ $oxidationState -eq 3 ] || [ $oxidationState -eq 4 ]; then
        oxid="H"
elif [ $oxidationState -eq 5 ] ; then
        oxid="H2"
else

echo "

Enter a valid number please.

"
exit 0
fi

# Add FlavinVariant Oxidation State Template Connectivities to Final.mol2
sed -n '/BOND/,$p' $templatedir/${flavinVariant}/${flavinVariant}${oxid}/${flavinVariant}${oxid}.mol2 >> CHRFinal.mol2


# #Convert CHRFinal to xyz and Hydrogenate.
obabel -imol2 CHRFinal.mol2 -oxyz -O ${pdbName}_${flavinVariant}${oxid}.xyz -h
obabel -imol2 CHRFinal.mol2 -omol2 -O ${pdbName}_${flavinVariant}${oxid}.mol2 -h


# Change .xyz file heading
CHRlines=`wc ${pdbName}_${flavinVariant}${oxid}.xyz | awk '{print $1}'`
newCHRlength=$(( CHRlines-4 ))
sed -i'.bak' "1s/.*/$newCHRlength/" ${pdbName}_${flavinVariant}${oxid}.xyz

#  Remove Excess Hydrogens from Phosphate and Renumber hydrogen atoms
if [ $flavinVariant = "FMN" ]; then
      #In FMNH2 the indices of H1,2 & 3 are incorrect, this fixes that.
      if [ $oxidationState -eq 3 ] ; then
         printf '%s\n' 34m35 35-m34- w q | ed -s ${pdbName}_${flavinVariant}${oxid}.xyz
         printf '%s\n' 35m36 36-m35- w q | ed -s ${pdbName}_${flavinVariant}${oxid}.xyz
      fi


      sed -i'.bak' '$d' ${pdbName}_${flavinVariant}${oxid}.xyz
      sed -i'.bak' '$d' ${pdbName}_${flavinVariant}${oxid}.xyz
else

      #In FADH2 the indices of H1,2 & 3 are incorrect, this fixes that. Relevant because the charges 
      # if [ $oxidationState -eq 3 ] ; then
      #    printf '%s\n' 69m70 70-m69- w q | ed -s ${pdbName}_${flavinVariant}${oxid}.xyz
      #    printf '%s\n' 70m71 71-m70- w q | ed -s ${pdbName}_${flavinVariant}${oxid}.xyz
      # fi
      
      # Remove Hydrogens from Phosphate 
      sed -i'.bak' '56d' ${pdbName}_${flavinVariant}${oxid}.xyz
      sed -i'.bak' '$d' ${pdbName}_${flavinVariant}${oxid}.xyz
fi 

rm -r CHR.mol2 CHRFinal.mol2 CHR.xyz


#Create CHR_chain.xyz

# Get Atom Labels 
echo ${newCHRlength} > atomLabels && echo "" >> atomLabels 
awk -v CHRfileLength="$(( newCHRlength + 2 ))" 'NR>=3 && NR<=CHRfileLength { print $1 }' $templatedir/${flavinVariant}/${flavinVariant}${oxid}/manchester_${flavinVariant}${oxid}_rtp >> atomLabels 

#Get Coordinates
echo "" > coord && echo "" >> coord
awk -v CHRfileLength="$(( newCHRlength + 2 ))" 'NR>=3 && NR<=CHRfileLength {print " \t" $2 " \t" $3 " \t" $4 }' ${pdbName}_${flavinVariant}${oxid}.xyz >> mid
column -t -s $'\t' mid >> coord

paste atomLabels coord > interMediate

# Get Atom Types
echo "" > new && echo "" >> new
awk -v CHRfileLength="$(( newCHRlength + 2 ))" 'NR>=3 && NR<=CHRfileLength { print $2 }' $templatedir/${flavinVariant}/${flavinVariant}${oxid}/manchester_${flavinVariant}${oxid}_rtp >> new 
paste interMediate new > almostDone

#Get QM/MM Labels
paste almostDone $templatedir/${flavinVariant}/${flavinVariant}${oxid}/${flavinVariant}${oxid}QMMMLabels.txt > CHR_chain.xyz 

rm mid atomLabels coord interMediate new almostDone

#Get Bonding Information
sed -n '/bond/,$p' $templatedir/${flavinVariant}/${flavinVariant}${oxid}/manchester_${flavinVariant}${oxid}_rtp | tail -n+2 >> CHR_chain.xyz  

rm ${pdbName}_${flavinVariant}${oxid}.xyz.bak


#Remove B Conformers of Residues And A Conformer Identifiers if Available 
awk '{ if(substr($0, 17, 1) != "B") print }' ${pdbName}APEC.pdb > temp && mv temp ${pdbName}APEC.pdb
awk 'BEGIN{FS=OFS=""} {sub(".", " ", $17)} 1' ${pdbName}APEC.pdb > temp && mv temp ${pdbName}APEC.pdb

mv ${pdbName}_${flavinVariant}${oxid}.mol2 temp.mol2 && mv ${pdbName}_${flavinVariant}${oxid}.xyz temp.xyz

if [ $oxidationState -eq 2 ]; then
      oxid="-"
elif [ $oxidationState -eq 4 ]; then
        oxid="H-"
else
      :
fi

mv temp.mol2 ${pdbName}_${flavinVariant}${oxid}.mol2 && mv temp.xyz ${pdbName}_${flavinVariant}${oxid}.xyz 
awk '{$2=FNR}1' ${pdbName}APEC.pdb | column -t > temp && mv temp ${pdbName}APEC.pdb

mkdir ${pdbName}_${flavinVariant}${oxid}_APEC_Calculation_Files
mv ${pdbName}_${flavinVariant}${oxid}.mol2 CHR_chain.xyz ${pdbName}_${flavinVariant}${oxid}.xyz  ${pdbName}APEC.pdb ${pdbName}_${flavinVariant}${oxid}_APEC_Calculation_Files/

cp $templatedir/New_APEC.sh ${pdbName}_${flavinVariant}${oxid}_APEC_Calculation_Files/
rm ${pdbName}Clean.pdb &> /dev/null 

#cp /data/PHO_WORK/sajagbe2/QMMM/LOVCalculations/UpdatedScripts/New_APEC.sh ${pdbName}_${flavinVariant}${oxid}_APEC_Calculation_Files/

echo ""
echo ""
echo " ***********************************************************************"
echo ""
echo "  Please check that 1 molecule converted is printed above."
echo "  The warning about failure to kekulize aromatic bonds can be ignored."
echo "  PDB and flavin coordinates extracted. To run APEC:"
echo "  1) cd ${pdbName}_${flavinVariant}${oxid}_APEC_Calculation_Files/"
echo "  2) Run ./New_APEC.sh."
echo ""
echo " ***********************************************************************"
echo ""

exit 0


