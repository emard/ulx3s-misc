all:wav kml

wav: wav.c
	gcc $< -o $@

kml: kml.c
	gcc $< -o $@

clean:
	rm -f wav kml

hex: wav
	./wav
	hexdump -C accel.wav | less
