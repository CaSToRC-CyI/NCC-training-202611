#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <sys/time.h>
#include <omp.h>
#include <cuda_runtime.h>

/* Number of times axpy is repeated; the reported time is the average */
#define NREP 10

/***
 * Print usage
 ***/
void
usage(char *argv[])
{
  fprintf(stderr, "usage: %s N NTHR\n", argv[0]);
  fprintf(stderr, "       N:    length of vectors x and y\n");
  fprintf(stderr, "       NTHR: number of GPU threads per block\n");
  return;
}

/***
 * Allocate memory; print error if NULL is returned
 ***/
void *
ualloc(size_t size)
{
  void *ptr = malloc(size);
  if(ptr == NULL) {
    fprintf(stderr, "malloc() returned null; quitting...\n");
    exit(-2);
  }
  return ptr;
}

/***
 * Allocate memory on GPU; print error if not successful
 ***/
void *
gpu_alloc(size_t size)
{
  void *ptr;
  cudaError_t err = cudaMalloc(&ptr, size);
  if(err != cudaSuccess) {
    fprintf(stderr, "cudaMalloc() returned %s; quitting...\n", cudaGetErrorString(err));
    exit(-2);
  }
  return ptr;
}

/***
 * Return a pseudo-random number in [0, 1) that depends only on i, so
 * that arrays can be initialized in parallel
 ***/
float
hrand(uint64_t i)
{
  uint64_t z = i + 0x9e3779b97f4a7c15ULL;
  z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9ULL;
  z = (z ^ (z >> 27)) * 0x94d049bb133111ebULL;
  z = z ^ (z >> 31);
  return (float)((z >> 40) / (double)(1ULL << 24));
}

/***
 * Return seconds elapsed since t0, with t0 = 0 the epoch
 ***/
double
stop_watch(double t0)
{
  struct timeval t;
  gettimeofday(&t, NULL);
  return (double)t.tv_sec + (double)t.tv_usec/1e6 - t0;
}

/***
 * Do y <- a*x + y on the CPU using OpenMP
 ***/
void
axpy(long n, float a, float *x, float *y)
{
#pragma omp parallel for
  for(long i=0; i<n; i++)
    y[i] = a*x[i] + y[i];

  return;
}

/***
 * Do y <- a*x + y on the GPU. Each GPU thread updates one element
 ***/
__global__ void
gpu_axpy(long n, float a, float *x, float *y)
{
  long idx = threadIdx.x + (long)blockIdx.x*blockDim.x;
  if(idx < n)
    y[idx] = a*x[idx] + y[idx];
  return;
}

int
main(int argc, char *argv[])
{
  /*
   * If number of arguments are not as expected, print usage and exit
   */
  if(argc != 3) {
    usage(argv);
    return 1;
  }

  long n = atol(argv[1]);
  int nthr = atoi(argv[2]);

  float *x0 = (float *)ualloc(sizeof(float)*n);
  float *x1 = (float *)ualloc(sizeof(float)*n);
  float *y0 = (float *)ualloc(sizeof(float)*n);
  float *y1 = (float *)ualloc(sizeof(float)*n);

  /*
   * Initialize a and arrays
   */
  float a = hrand(2*n);
#pragma omp parallel for
  for(long i=0; i<n; i++) {
    x0[i] = hrand(i);
    x1[i] = x0[i];
    y0[i] = hrand(i+n);
    y1[i] = y0[i];
  }

  double n_flop = 2;
  double n_io = 3*sizeof(float);

  /*
   * A: Run axpy() on the CPU, return to y0, report performance
   */
  {
    axpy(n, a, x0, y0);
    double t0 = stop_watch(0);
    for(int r=0; r<NREP; r++)
      axpy(n, a, x0, y0);
    t0 = stop_watch(t0)/NREP;

    int ncpu = omp_get_max_threads();
    printf(" CPU: nthr = %4d                    t0 = %8.6lf sec   P = %8.3lf Gflop/s   B = %8.3lf GB/s\n",
           ncpu, t0, n_flop*n/1e9/t0, n_io*n/1e9/t0);
  }

  /*
   * B: Run gpu_axpy() on the GPU, return to y1, report performance
   */
  {
    /* Allocate GPU memory and copy x1 and y1 to the GPU */
    float *d_x = (float *)gpu_alloc(n*sizeof(float));
    float *d_y = (float *)gpu_alloc(n*sizeof(float));
    cudaMemcpy(d_x, x1, sizeof(float)*n, cudaMemcpyHostToDevice);
    cudaMemcpy(d_y, y1, sizeof(float)*n, cudaMemcpyHostToDevice);

    /* Number of blocks needed so that there is one thread per element */
    long nblck = (n + nthr - 1)/nthr;

    /* Warm-up call; also checks that the kernel can be launched */
    gpu_axpy<<<nblck, nthr>>>(n, a, d_x, d_y);
    cudaError_t err = cudaDeviceSynchronize();
    if(err == cudaSuccess)
      err = cudaGetLastError();
    if(err != cudaSuccess) {
      fprintf(stderr, " GPU: kernel with %d threads per block failed: %s\n",
              nthr, cudaGetErrorString(err));
      return 3;
    }

    double t0 = stop_watch(0);
    for(int r=0; r<NREP; r++)
      gpu_axpy<<<nblck, nthr>>>(n, a, d_x, d_y);
    cudaDeviceSynchronize();
    t0 = stop_watch(t0)/NREP;

    printf(" GPU: nthr = %4d   nblck = %9ld   t0 = %8.6lf sec   P = %8.3lf Gflop/s   B = %8.3lf GB/s\n",
           nthr, nblck, t0, n_flop*n/1e9/t0, n_io*n/1e9/t0);

    /* Copy y1 back from the GPU and free GPU memory */
    cudaMemcpy(y1, d_y, sizeof(float)*n, cudaMemcpyDeviceToHost);
    cudaFree(d_x);
    cudaFree(d_y);
  }

  /* Compare y1 and y0 */
  double diff = 0;
  double norm = 0;
  for(long i=0; i<n; i++) {
    double d = y0[i]-y1[i];
    diff += d*d;
    norm += (double)y0[i]*y0[i];
  }
  printf(" Diff = %e\n", diff/norm);

  free(x0);
  free(x1);
  free(y0);
  free(y1);
  return 0;
}
