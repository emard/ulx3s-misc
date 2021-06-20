all: \
spreman.wav \
nsenzora.wav \
nlijevi.wav \
ndesni.wav \
nkartice.wav \
nmjesta.wav \
cekam.wav \
trazim.wav \
1.wav \

1.wav : brojevi.sh
	./brojevi.sh

%.wav : %.txt
	./txt2wav.sh $< $@

clean:
	rm -f *.wav *~
