#!/bin/sh

#for i in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 30 40 50 60 70 80 90 100 200 300 400 500 600 700 800 900 1000 2000 3000
for i in 0 1 2 3 4 5 6 7 8 9
do
  echo " $i " > /tmp/broj.txt
  ./txt2wav.sh /tmp/broj.txt $i.wav
done
