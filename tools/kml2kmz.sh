#!/usr/bin/sh

for x in $*
do
  ln -s $x doc.kml
  zip -r $(dirname $x)/$(basename $x .kml).kmz doc.kml
  rm doc.kml
done
