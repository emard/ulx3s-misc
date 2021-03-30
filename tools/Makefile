wav: wav.c
	gcc $< -o $@

clean:
	rm -f wav

hex: wav
	./wav
	hexdump -C accel.wav | less
