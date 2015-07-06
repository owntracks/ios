#!/bin/bash

INK=/Applications/Inkscape.app/Contents/Resources/bin/inkscape
IMAGEW=imagew

if [[ -z "$1" ]] 
then
	echo "SVG file needed."
	exit;
fi

BASE=`basename "$1" .svg`
SVG="$1"
MYPWD=`pwd`

# need to use absolute paths in OSX

$INK -z -C -e "$MYPWD/$BASE-33.png" -f 		$MYPWD/$SVG -w 33 -h 33
$INK -z -C -e "$MYPWD/$BASE-33@2x.png" -f 	$MYPWD/$SVG -w 66 -h 66
$INK -z -C -e "$MYPWD/$BASE-33@3x.png" -f 	$MYPWD/$SVG -w 99 -h 99
