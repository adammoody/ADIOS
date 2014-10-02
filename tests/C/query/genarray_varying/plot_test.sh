#!/bin/bash

FN=${1:-q1.bp}
echo Filename=$FN

/ccs/proj/e2e/plotter/sith/plotter2d -f $FN -v xy/original -o xy_original -zonal -min -3 -max 2 -s "t0,0,0" 
/ccs/proj/e2e/plotter/sith/plotter2d -f $FN -v xy/manual   -o xy_manual   -zonal -min -3 -max 2 -s "t0,0,0"
/ccs/proj/e2e/plotter/sith/plotter2d -f $FN -v xy/queried  -o xy_queried  -zonal -min -3 -max 2 -s "t0,0,0"

