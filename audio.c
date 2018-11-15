
#include <stdio.h>
#include <assert.h>
#include <SDL.h>
#include "audio.h"

SDL_AudioDeviceID dev;
static int evnr;

static void on_audio(void *userdata, Uint8* stream, int len)
{
	void *data = malloc(len);
	memcpy(data, stream, len);

	SDL_Event ev;
	ev.type = evnr;
	ev.user.code = len;
	ev.user.data1 = data;

	SDL_PushEvent(&ev);
}


int audio_init(void)
{
	SDL_AudioSpec want, have;


        int count = SDL_GetNumAudioDevices(0);
        for (int i = 0; i < count; ++i) {
		printf("%s\n",  SDL_GetAudioDeviceName(i, 1));
        }

	evnr = SDL_RegisterEvents(1);

	SDL_memset(&want, 0, sizeof(want));
	want.freq = SRATE;
	want.format = AUDIO_F32;
	want.channels = 2;
	want.samples = BLOCK_SIZE;
	want.callback = on_audio;

	dev = SDL_OpenAudioDevice(NULL, 1, &want, &have, 0);
	if(dev == 0) {
		fprintf(stderr, "SDL_OpenAudioDevice(): %s\n", SDL_GetError());
		exit(1);
	}

	assert(have.format == want.format);
	SDL_PauseAudioDevice(dev, 0);

	return evnr;
}

