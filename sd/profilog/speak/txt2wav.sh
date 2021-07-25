#!/bin/sh
espeak-ng -v hr -a 98 -f $1 -w /tmp/speak.wav; sox /tmp/speak.wav --no-dither -r 11025 -b 8 $2 reverse trim 1s reverse

# to play without clicks, last byte should end with 80 and not 00
# if it doesn't ends with 80, then try to trim 1 sample from the end

for i in 1 2 3 4 5
do
lastbytehex=$(tail --byte 1 $2 | od -An -tx1 -w1 -v)
if [ ${lastbytehex} -ne "80" ]
then
  sox /tmp/speak.wav --no-dither -r 11025 -b 8 $2 reverse trim ${i}s reverse
else
  exit 0
fi
done

# check again, if still ends with 00 report clicks warning:

lastbytehex=$(tail --byte 1 $2 | od -An -tx1 -w1 -v)
if [ ${lastbytehex} -ne "80" ]
then
  echo "CLICKS warning: $2 last byte is not 0x80"
fi
exit 1
