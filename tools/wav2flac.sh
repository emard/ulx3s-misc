#!/bin/sh
for x in $*
do
  flac --silent --channel-map=none  --ignore-chunk-sizes $x
done
