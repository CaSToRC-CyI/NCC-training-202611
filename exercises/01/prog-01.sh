#!/bin/bash
#SBATCH -J prog-01
#SBATCH -o prog-01.txt
#SBATCH -e prog-01.err
#SBATCH -p rtx
#SBATCH -A edu30
#SBATCH --reservation=edu30
#SBATCH -t 00:01:00
#SBATCH -N 1
#SBATCH -n 4
#SBATCH --gres=gpu:1

echo " Job ID:      $SLURM_JOB_ID"
echo " Node(s):     $SLURM_JOB_NODELIST"
echo " Processes:   $SLURM_NTASKS"

srun ./p01
