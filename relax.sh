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

# Submit the first job and catch its job ID from stdout
id=$(sbatch $jobscriptFileName 2>&1 | tee /dev/tty | grep -o '[0-9]\{8\}')

# Queue up the desired amount of relaxations, chaining them together
for ((i = 1; i < $iterations; i++)); do

	# Use the last submitted job ID as a dependency to the new job,
	# then record the new jobs ID for next iteration.
	id=$(sbatch -d afterok:"$id" $jobscriptFileName 2>&1 | tee /dev/tty | grep -o '[0-9]\{8\}')

done
