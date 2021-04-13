all: \
spreman.wav \
nsenzora.wav \
nlijevi.wav \
ndesni.wav \
nkartice.wav \
nmjesta.wav \
trazim.wav \
tisuca.wav \
1.wav \

1.wav : brojevi.sh
	./brojevi.sh

%.wav : %.txt
	espeak-ng -v hr -a 98 -f $< -w /tmp/speak.wav; sox /tmp/speak.wav --no-dither -r 11025 -b 8 $@ reverse trim 1s reverse

clean:
	rm -f *.wav *~

