#!/bin/bash

INK=`which inkscape`
IMAGEW=`which imagew`

if [[ -z "$1" ]] 
then
	echo "SVG file needed."
	exit;
fi

BASE=`basename "$1" .svg`
SVG="$1"
MYPWD=`pwd`

# need to use absolute paths in OSX

$INK -C --export-type="png" --export-filename "$MYPWD/$BASE-33.png"	-w 33 -h 33 $MYPWD/$SVG
$INK -C --export-type="png" --export-filename "$MYPWD/$BASE-33@2x.png"	-w 66 -h 66 $MYPWD/$SVG
$INK -C --export-type="png" --export-filename "$MYPWD/$BASE-33@3x.png"	-w 99 -h 99 $MYPWD/$SVG

