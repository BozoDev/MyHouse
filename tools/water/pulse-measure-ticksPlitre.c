#include <stdio.h>
#include <pigpio.h>

#define HALL 26

void alert(int gpio, int level, uint32_t tick)
{
   static uint32_t lastTick=0;
   static int counter=0;

   if ( level != 1 )
      return;
   if ( counter < 75 ) {
      counter++;
      return;
   } else {
      if (lastTick) printf("%.4f\n", (float)(tick-lastTick)/1000000.0);
      counter = 0;
  }
//   else          printf("0.00\n");

   lastTick = tick;
}

int main(int argc, char *argv[])
{
   int secs=60;

   if (argc>1) secs = atoi(argv[1]); /* program run seconds */

   if ((secs<1) || (secs>3600)) secs = 3600;

   if (gpioInitialise()<0) return 1;

   gpioSetMode(HALL, PI_INPUT);

   gpioSetPullUpDown(HALL, PI_PUD_UP);

   gpioSetAlertFunc(HALL, alert);

   sleep(secs);

   gpioTerminate();
}
