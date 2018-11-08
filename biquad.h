#ifndef lib_biquad_h
#define lib_biquad_h

#include <stdbool.h>

struct biquad {
	float inv_srate;
	float x1, x2;
	float y0, y1, y2;
	float b0_a0, b1_a0, b2_a0;
	float a1_a0, a2_a0;
	bool initialized;
	bool first;
};

enum biquad_type {
	BIQUAD_TYPE_LP,
	BIQUAD_TYPE_HP,
	BIQUAD_TYPE_BP,
	BIQUAD_TYPE_BS,
};

/*
 * Initialze biquad filter
 */

int biquad_init(struct biquad *bq, float srate);
int biquad_config(struct biquad *bq, enum biquad_type type, float freq, float Q);

/*
 * Run biquad filer with new sample input, produces new filtered sample
 */

float biquad_run(struct biquad *bq, float v_in);

#endif
