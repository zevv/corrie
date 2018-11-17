
all: corrienim


BIN   	= corrie
SRC 	= main.cpp biquad.c corr.cpp audio.c

PKG	+= fftw3 sdl2 sdl2 SDL2_ttf
CFLAGS  += -Wall -Werror
CFLAGS	+= -O3 -MMD
CFLAGS	+= -g
CXXFLAGS += -std=c++11
LDFLAGS += -g
LIBS	+= -lm

CPPFLAGS += $(shell pkg-config --cflags $(PKG))
LDFLAGS	+= $(shell pkg-config --libs $(PKG))

CROSS	=
OBJS    = $(subst .c,.o, $(subst .cpp,.o, $(SRC)))
DEPS    = $(subst .c,.d, $(SRC))
CC 	= $(CROSS)gcc
CXX	= $(CROSS)g++
LD 	= $(CROSS)g++

$(BIN):	$(OBJS)
	$(LD) $(LDFLAGS) -o $@ $(OBJS) $(LIBS)

clean:
	rm -f $(OBJS) $(BIN) core

corrienim: c
	
c: $(wildcard *.nim) Makefile
	nim c -d:debug --debugger:native c.nim

crel: $(wildcard *.nim) Makefile
	nim c -d:release -o:crel c.nim

-include $(DEPS)
