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

$INK -z -C -e "$MYPWD/$BASE-25.png" -f 		$MYPWD/$SVG -w 25 -h 25
$INK -z -C -e "$MYPWD/$BASE-25@2x.png" -f 	$MYPWD/$SVG -w 50 -h 50
$INK -z -C -e "$MYPWD/$BASE-25@3x.png" -f 	$MYPWD/$SVG -w 75 -h 75

$IMAGEW -negate "$MYPWD/$BASE-25.png" "$MYPWD/$BASE-25-negate.png"
$IMAGEW -negate "$MYPWD/$BASE-25@2x.png" "$MYPWD/$BASE-25-negate@2x.png"
$IMAGEW -negate "$MYPWD/$BASE-25@3x.png" "$MYPWD/$BASE-25-negate@3x.png"
