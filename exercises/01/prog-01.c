#include <unistd.h>           
#include <stdio.h>            
#include <sys/types.h>        



int
main(int argc, char *argv[])
{
  char hname[256];         
  pid_t p;                 
  gethostname(hname, 256); 
  p = getpid();            
  printf(" Hostname: %s, pid: %lu\n", hname, p); 
  return 0; 
            
}
