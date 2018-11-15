#include <stdio.h>
#include <stdint.h>
#include <assert.h>
#include <string.h>
#include <math.h>
#include <unistd.h>
#include <stdlib.h>
#include <complex>
#include <map>

using namespace std;

#include <SDL.h>
#include <SDL_ttf.h>

#include <fftw3.h>

#include "biquad.h"
#include "audio.h"

#define FFT_SIZE 1024
#define SPEED_OF_SOUND 300.0
#define MIC_SEP 0.06
#define F_MAX (SRATE*0.5)
#define F_LOW_CUT 80
#define F_HIGH_CUT (SPEED_OF_SOUND / MIC_SEP)
//#define F_HIGH_CUT F_MAX
	

SDL_Window *win;
SDL_Surface *surf;
SDL_Renderer *rend;

TTF_Font *font;

int win_w = 1280;
int win_h = 720;
int audio_ev_nr = 0;
double in[2][FFT_SIZE];
complex<double> out[2][FFT_SIZE];
complex<double> mul[FFT_SIZE];
double corr[FFT_SIZE];
double corr_avg[FFT_SIZE];
double hamming[FFT_SIZE];
double peak;
struct biquad lp[2];

fftw_plan plan0, plan1, plan2;

void init(void)
{

	SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO);
	win = SDL_CreateWindow("corrie",
		SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
		win_w, win_h,
		SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE);
	rend = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);
	
	audio_ev_nr = audio_init();

	SDL_RendererInfo info;
	SDL_GetRendererInfo(rend, &info);
	printf("%s\n", info.name);

	TTF_Init();
	font = TTF_OpenFont("font.ttf", 13);
	assert(font);

	memset(out, 0, sizeof(out));
	memset(mul, 0, sizeof(mul));
	memset(corr, 0, sizeof(corr));
	memset(corr_avg, 0, sizeof(corr_avg));

	float a0 = 0.54;
	float a1 = 1 - a0;
	for(int i=0; i<BLOCK_SIZE; i++) {
		hamming[i] = a0 - a1 * cos(2*3.141592*i/(BLOCK_SIZE-1));
		hamming[i] = 1.0;
	}

	plan0 = fftw_plan_dft_r2c_1d(FFT_SIZE, in[0], reinterpret_cast<fftw_complex*>(out[0]), FFTW_ESTIMATE);
	plan1 = fftw_plan_dft_r2c_1d(FFT_SIZE, in[1], reinterpret_cast<fftw_complex*>(out[1]), FFTW_ESTIMATE);
	plan2 = fftw_plan_dft_c2r_1d(FFT_SIZE, reinterpret_cast<fftw_complex*>(mul), corr, FFTW_ESTIMATE);

	biquad_init(&lp[0], SRATE);
	biquad_init(&lp[1], SRATE);
	biquad_config(&lp[0], BIQUAD_TYPE_HP, F_LOW_CUT, 0.7);
	biquad_config(&lp[1], BIQUAD_TYPE_HP, F_LOW_CUT, 0.7);
}

void calc(void);
void draw(void);

void handle_audio(SDL_Event *e)
{
	int len = e->user.code;
	void *data = e->user.data1;
	float *tmp = (float *)data;

	for(int i=0; i<BLOCK_SIZE; i++) {
		in[0][i] = biquad_run(&lp[0], *tmp++) * hamming[i];
		in[1][i] = biquad_run(&lp[1], *tmp++) * hamming[i];
		//in[0][i] = cos(i * 0.2) * hamming[i];
		//in[1][i] = cos(i * 0.2 + 0.1) * hamming[i];;
	}

	free(data);
		
	calc();
	draw();
}


void calc(void)
{
	/* Correlation by FFT */

	fftw_execute(plan0);
	fftw_execute(plan1);

	int i_from = FFT_SIZE * 0.5 * F_LOW_CUT / F_MAX;
	int i_to = FFT_SIZE * 0.5 * F_HIGH_CUT / F_MAX;
	double scale = 1.0 / FFT_SIZE * 2;
	for(int i=0; i<FFT_SIZE; i++) {
		if(i < i_from || i > i_to) {
			out[0][i] = out[1][i] = 0.0;
		}
		out[0][i] *= scale;
		out[1][i] *= scale;
		mul[i] = out[0][i] * conj(out[1][i]);
	}

	fftw_execute(plan2);

	/* Find peaks */

	int imax = 0;
	double max = 0;
	double a = 10.0;
	for(int i=0; i<FFT_SIZE; i++) {
		corr_avg[i] = corr_avg[i] + corr[i] * a;
		if(corr_avg[i] > max) {
			max = corr_avg[i];
			imax = i ;
		}
	}

	/* scale correlation */

	for(int i=0; i<FFT_SIZE; i++) {
		corr_avg[i] = corr_avg[i] / max;
	}

	/* Interpolate true peak */

	int n = imax;
	int nl = (imax - 1 + FFT_SIZE) % FFT_SIZE;
	int nr = (imax + 1 + FFT_SIZE) % FFT_SIZE;
	peak = n + (corr_avg[nr] - corr_avg[nl]) /
		(2 * ( 2*corr_avg[n] - corr_avg[nl] - corr_avg[nr]));
	if(peak > FFT_SIZE/2) peak -= FFT_SIZE;

}


std::map<string, SDL_Texture *> text_map;

void draw_text(std::string s, int x, int y)
{
	SDL_Texture *tex;

	auto it = text_map.find(s);
	if(it != text_map.end()) {
		tex = it->second;
	} else {
		SDL_Color fg = { 0, 212, 144 };
		SDL_Surface * surface = TTF_RenderText_Blended(font, s.c_str(), fg);
		tex = SDL_CreateTextureFromSurface(rend, surface);
		SDL_FreeSurface(surface);
		text_map[s] = tex;
	}

	int w, h;
	SDL_QueryTexture(tex, NULL, NULL, &w, &h);
	SDL_Rect dst = { x, y, w, h };
	
	SDL_RenderCopy(rend, tex, NULL, &dst);
}



void in_box(std::string label, void (*fn)(SDL_Rect *r), int x, int y, int w, int h)
{
	x += 2;
	y += 2;
	w -= 4;
	h -= 4;

	SDL_Rect r = { x, y, w, h };
	SDL_SetRenderDrawColor(rend, 0, 0, 0, 255);
	SDL_RenderFillRect(rend, &r);

	SDL_SetRenderDrawColor(rend, 0, 0, 0, 255);
	SDL_RenderFillRect(rend, &r);

	SDL_RenderSetClipRect(rend, &r);
	fn(&r);
	SDL_RenderSetClipRect(rend, NULL);
	
	draw_text(label, r.x+5, r.y+5);
	
	SDL_SetRenderDrawColor(rend, 100, 100, 100, 255);
	SDL_RenderDrawRect(rend, &r);
}


void channel_color(int c)
{
	if(c == 1) {
		SDL_SetRenderDrawColor(rend, 180, 0, 255, 255);
	} else {
		SDL_SetRenderDrawColor(rend, 0, 255, 0, 255);
	}
}


void draw_grid(SDL_Rect *r, int xdiv, int ydiv)
{
	SDL_SetRenderDrawColor(rend, 255, 255, 255, 32);

	for(int i=0; i<=ydiv; i++) {
		int y = r->y + r->h * i / ydiv;
		SDL_RenderDrawLine(rend, r->x, y, r->x+r->w, y);
	}
	for(int i=0; i<=xdiv; i++) {
		int x = r->x + r->w * i / xdiv;
		SDL_RenderDrawLine(rend, x, r->y, x, r->y + r->h);
	}
}


void draw_corr(SDL_Rect *r)
{
	draw_grid(r, 10, 6);

	SDL_Point point[FFT_SIZE];
	int range = F_MAX * MIC_SEP / SPEED_OF_SOUND + 1;
	range = FFT_SIZE/2;
	int n = 0;
	for(int i=-range; i<range; i++) {
		int j = i >= 0 ? i : i+FFT_SIZE;
		point[n].x = r->x + r->w /2 + i * r->w / (range * 2);
		point[n].y = r->y + r->h*0.5 + 0.5 * r->h * - corr_avg[j];
		n ++;
	}
	SDL_SetRenderDrawColor(rend, 0, 212, 144, 0xFF );
	SDL_RenderDrawLines(rend, point, n);
}


void draw_scope(SDL_Rect *r)
{
	draw_grid(r, 10, 4);
	
	SDL_SetRenderDrawBlendMode(rend, SDL_BLENDMODE_ADD);

	for(int j=0; j<2; j++) {
		SDL_Point point[BLOCK_SIZE];
		for(int i=0; i<BLOCK_SIZE; i++) {
			point[i].x = r->x + i * r->w / BLOCK_SIZE;
			point[i].y = r->y + in[j][i] * r->h/2 + r->h/2;
		}
		channel_color(j);
		SDL_RenderDrawLines(rend, point, BLOCK_SIZE-1);
	}
	SDL_SetRenderDrawBlendMode(rend, SDL_BLENDMODE_BLEND);
}


void draw_fft(SDL_Rect *r)
{
	draw_grid(r, 10, 6);

	SDL_Point point[FFT_SIZE];
	
	SDL_SetRenderDrawBlendMode(rend, SDL_BLENDMODE_ADD);
	
	for(int j=0; j<2; j++) {
		int i_from = FFT_SIZE * 0.5 * F_LOW_CUT / F_MAX; 
		int i_to = FFT_SIZE * 0.5 * F_HIGH_CUT / F_MAX;
		int i_range = i_to - i_from;
		double p = 0;
		for(int i=0; i<=i_range; i++) {
			double v = 4 * abs(out[j][i+i_from]);
			if(v > p) p = v;
			point[i].x = r->x + r->w * i / (i_range-1);
			point[i].y = r->y - log(v) * r->h * 0.15;
		}
		channel_color(j);
		SDL_RenderDrawLines(rend, point, i_range);
	}
	
	SDL_SetRenderDrawBlendMode(rend, SDL_BLENDMODE_BLEND);
}


void draw_waterfall(SDL_Rect *r)
{
	static SDL_Texture *tex = NULL;
	static int y = 0;
	int hist = 200;

	if(tex == NULL) {
		SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "linear");
		tex = SDL_CreateTexture(rend, SDL_PIXELFORMAT_RGBA8888, SDL_TEXTUREACCESS_STREAMING, FFT_SIZE/2, hist);
	}

	void *pixels = NULL;
	int pitch;
	int rv = SDL_LockTexture(tex, NULL, &pixels, &pitch);
	
	if(rv == 0) {
		uint8_t *p8 = reinterpret_cast<uint8_t *>(pixels) + pitch * y;
		uint32_t *p = reinterpret_cast<uint32_t *>(p8);
		for(int i=0; i<FFT_SIZE/2; i++) {
			double v[2];
			for(int j=0; j<2; j++) {
				v[j] = log(abs(out[j][i]));
				v[j] = v[j]*0.2 + 1.8;
				if(v[j] < 0.0) v[j] = 0.0;
				if(v[j] > 1.0) v[j] = 1.0;
			}
			*p = (int)(v[0]*180) << 24 |
			     (int)(v[1]*255) << 16 |
			     (int)(v[0]*255) << 8  |
			     (255          ) << 0;
			p++;
		}
		y = (y+1 ) % hist;
	}

	SDL_UnlockTexture(tex);
	
	int i_from = FFT_SIZE * 0.5 * F_LOW_CUT / F_MAX;
	int i_to = FFT_SIZE * 0.5 * F_HIGH_CUT / F_MAX;
	int y2 = y * r->h / hist;
	{
		SDL_Rect rs = { i_from, y, i_to-i_from, hist-y };
		SDL_Rect rd = { r->x, r->y, r->w, r->h - y2 };
		SDL_RenderCopy(rend, tex, &rs, &rd);
	}
	{
		SDL_Rect rs = { i_from, 0, i_to-i_from, y };
		SDL_Rect rd = { r->x, r->y + r->h - y2, r->w, y2 };
		SDL_RenderCopy(rend, tex, &rs, &rd);
	}
}


void draw(void)
{
	SDL_SetRenderDrawColor(rend, 50, 50, 50, 255);
	SDL_RenderClear(rend);
	SDL_SetRenderDrawBlendMode(rend, SDL_BLENDMODE_BLEND);

	in_box("corr", draw_corr, 0, 0, win_w, win_h/2);
	in_box("wave", draw_scope, 0, win_h/2, win_w/2, win_h/2);
	in_box("FFT", draw_fft, win_w/2, win_h*0.75, win_w/2, win_h/4);
	in_box("FFT", draw_waterfall, win_w/2, win_h*0.5, win_w/2, win_h/4);

	{

		double x = win_w/2 + peak*100;
		SDL_SetRenderDrawColor(rend, 255, 0, 255, 255);
		SDL_RenderDrawLine(rend, x, 0, x, win_h/2);
		x ++;
		SDL_RenderDrawLine(rend, x, 0, x, win_h/2);
	}

	SDL_RenderPresent(rend);
	SDL_UpdateWindowSurface(win);
}


void events(void)
{
	SDL_Event e;
	while(SDL_PollEvent(&e)) {
		if(e.type == SDL_QUIT) exit(0);
		if(e.type == SDL_WINDOWEVENT) {
			if (e.window.event == SDL_WINDOWEVENT_RESIZED) {
				 win_w = e.window.data1;
				 win_h = e.window.data2;
			}
		}
		if(e.type == audio_ev_nr) {
			handle_audio(&e);
		}
	}
}
