STratosphere presents
                  THE 80's SlideShow

Code  : Nanard
GfX   : Jojo073
Music : Karsten Obarski (YM2149F conversion by Estrayk)

Should run on any Atari ST / STe / Mega STe - 50Hz
We have still bombs with some HD drivers...

Press ESC to quit during the show, any other key to skip to the next picture.
The color activity indicator at the bottom right of the screen is :
 - green :  ready
 - orange : loading from disk
 - blue :   decoding IFF picture

A Party version has been released for the Cookie demoparty held in Paris
December 3rd 2016 - http://cookie.paris/
http://www.pouet.net/prod.php?which=68597
This Party version has glitches on STe machines.

Music composed in maxYMiser.
Pictures drawn using Deluxe Paint (on amiga ;) http://jojo073.blogspot.fr/
Coded using VASM and Hatari on a linux PC. UPX is used to pack PRG.

This is an open source production :
https://github.com/miniupnp/AtariST/tree/master/the_80s

Tested on : Mega STe (TOS 2.06 es)
            2080 STe (TOS 1.06 fr)
            1040 STf (TOS 1.00 fr)
            1040 STfm (TOS 1.04 de)

TODO :
 run OK on 60HZ machines ?
 test with EMUTOS
 proper ASCII logo
 own IKBD handler to fix things under TOS 1.00 and 1.02

Programming notes :
Contrary to most demoscene production code, I've tried to be as "OS friendly"
as possible. Everything that can run in usermode does run in usermode, TOS
interrupt routines are still running.
GEMDOS functions are used to load files, etc.
That's because we wanted to be compatible with many machines and load files
from hard disk (Ultra Satan / CosmosEx)



                                                                         nanard
