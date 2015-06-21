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

$INK -z -D -e "$MYPWD/$BASE-40.png" -f 		$MYPWD/$SVG -w 40 -h 40
$INK -z -D -e "$MYPWD/$BASE-40@2x.png" -f 	$MYPWD/$SVG -w 80 -h 80
$INK -z -D -e "$MYPWD/$BASE-40@3x.png" -f 	$MYPWD/$SVG -w 120 -h 120
