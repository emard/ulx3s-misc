all: spreman.wav nsenzora.wav nlijevi.wav ndesni.wav nkartice.wav nmjesta.wav cekam.wav

%.wav : %.txt
	espeak-ng -v hr -a 98 -f $< -w /tmp/speak.wav; sox /tmp/speak.wav --no-dither -r 11025 -b 8 $@ reverse trim 1s reverse

clean:
	rm -f *.wav *~

