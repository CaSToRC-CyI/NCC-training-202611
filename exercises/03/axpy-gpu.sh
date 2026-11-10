#!/bin/bash
#SBATCH -J axpy-gpu
#SBATCH -o axpy-gpu.txt
#SBATCH -e axpy-gpu.err
#SBATCH -p rtx
#SBATCH -A edu30
#SBATCH --reservation=edu30
#SBATCH -t 00:05:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --cpus-per-task=8
#SBATCH --gres=gpu:1

export OMP_PLACES=cores
export OMP_PROC_BIND=close
export OMP_NUM_THREADS=8      # <-- EDIT ME: CPU threads, try 1, 2, 4, 8
NTHR=1024                     # <-- EDIT ME: GPU threads per block, try 1, 32, 64, ..., 1024

N=$((1024*1024*64))
srun --cpus-per-task=$SLURM_CPUS_PER_TASK ./axpy-gpu $N $NTHR
