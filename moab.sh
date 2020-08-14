#! /bin/bash
echo "Starting multiple moab_sim.py processes..."
parallel -j 7 python3 moab_sim.py ::: {1..7}
