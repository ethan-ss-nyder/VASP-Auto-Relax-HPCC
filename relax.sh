# Automates VASP relaxations on MSU's HPCC.
# NOTE: This script assumes the initial self-consistent run has been done already,
# and does not perform the final self-consistent run.

# By Ethan S. Snyder, 12/12/2024

################################################## FUNCTIONS ######################################################

function print_usage() {
	echo -e "\nUsage: $(basename "$0") [options]"
	echo -e "\n\nOptions:"
	echo "-n, --number            number of desired iterations, must be greater than 0. Does not include self-consistent runs. "
	echo "-h, --help              display this help text, then exit"
	echo -e "\nSpecifically for use on MSU's HPCC."
	exit 0
}

############################################## PARSE CALL-TIME FLAGS ##############################################

iterations=0
flags_defined=false

# Handles flags operations and variable setting
while getopts 'n:h' flag; do
	case "${flag}" in
		n) iterations=$OPTARG flags_defined=true ;;
		h) flags_defined=true print_usage ;;
	esac
done

# Handles the case where no flags were defined
if [ "$flags_defined" = false ]; then
	echo "Exiting. No flags defined. Use -h for help."
	exit 1
elif [ $iterations -le 0 ]; then
	echo "Please use a positive number. What were you trying to achieve?"
	echo "Use -h for help."
	exit 1
fi

###################################### FIND AND VALIDATE JOBSCRIPT FILE ##########################################

# Ask user for jobscript file name
echo "Input the jobscript file name:"
read -p "(Default: ./jobscript*)" jobscriptFileName

# If the user input is blank, use find their exact jobscript file name using "ls jobscript*"
if [ -z "$jobscriptFileName" ]; then

	# Take the first file name output by "ls jobscript*" and discard any errors
	jobscriptFileName=$(ls jobscript* 2>/dev/null | head -n 1)

	# Check if this file exists (ls may return empty). If file DNE, exit.
	if [ ! -f "$jobscriptFileName" ]; then
		echo "No file jobscript* found in working directory. Exiting."
		exit 1
	fi
		
# If the file name provided isn't found, exit the script
elif [ -z "$(ls | grep $jobscriptFileName)" ]; then
	echo "Jobscript file not found. Exiting."
	exit 0
fi

# Correct the user's jobscript file if needed, adding "cp CONTCAR POSCAR"
if grep -q "^cp CONTCAR POSCAR$" "$jobscriptFileName"; then
	echo "$jobscriptFileName is correctly configured! Continuing..."
else
	# awk magic. Creates a temporary file with 'cp CONTCAR POSCAR' a line before the srun line.
	awk '/^srun/ {print "cp CONTCAR POSCAR"} {print}' "$jobscriptFileName" > "${jobscriptFileName}.tmp" \
		&& mv "${jobscriptFileName}.tmp" "$jobscriptFileName"
	echo "Adding 'cp CONTCAR POSCAR' to jobscript file..."
fi

###################################### ITERATIVELY QUEUE CHIANED JOBS ##########################################

# Grab the user's queue before and after adding to it
sq > temp1.txt
sbatch $jobscriptFileName
sq > temp2.txt

# Queue up the desired amount of relaxations, chaining them together
for ((i = 1; i < $iterations; i++)); do

	# Since temp2 contains the ID of temp1's job, diff the files to eliminate that
	diff temp1.txt temp2.txt > temp3.txt

	# Parse out the 8 digit string (the job ID) from the newest temp file
	id=$(grep -o '\b[0-9]\{8\}\b' "temp3.txt")

	# Submit the job, record the queue before and after
	sq > temp1.txt
	sbatch -d afterok:"$id" $jobscriptFileName
	sq > temp2.txt
done

# Before exiting, clean up the mess
rm temp1.txt temp2.txt temp3.txt
