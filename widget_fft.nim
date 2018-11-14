import math
import sdl2/sdl
import fftw3
import random
import widget
import gui
import app
import strutils
import textcache

const FFTSIZE_MAX = 16384


proc abs(v: fftw_complex): cdouble =
  return sqrt(v[0] * v[0] + v[1] * v[1])

type
  WindowType = enum
    Blackman, Gaussian, Cauchy, Hanning, Hamming, Welch, Rect

  WidgetFFT = ref object of Widget
    gui: Gui
    window: array[BLOCKSIZE_MAX, float]
    winType: WindowType
    winAdj: float
    input: array[FFTSIZE_MAX, cdouble]
    output: array[FFTSIZE_MAX, fftw_complex]
    fftSize: int
    plan: fftw_plan
    db_top, db_range: float
    cursorX: int

proc rect(x: int): float =
  return 1.0

proc setWindowType(w: WidgetFFT, t: WindowType) =
  w.winType = t
  let beta = w.winAdj
  for x in 0..BLOCKSIZE_MAX-1:
    let i = 2 * float(x) / float(BLOCKSIZE_MAX)
    var v = 0.0
    case t
      of Blackman:
        v = 0.42 - 0.5 * cos(PI * i) + 0.08 * cos(2 * PI * i)
      of Gaussian:
        v = pow(E, -0.5 * (beta * (1.0 - i))^2)
      of Cauchy:
        v = 1.0 / (1.0 + (beta * (1.0 - i))^2)
      of Hamming:
        v = 0.54 - 0.46 * cos(PI * i)
      of Hanning:
        v = 0.5 - 0.5 * cos(PI * i)
      of Welch:
        v = 1.0 - (i - 1.0)^2
      of Rect:
        v = 1.0
    w.window[x] = v


proc setFFTSize(w: WidgetFFT, s: int) =
  w.fftSize = s
  if w.plan != nil:
    fftw_destroy_plan(w.plan)
  w.plan = fftw_plan_dft_r2c_1d(w.fftsize, addr(w.input[low(w.input)]),
             addr(w.output[low(w.output)]), FFTW_ESTIMATE)


proc newWidgetFFT*(app: App): WidgetFFT =
  var w = WidgetFFT()

  w.db_top = 0.0
  w.db_range = -200.0
  w.fftsize = 1024
  w.winAdj = 1.0
  w.gui = newGui(app.rend, app.textcache)

  w.setWindowType(Gaussian)
  w.setFFTSize(w.fftsize)

  return w


var ss  = 1.0


method label(w: WidgetFFT): string =
  return "FFT " & $w.fftSize & " " & $w.winType & "/" & formatFloat(w.winAdj, precision=2)
 
method draw(w: WidgetFFT, app: App, buf: AudioBuffer) =

  proc db2y(v: float): int =
      return int(-v * float(w.h) / -w.db_Range)

  # Grid

  ss = ss * 1.00001
  discard app.rend.setRenderDrawColor(30, 30, 30, 255)
  var step = -5.0
  while db2y(step) < 16:
    step = step * 2
  var v = step
  while v > w.db_range:
    let y = db2y(v)
    discard app.rend.renderDrawLine(0, y, w.w, y)
    app.textCache.drawText(align($int(v), 4), 3, y)
    v = v + step
 
  # FFT

  discard setRenderDrawBlendMode(app.rend, BLENDMODE_ADD);

  let n = min(w.fftsize, BLOCKSIZE_MAX)
  let scale = 1.0 / float(n/2)
  for j in 0..1:
    for i in 0..BLOCKSIZE_MAX-1:
      var v = buf.data[i][j]
      #v = cos(float(i) * PI * 0.550) * 0.5 +
      #    cos(float(i) * PI * 0.555) * 0.5 
      #v = v + rand(0.00001)
      #v = if v > 0: -1 else: 1
      w.input[i] = v * scale * w.window[i]

    fftw_execute(w.plan)

    let n = w.fftsize /% 2 - 1
    var p: array[FFTSIZE_MAX, sdl.Point]
    let scale = float(w.h) / float(n)
    for i in 0..n-1:
      let v = abs(w.output[i])
      let vdb = if v>0 : 20 * log10(v) else: -w.db_range
      let y = db2y(vdb)
      p[i].x = 30 + cint((w.w - 30) * i / n)
      p[i].y = cint(y)
    
    app.rend.channelColor(j)

    discard app.rend.renderDrawLines(addr(p[0]), n)
  
  # Cursor

  if true:
    discard setRenderDrawBlendMode(app.rend, BLENDMODE_ADD);
    discard app.rend.setRenderDrawColor(255, 255, 255, 60)
    var f = float(w.cursorX - 30)
    var f1 = f / 32.0
    var f2 = f * 32.0
    if f1 > 0:
      while f1 <= f2:
        var x = int(30 + int(f1))
        discard app.rend.renderDrawLine(x, 0, x, w.h)
        if f1 < f:
          f1 = f1 * 2
        else:
          f1 = f1 + f


  discard setRenderDrawBlendMode(app.rend, BLENDMODE_BLEND);

  # Window

  if true:
    var p: array[BLOCKSIZE_MAX, sdl.Point]
    for i in 0..BLOCKSIZE_MAX-1:
      let v = w.window[i]
      let y = v * float(w.h)
      p[i].x = cint(w.w * i / BLOCKSIZE_MAX)
      p[i].y = w.h - cint(y)

    discard app.rend.setRenderDrawColor(0, 0, 255, 255)
    discard app.rend.renderDrawLines(addr(p[0]), BLOCKSIZE_MAX)

  # Gui

  w.gui.start(210, 10)
  if w.gui.button(1, "Click me"): echo "click"
  discard w.gui.button(2, "No thanks")
  if w.gui.select(3, "Window", addr w.winType):
    w.setWindowType(w.winType)
  
  if w.winType == Gaussian or w.winType == Cauchy:
    if w.gui.slider(4, "beta", w.winAdj, 0.1, 40.0):
      w.setWindowType(w.winType)


method handleMouse*(w: WidgetFFT, x, y: int): bool =
  w.gui.mouseMove(x, y)
  w.cursorX = x
  return true

method handleButton*(w: WidgetFFT, x, y: int, state: bool): bool =
  w.gui.mouseButton(x, y, if state: 1 else: 0)
  return true

method handleKey(w: WidgetFFT, key: Keycode, x, y: int): bool =

  if key == K_LEFTBRACKET:
    w.winAdj = max(w.winAdj * 0.9, 0.1)
    w.setWindowType(w.winType)
  
  if key == K_RIGHTBRACKET:
    w.winAdj = min(w.winAdj / 0.9, 40.0)
    w.setWindowType(w.winType)

  if key == K_s:
    var s = w.fftsize
    if s < FFTSIZE_MAX:
      s = s * 2
    else:
      s = 64
    w.setFFTSize(s)
    return true

  if key == K_w:
    var t = w.winType
    if t == high(WindowType):
      t = low(WindowType)
    else:
      inc(t)
    w.setWindowType(t)
    return true


# vi: ft=nim sw=2 ts=2
