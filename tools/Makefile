all:wav kml

wav: wav.c
	gcc $< -o $@

kml: kml.c
	gcc $< -o $@

clean:
	rm -f wav

hex: wav
	./wav
	hexdump -C accel.wav | less
