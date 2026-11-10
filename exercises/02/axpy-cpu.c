#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <sys/time.h>
#include <omp.h>

/* Number of times axpy() is repeated; the reported time is the average */
#define NREP 10

/***
 * Print usage
 ***/
void
usage(char *argv[])
{
  fprintf(stderr, "usage: %s N\n", argv[0]);
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

int
main(int argc, char *argv[])
{
  /*
   * If number of arguments are not as expected, print usage and exit
   */
  if(argc != 2) {
    usage(argv);
    return 1;
  }

  long n = atol(argv[1]);

  float *x = (float *)ualloc(sizeof(float)*n);
  float *y = (float *)ualloc(sizeof(float)*n);

  /*
   * Initialize a and arrays
   */
  float a = hrand(2*n);
#pragma omp parallel for
  for(long i=0; i<n; i++) {
    x[i] = hrand(i);
    y[i] = hrand(i+n);
  }

  /*
   * Run axpy() once as a warm-up, then NREP times, report average performance
   */
  axpy(n, a, x, y);
  double t0 = stop_watch(0);
  for(int r=0; r<NREP; r++)
    axpy(n, a, x, y);
  t0 = stop_watch(t0)/NREP;

  double n_flop = 2;
  double n_io = 3*sizeof(float);
  int nthr = omp_get_max_threads();
  printf(" CPU: nthr = %4d   t0 = %8.6lf sec   P = %8.3lf Gflop/s   B = %8.3lf GB/s\n",
         nthr, t0, n_flop*n/1e9/t0, n_io*n/1e9/t0);

  free(x);
  free(y);
  return 0;
}
