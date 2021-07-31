all: \
ready.wav \
nsensor.wav \
nleft.wav \
nright.wav \
ncard.wav \
nfree.wav \
wait.wav \
record.wav \
searchgps.wav \
searchobd.wav \
lstrong.wav \
rstrong.wav \
webserver.wav \
point.wav \
1.wav \

1.wav : numbers.sh
	./numbers.sh

%.wav : %.txt
	./txt2wav.sh $< $@

clean:
	rm -f *.wav *~
