
corrie: main.c Makefile
	gcc -g -Wall -Werror main.c -o corrie -lm \
		`pkg-config --cflags --libs fftw3 sdl2 libpulse-simple sdl2 SDL2_ttf`

clean:
	rm corrie

