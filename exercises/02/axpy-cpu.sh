#!/bin/bash
#SBATCH -J axpy-cpu
#SBATCH -o axpy-cpu.txt
#SBATCH -e axpy-cpu.err
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
export OMP_NUM_THREADS=1      # <-- EDIT ME: try 1, 2, 4, 8

N=$((1024*1024*64))
srun --cpus-per-task=$SLURM_CPUS_PER_TASK ./axpy-cpu $N
