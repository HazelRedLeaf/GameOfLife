/////////////////////////////////////////////////////////////////////////////////////////
//
// COMS20001 - Assignment 2
//
/////////////////////////////////////////////////////////////////////////////////////////

typedef unsigned char uchar;

#include <platform.h>
#include <stdio.h>
#include "pgmIO.h"
#include <math.h>
#include <sys/time.h>
#define IMHT 16
#define IMWD 16
#define THREADS 4

out port cled0 = PORT_CLOCKLED_0;
out port cled1 = PORT_CLOCKLED_1;
out port cled2 = PORT_CLOCKLED_2;
out port cled3 = PORT_CLOCKLED_3;
out port cledG = PORT_CLOCKLED_SELG;
out port cledR = PORT_CLOCKLED_SELR;
in port  buttons = PORT_BUTTON;
out port speaker = PORT_SPEAKER;


//DISPLAYS an LED pattern in one quadrant of the clock LEDs
int showLED(out port p, chanend fromVisualiser) {
  unsigned int lightUpPattern;
  while (1) {
    fromVisualiser :> lightUpPattern; //read LED pattern from visualiser process
    if(lightUpPattern==-1)//shutdown on flag
        return 0;
    p <: lightUpPattern;              //send pattern to LEDs
  }
  return 0;
}

//PROCESS TO COORDINATE DISPLAY of LED lights
void visualiser(chanend fromDistributor,
        chanend toQuadrant0, chanend toQuadrant1, chanend toQuadrant2, chanend toQuadrant3, chanend fromIn) {
  int display;
  //int j;
  cledG <: 1;
//  16 - first
//  32 - second
//  64 - third
  int toQ[4];

  while (1)
  {
    for(int i = 0; i<4; i++)
        toQ[i] = 0;
    select
          {
              case fromDistributor :> display:
              break;
              case fromIn :> display:
              break;
          }
    if(display==-1)//if received a shutdown flag
    {
        toQuadrant0 <: -1;
        toQuadrant1 <: -1;
        toQuadrant2 <: -1;
        toQuadrant3 <: -1;
        return;
    }
    for(int i = 11; i>=0; i--)
    {
        if(display>=pow(2,1+i))
        {
                toQ[i/3] += pow(2, 4+i%3);
                display -= pow(2,1+i);
        }
    }
    toQuadrant0 <: toQ[0];
    toQuadrant1 <: toQ[1];
    toQuadrant2 <: toQ[2];
    toQuadrant3 <: toQ[3];
  }
}

//PLAYS a short sound (pls use with caution and consideration to other students in the labs!)
void playSound(unsigned int wavelength, out port speaker) {
  timer  tmr;
  int t, isOn = 1;
  tmr :> t;
  for (int i=0; i<2; i++) {
    isOn = !isOn;
    t += wavelength;
    tmr when timerafter(t) :> void;
    speaker <: isOn;
  }
}

//WAIT function
void waitMoment() {
  timer tmr;
  uint waitTime;
  tmr :> waitTime;
  waitTime += 10000000;
  tmr when timerafter(waitTime) :> void;
}

//READ BUTTONS and send to distributor
void buttonListener(in port b, out port spkr, chanend toDistributor) {
  int r;
  int flag = 2; //-1=shutdown 0= paused, 1=running, 2=not started, 3= save file
  while (1) {
    b when pinsneq(15) :> r;   // check if some buttons are pressed
    playSound(2000000,spkr);   // play sound
    if(flag==2) //if not yet running
    {
        if (r==14)
        {
            toDistributor <: 1; //send start
            flag = 1;
        }
        else if(r==7)
        {
            toDistributor <: -1; //send shutdown
            return;
        }
        else
            continue;

    }
    else if(flag == 1) //if running
    {
        if(r==7)
        {
            toDistributor <: -1; //send shutdown
            return;
        }
        else if(r==13)
        {
            toDistributor <: 0; // send pause
            flag = 0;
        }
        else if(r==11)
        {
            toDistributor <: 3;// send save file flag
        }
        else
            continue;
    }
    else if(flag == 0) //if paused
    {
        if(r==7)
        {
            toDistributor <: -1; //send shutdown
            return;
        }
        else if(r==13)
        {
            toDistributor <: 1; // send restart
            flag = 1;
        }
        else if(r==11)
        {
            toDistributor <: 3;// send save file flag
        }
        else
            continue;
    }
    waitMoment();
    waitMoment();
    waitMoment();
    waitMoment();
  }
}




/////////////////////////////////////////////////////////////////////////////////////////
//
// Read Image from pgm file with path and name infname[] to channel c_out
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataInStream(chanend c_out, chanend toVis)
{
  int res;
  int flag = 0;
  char infname[] = "C:\\Users\\Katka\\Desktop\\16x16.pgm";     //put your input image path here, absolute path
  uchar line[ IMWD ];
  printf( "DataInStream:Start...\n" );
  res = _openinpgm( infname, IMWD, IMHT );
  if( res )
  {
    printf( "DataInStream:Error openening %s\n.", infname );
    return;
  }
  c_out :> flag;
  if(flag==-1)
      return;
  for( int y = 0; y < IMHT; y++ )
  {
    _readinline( line, IMWD );
    for( int x = 0; x < IMWD; x++ )
    {
      c_out <: line[ x ];
     // printf( "-%4.1d ", line[ x ] ); //uncomment to show image values
    }
   // printf( "\n" ); //uncomment to show image values
    int done;
    done = (double)y/(double)IMHT*8192;
    toVis <: done;
  }
  _closeinpgm();
  printf( "DataInStream:Done...\n" );
  return;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Start your implementation by changing this function to farm out parts of the image...
//
/////////////////////////////////////////////////////////////////////////////////////////
void distributor(chanend c_in, chanend c_out,
        chanend worker1, chanend worker2, chanend worker3, chanend worker4,
        chanend butToDis, chanend disToVis)
{
  uchar val;
  int counter;
  int roundNumber = 0;
  int flag = 0; //0 = pause, 1=run
  printf( "ProcessImage:Start, size = %dx%d\n", IMHT, IMWD );
  //This code is to be replaced – it is a place holder for farming out the work...
  int workerHeight = IMHT / THREADS; // number of rows a single worker has to process

  butToDis :> flag;
  if(flag==1)
      c_in <: 1;//just run
  else if(flag == -1)
  {
      worker1 <: -1;
      worker2 <: -1;
      worker3 <: -1;
      worker4 <: -1;
      c_in <: -1;
      //c_out <: -1;
      disToVis <: -1;
      return;
  }
  printf("dist started #n");

  worker1 <: workerHeight;
  worker2 <: workerHeight;
  worker3 <: workerHeight;
  worker4 <: workerHeight;
  for( int y = 1; y <= IMHT; y++ )
  {
    for( int x = 1; x <= IMWD; x++ )
    {
      c_in :> val;
     // val = (uchar)( val ^ 0xFF ); //Need to cast
      if (y <= workerHeight)
      {
          worker1 <: val;
      }
      else if ((y > workerHeight) && (y <= 2*workerHeight))
      {
          worker2 <: val;
      }
      else if ((y > 2*workerHeight) && (y <= 3*workerHeight))
      {
          worker3 <: val;
      }
      else
      {
          worker4 <: val;
      }
    }
  }

  printf( "ProcessImage:Done...\n" );
  startTimer();
  while(1)
  {
      //struct timeval t1, t2;
      //double elapsedTime;
      //clock_gettime();
      // start timer
      //gettimeofday(&t1, NULL);

      int temp;
      counter = 0;
      roundNumber++;

      //get the alive count
      worker1 :> temp;
      counter += temp;
      worker2 :> temp;
      counter += temp;
      worker3 :> temp;
      counter += temp;
      worker4 :> temp;
      counter += temp;
      disToVis <: counter; //send to visualiser

      //check for flags from buttons
      select
      {
          case butToDis :> flag:
              //printf("received %d \n", flag);
              if(flag==-1)
              {
                  worker1 <: -1;
                  worker2 <: -1;
                  worker3 <: -1;
                  worker4 <: -1;
                  c_out <: -1;
                  disToVis <: -1;
                  return;
              }
              else if(flag==0) // received a pause flag
              {
                  disToVis <: roundNumber;
                  while(flag!=1) //until received a run flag
                  {
                      butToDis :> flag;
                      if(flag == 1)//if unpaused, continue
                      {
                          worker1 <: 1;
                          worker2 <: 1;
                          worker3 <: 1;
                          worker4 <: 1;
                      }
                      else if(flag==-1) //if shutdown when paused
                      {
                          worker1 <: -1;
                          worker2 <: -1;
                          worker3 <: -1;
                          worker4 <: -1;
                          c_out <: -1;
                          disToVis <: -1;
                          return;
                      }
                      else if(flag == 3) // if received a save flag
                      {
                          c_out <: 3; //ask dataOut to save the file
                          worker1 <: 3; //and ask workers to send the data
                          worker2 <: 3;
                          worker3 <: 3;
                          worker4 <: 3;
                        for( int y = 1; y <= workerHeight; y++ ) //get the data from workers and send to dataOut
                         {
                           for( int x = 1; x <= IMWD; x++ )
                           {
                               worker1 :> val;
                               c_out <: val;
                           }
                         }
                        for( int y = 1; y <= workerHeight; y++ )
                         {
                           for( int x = 1; x <= IMWD; x++ )
                           {
                               worker2 :> val;
                               c_out <: val;
                           }
                         }
                        for( int y = 1; y <= workerHeight; y++ )
                         {
                           for( int x = 1; x <= IMWD; x++ )
                           {
                               worker3 :> val;
                               c_out <: val;
                           }
                         }
                        for( int y = 1; y <= workerHeight; y++ )
                         {
                           for( int x = 1; x <= IMWD; x++ )
                           {
                               worker4 :> val;
                               c_out <: val;
                           }
                         } //end of sending to dataOut
                        c_out :> val;
                      } // end of received save file flag
                  }//end of while waiting for unpause
              }//end of paused section
              else if(flag == 3) // if received a save flag while running
              {
                  c_out <: 3; //ask dataOut to save the file
                  worker1 <: 3; // and ask workers for data
                  worker2 <: 3;
                  worker3 <: 3;
                  worker4 <: 3;
                  for( int y = 1; y <= workerHeight; y++ ) //get the data from workers and send to dataOut
                   {
                     for( int x = 1; x <= IMWD; x++ )
                     {
                         worker1 :> val;
                         c_out <: val;
                     }
                   }
                  for( int y = 1; y <= workerHeight; y++ )
                   {
                     for( int x = 1; x <= IMWD; x++ )
                     {
                         worker2 :> val;
                         c_out <: val;
                     }
                   }
                  for( int y = 1; y <= workerHeight; y++ )
                   {
                     for( int x = 1; x <= IMWD; x++ )
                     {
                         worker3 :> val;
                         c_out <: val;
                     }
                   }
                  for( int y = 1; y <= workerHeight; y++ )
                   {
                     for( int x = 1; x <= IMWD; x++ )
                     {
                         worker4 :> val;
                         c_out <: val;
                     }
                   } //end of sending to dataOut
                  c_out :> val;//get a response from c_out that it finished and then
                  worker1 <: 1;// keep running
                  worker2 <: 1;
                  worker3 <: 1;
                  worker4 <: 1;
              }//end of save file while running
              break;
          default: //if no buttons pressed just continue
              {
                    worker1 <: 1;
                    worker2 <: 1;
                    worker3 <: 1;
                    worker4 <: 1;
              }
              break;
      }
      if(roundNumber%1000==0)
          endTimer();
  } //end of infinite while
}

void worker(int ID, chanend distributor, chanend previous, chanend next)
{
    uchar chunk[IMHT/4][IMWD];
    uchar newLine[IMWD];//previously calculated line
    uchar oldLine[IMWD];//newly calculated line
    uchar previousLine[IMWD];
    uchar nextLine[IMWD];
    int counter=0;
    int chunkHeight, aliveCounter=0;
    int flag = 1; //1= run

    distributor :> chunkHeight;
    if(chunkHeight==-1) //received a shutdown flag
        return;

    for(int i=0; i<chunkHeight; i++ )
    {
        for( int x = 0; x < IMWD; x++ )
        {
          distributor :> chunk[i][x];
          if (chunk[i][x]==255)
              counter++;
        }
    }
    while(flag)
    {
        if(ID==1)
        {
            for( int x = 0; x < IMWD; x++ )
            {
                next <: chunk[chunkHeight-1][x];
            }

            for( int x = 0; x < IMWD; x++ )
            {
                next :> nextLine[x];
            }
        }
        else if(ID==2)
        {
            for( int x = 0; x < IMWD; x++ )
            {
                previous :> previousLine[x];
            }

            for( int x = 0; x < IMWD; x++ )
            {
                previous <: chunk[0][x];
            }

            for( int x = 0; x < IMWD; x++ )
            {
                next <: chunk[chunkHeight-1][x];
            }

            for( int x = 0; x < IMWD; x++ )
            {
                next :> nextLine[x];
            }

        }
        else if(ID==3)
        {
            for( int x = 0; x < IMWD; x++ )
            {
                next <: chunk[chunkHeight-1][x];
            }
            for( int x = 0; x < IMWD; x++ )
            {
                next :> nextLine[x];
            }

            for( int x = 0; x < IMWD; x++ )
            {
                previous :> previousLine[x];
            }
            for( int x = 0; x < IMWD; x++ )
            {
                previous <: chunk[0][x];
            }
        }
        else if(ID==4)
        {
            for( int x = 0; x < IMWD; x++ )
            {
                previous :> previousLine[x];
            }

            for( int x = 0; x < IMWD; x++ )
            {
                previous <: chunk[0][x];
            }
        }//end of inter-slave line exchange

        //calculate flow
        for(int i=0; i<chunkHeight; i++ )
        {
            for( int x = 0; x < IMWD; x++ )
            {
                counter=0;
                if(x!=0) //left
                    counter+=chunk[i][x-1];
                if(x!=IMWD-1)//right
                    counter += chunk[i][x+1];
                if(i!=0) // up
                {
                    counter += chunk[i-1][x];
                    if (x!=0)
                        counter += chunk[i-1][x-1];
                    if (x!=IMWD-1)
                        counter += chunk[i-1][x+1];
                }
                else //if top row
                {
                    if(ID!=1) //if not top chunk
                    {
                        counter += previousLine[x];
                        if (x!=0)
                            counter += previousLine[x-1];
                        if (x!=IMWD-1)
                            counter += previousLine[x+1];
                    }
                }
                if(i!= chunkHeight-1) // down
                {
                    counter += chunk[i+1][x];
                    if (x!=0)
                        counter += chunk[i+1][x-1];
                    if (x!=IMWD-1)
                        counter += chunk[i+1][x+1];
                }
                else //if bottom row
                {
                    if(ID!=THREADS)
                    {
                        counter += nextLine[x];
                        if (x!=0)
                            counter += nextLine[x-1];
                        if (x!=IMWD-1)
                            counter += nextLine[x+1];
                    }
                }
                counter /= 255;
                if(counter < 2)
                    newLine[x] = 0;
                else if(counter > 3)
                    newLine[x] = 0;
                else if(counter == 3)
                    newLine[x] = 255;
                else //exactly 2
                    newLine[x] = chunk[i][x];
            }//end of line calculation

            if(i!=0)
            for( int x = 0; x < IMWD; x++ )
            {
                chunk[i-1][x] = oldLine[x];
                if(oldLine[x]== 255)
                    aliveCounter++;
            }
            for( int x = 0; x < IMWD; x++ )
            {
                oldLine[x] = newLine[x];
            }
            if(i==chunkHeight-1)
            {
                for( int x = 0; x < IMWD; x++ )
                {
                    chunk[i][x] = oldLine[x];
                    if(oldLine[x]== 255)
                        aliveCounter++;
                }
            }
        } //end of row calculation
        //override the old chunk


        distributor <: aliveCounter;
        aliveCounter=0; //reset alive counter
        flag = 0; //pause until received something from dist

        while(flag!=1) // until received a next round start flag
        {
            distributor :> flag;
            if(flag==-1) //if shutdown, shutdown.
                return;
            else if(flag==3) //if requested data, send it to the dist.
            {
                for(int i=0; i<chunkHeight; i++ ) // and send the data to distr.
                {
                   for( int x = 0; x < IMWD; x++ )
                   {
                       distributor <: chunk[i][x];
                   }
                }
            }
        }
    } //end of while flag

    return;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to pgm image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(chanend c_in)
{
  char outfname[] = "C:\\Users\\Katka\\Desktop\\16x16out.pgm"; //put your output image path here, absolute path
  int res, flag;
  uchar line[ IMWD ];
  while(1)
  {
      c_in :> flag;
      if(flag==-1) // if shutdown, shutdown, else save the file.
          return;
      printf( "DataOutStream:Start...\n" );
      res = _openoutpgm( outfname, IMWD, IMHT );
      if( res )
      {
        printf( "DataOutStream:Error opening %s\n.", outfname );
        return;
      }
      for( int y = 0; y < IMHT; y++ )
      {
        for( int x = 0; x < IMWD; x++ )
        {
          c_in :> line[ x ];
        }
        _writeoutline( line, IMWD );
      }
      _closeoutpgm();

      c_in <: '1'; // just sending something to notify the distributor that saving is finished

      printf( "DataOutStream:Done...\n" );
  }
}

//MAIN PROCESS defining channels, orchestrating and starting the threads
int main()
{
  chan c_inIO, c_outIO, worker1, worker2, worker3, worker4; //extend your channel definitions here
  chan OneToTwo, TwoToThree, ThreeToFour,FourToOne; // interworker channels
  chan butToDis, disToVis, inToVis;
  chan quadrant0,quadrant1,quadrant2,quadrant3; //helper channels for LED visualisation
  par //extend/change this par statement
  {
      on stdcore[1]: DataInStream( c_inIO , inToVis);
      on stdcore[2]: distributor( c_inIO, c_outIO , worker1, worker2, worker3, worker4, butToDis, disToVis);
      on stdcore[3]: DataOutStream( c_outIO );
      on stdcore[0]: worker(1,worker1, FourToOne, OneToTwo);
      on stdcore[1]: worker(2,worker2, OneToTwo, TwoToThree);
      on stdcore[2]: worker(3,worker3, TwoToThree, ThreeToFour);
      on stdcore[3]: worker(4,worker4, ThreeToFour, FourToOne);

      //HELPER PROCESSES
      on stdcore[0]: buttonListener(buttons, speaker,butToDis);
      on stdcore[0]: visualiser(disToVis,quadrant0,quadrant1,quadrant2,quadrant3, inToVis);
      on stdcore[0]: showLED(cled0,quadrant0);
      on stdcore[1]: showLED(cled1,quadrant1);
      on stdcore[2]: showLED(cled2,quadrant2);
      on stdcore[3]: showLED(cled3,quadrant3);
  }
 // printf( "Main:Done...\n" );
  return 0;
}
