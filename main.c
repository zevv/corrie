#include <stdio.h>
#include <stdint.h>
#include <assert.h>
#include <string.h>
#include <math.h>
#include <unistd.h>
#include <stdlib.h>
#include <SDL.h>
#include <complex.h>

#include <fftw3.h>

#include <pulse/simple.h>
#include <pulse/error.h>

#define BLOCK_SIZE 256
#define FFT_SIZE 256
#define W 1024
#define H 512
#define SRATE 48000
#define SPEED_OF_SOUND 300.0
#define MIC_SEP 0.06
#define F_LOW_CUT 170
#define F_MAX (SRATE*0.5)
#define F_HIGH_CUT (SPEED_OF_SOUND / MIC_SEP)
//#define F_HIGH_CUT F_MAX
	
static const pa_sample_spec ss = {
	.format = PA_SAMPLE_FLOAT32LE,
	.rate = SRATE,
	.channels = 2
};

static const pa_buffer_attr ba = {
	.maxlength = -1,
	.tlength = -1,
	.prebuf = -1,
	.minreq = -1,
	.fragsize = BLOCK_SIZE,
};

pa_simple *pa = NULL;
double in[2][FFT_SIZE];
fftw_complex out[2][FFT_SIZE];
fftw_complex mul[FFT_SIZE];
double corr[FFT_SIZE];
double corr_avg[FFT_SIZE];
double hamming[FFT_SIZE];
SDL_Window *win;
SDL_Surface *surf;
SDL_Renderer *rend;
double peak;

fftw_plan plan0, plan1, plan2;

void init(void)
{
	memset(out, 0, sizeof(out));
	memset(corr_avg, 0, sizeof(corr_avg));

	float a0 = 0.54;
	float a1 = 1 - a0;
	for(int i=0; i<BLOCK_SIZE; i++) {
		hamming[i] = a0 - a1 * cos(2*3.141592*i/(BLOCK_SIZE-1));
		hamming[i] = a0 - a1 * cos(2*3.141592*i/(BLOCK_SIZE-1));
	}

	plan0 = fftw_plan_dft_r2c_1d(FFT_SIZE, in[0], out[0], FFTW_ESTIMATE);
	plan1 = fftw_plan_dft_r2c_1d(FFT_SIZE, in[1], out[1], FFTW_ESTIMATE);
	plan2 = fftw_plan_dft_c2r_1d(FFT_SIZE, mul, corr, FFTW_ESTIMATE);
}



void rec(void)
{
	/* Record audio block */

	float tmp[BLOCK_SIZE][2];
	int error;
	pa_simple_read(pa, tmp, sizeof(tmp), &error);
	
	/* Window input data */

	for(int i=0; i<BLOCK_SIZE; i++) {
		in[0][i] = tmp[i][0] * hamming[i];
		in[1][i] = tmp[i][1] * hamming[i];
	}
}


void calc(void)
{
	/* Correlation by FFT */

	fftw_execute(plan0);
	fftw_execute(plan1);

	int i_from = FFT_SIZE * 0.5 * F_LOW_CUT / F_MAX;
	int i_to = FFT_SIZE * 0.5 * F_HIGH_CUT / F_MAX;

	memset(mul, 0, sizeof(mul));
	for(int i=0; i<i_from; i++) {
		out[0][i] = out[1][i] = 0;
	}
	for(int i=i_to; i<FFT_SIZE; i++) {
		out[0][i] = out[1][i] = 0;
	}

	for(int i=i_from; i<i_to; i++) {
		mul[i] = out[0][i] * conj(out[1][i]);
	}

	fftw_execute(plan2);

	/* Find peaks */

	int imax = 0;
	double max = 0;
	double a = 0.98;
	double scale = 1.0 / FFT_SIZE;
	for(int i=0; i<FFT_SIZE; i++) {
		corr_avg[i] = corr_avg[i] * a + corr[i] * scale * (1-a);
		if(corr_avg[i] > max) {
			max = corr_avg[i];
			imax = i ;
		}
	}
	
	fprintf(stderr, "%f\n", max);

	/* scale correlation */

	for(int i=0; i<FFT_SIZE; i++) {
		if(1) corr_avg[i] = corr_avg[i] / max;
	}

	/* Interpolate true peak */

	int n = imax;
	int nl = (imax - 1 + FFT_SIZE) % FFT_SIZE;
	int nr = (imax + 1 + FFT_SIZE) % FFT_SIZE;
	peak = n + (corr_avg[nr] - corr_avg[nl]) /
		(2 * ( 2*corr_avg[n] - corr_avg[nl] - corr_avg[nr]));
	if(peak > FFT_SIZE/2) peak -= FFT_SIZE;

}


void draw(void)
{
	SDL_SetRenderDrawColor(rend, 0, 0, 0, 255);
	SDL_RenderClear(rend);
		

	if(1) {
		SDL_Point point[FFT_SIZE];
		int range = F_MAX * MIC_SEP / SPEED_OF_SOUND + 1;
		range = FFT_SIZE/2;
		int n = 0;
		for(int i=-range; i<range; i++) {
			int j = i >= 0 ? i : i+FFT_SIZE;
			point[n].x = W /2 + i * W / (range * 2);
			point[n].y = H * (1.01 - corr_avg[j]);
			n ++;
		}
		SDL_SetRenderDrawColor(rend, 0xFF, 0x00, 0x00, 0xFF );
		SDL_RenderDrawLines(rend, point, n);
	}

	{

		double x = W/2 + peak*100;
		SDL_SetRenderDrawColor(rend, 255, 0, 255, 255);
		SDL_RenderDrawLine(rend, x, 0, x, H/2);
		x ++;
		SDL_RenderDrawLine(rend, x, 0, x, H/2);
	}
	
	SDL_SetRenderDrawColor(rend, 0, 255, 0, 0);

	/* scope */

	for(int j=0; j<2; j++) {
		SDL_Point point[BLOCK_SIZE];
		for(int i=0; i<BLOCK_SIZE; i++) {
			point[i].x = i * W / BLOCK_SIZE * 0.5;
			point[i].y = in[j][i] * H/2 + H*0.75;
		}
		SDL_RenderDrawLines(rend, point, BLOCK_SIZE-1);
	}

	/* FFT */

	SDL_Point point[FFT_SIZE];
	for(int i=0; i<FFT_SIZE; i++) {
		point[i].x = W/2 + i * W / FFT_SIZE;
		point[i].y = H - 10 - cabs(out[0][i]) * 20;
	}
	SDL_RenderDrawLines(rend, point, BLOCK_SIZE-1);
	

	SDL_RenderPresent(rend);
	SDL_UpdateWindowSurface(win);
}


int main(int argc, char **argv)
{
	SDL_Init(SDL_INIT_VIDEO);
	win = SDL_CreateWindow("corrie",
		SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
		W, H,
		SDL_WINDOW_SHOWN );
	rend = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);

	int error;
	pa = pa_simple_new(NULL, argv[0], PA_STREAM_RECORD, NULL, "record", &ss, NULL, &ba, &error);
	assert(pa);

	init();

	for(;;) {
		rec();
		calc();
		draw();

	}

	return 0;
}
