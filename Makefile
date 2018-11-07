
corrie: main.c Makefile
	gcc -g -Wall -Werror main.c -o corrie -lm `pkg-config --cflags --libs fftw3 sdl2 libpulse-simple`

clean:
	rm corrie

