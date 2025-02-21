This script automates the process of running multiple relaxation jobs back-to-back on Michigan State University's High-Performance Computing Center for VASP calculations.

Requirements:
1. This script is in the working directory (with the INCAR, POSCAR, POTCAR, KPOINTS, and jobscript files).
2. For proper use, self-consistent (NSW=0) should be done before and after this script is run.

TODO:
1. Add feature that optimizes wall clock times within the jobscript file based on "grep Elapsed OUTCAR" output from previous job. This would be quite a bit of work involving more jobscript file editing, but would be very useful for "set it and forget it" functionality. This would allow the user to set a large wall clock initially, but for further jobs to be more efficient.
2. In addition to setting the wall clock, I'd like an option that can read 'mag=' values from stdout for spin polarized jobs, can toggle ISPIN off, and can adjust the wallclock accordingly for efficient chaining of spin polarized jobs.
3. Allow the usage of this script from any directory to any other directory instead of needing this script in the working directory.
