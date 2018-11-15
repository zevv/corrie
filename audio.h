#ifndef audio_h
#define audio_h

#ifdef __cplusplus
extern "C" {
#endif

#define BLOCK_SIZE 512
#define SRATE 48000

int audio_init(void);
void audio_read(void *buf, size_t len);

#ifdef __cplusplus
}
#endif

#endif
