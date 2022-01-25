#!/bin/sh
for x in $*
do
  flac --silent -d -f $x
done