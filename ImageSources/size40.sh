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

$INK -D --export-type="png" --export-filename "$MYPWD/$BASE-40.png"	-w 40 -h 40 $MYPWD/$SVG
$INK -D --export-type="png" --export-filename "$MYPWD/$BASE-40@2x.png"	-w 80 -h 80 $MYPWD/$SVG
$INK -D --export-type="png" --export-filename "$MYPWD/$BASE-40@3x.png"	-w 120 -h 120 $MYPWD/$SVG

$IMAGEW "$MYPWD/$BASE-40.png" "$MYPWD/$BASE-40-noalpha.png"
$IMAGEW "$MYPWD/$BASE-40@2x.png" "$MYPWD/$BASE-40-noalpha@2x.png"
$IMAGEW "$MYPWD/$BASE-40@3x.png" "$MYPWD/$BASE-40-noalpha@3x.png"
