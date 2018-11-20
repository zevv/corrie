import math
import sdl2/sdl
import fftw3
import random
import widget
import gui
import app
import strutils
import textcache
import capbuf
import capview


proc abs(v: fftw_complex): cdouble =
  return sqrt(v[0] * v[0] + v[1] * v[1])

type

  WidgetFFT = ref object of Widget
    gui: Gui
    input: seq[cdouble]
    output: seq[fftw_complex]
    plan: fftw_plan
    size: int
    db_top, db_range: float
    cursorX: int
    showFFTOpts: bool
    showWindowOpts: bool
    showXformSize: bool

proc rect(x: int): float =
  return 1.0


proc setSize(w: WidgetFFT, size: int) =

  if size != w.size:
    w.size = size
    if w.plan != nil:
      fftw_destroy_plan(w.plan)

    w.input.setLen(size)
    w.output.setLen(size)
    w.plan = fftw_plan_dft_r2c_1d(size, addr(w.input[low(w.input)]),
               addr(w.output[low(w.output)]), FFTW_ESTIMATE)


proc newWidgetFFT*(app: App): WidgetFFT =
  var w = WidgetFFT()

  w.db_top = 0.0
  w.db_range = -180.0
  w.gui = newGui(app.rend, app.textcache)

  w.setSize(1024)

  return w


var ss  = 1.0


 
method draw(w: WidgetFft, rend: Renderer, app: App, cv: CapView) =
  
  let cb = app.cb
  let offset = cv.getCursor()


  proc db2y(v: float): int =
      return int(-v * float(w.h) / -w.db_Range)

  # Grid

  if true:
    ss = ss * 1.00001
    discard rend.setRenderDrawColor(30, 30, 30, 255)
    var step = -5.0
    while db2y(step) < 16:
      step = step * 2
    var v = step
    while v > w.db_range:
      let y = db2y(v)
      discard rend.renderDrawLine(0, y, w.w, y)
      app.textCache.drawText(align($int(v), 4), 3, y)
      v = v + step
 
  # FFT

  discard setRenderDrawBlendMode(rend, BLENDMODE_ADD);

  let winData = cv.win.getData()
  let size = cv.win.size
  
  w.setSize(size)

  let scale = 1.0 / float(size/2)
  for j in 0..1:
    for i in 0..size-1:
      var v = cb.read(j, i+offset)
      w.input[i] = v * scale * winData[i]

    fftw_execute(w.plan)

    let n = size /% 2 - 1
    var p = newSeq[sdl.Point](n)
    let scale = float(w.h) / float(n)
    for i in 0..n-1:
      let v = abs(w.output[i])
      let vdb = if v>0 : 20 * log10(v) else: -w.db_range
      let y = db2y(vdb)
      p[i].x = 30 + cint((w.w - 30) * i / n)
      p[i].y = cint(y)
    
    rend.channelColor(j)

    discard rend.renderDrawLines(addr(p[0]), n)
  
  # Cursor

  if true:
    discard setRenderDrawBlendMode(rend, BLENDMODE_ADD);
    discard rend.setRenderDrawColor(255, 255, 255, 60)
    var f = float(w.cursorX - 30)
    var f1 = f / 32.0
    var f2 = f * 32.0
    if f1 > 0:
      while f1 <= f2:
        var x = int(30 + int(f1))
        discard rend.renderDrawLine(x, 0, x, w.h)
        if f1 < f:
          f1 = f1 * 2
        else:
          f1 = f1 + f
    discard setRenderDrawBlendMode(rend, BLENDMODE_BLEND);


  # Gui
  
  let win = cv.win

  w.gui.start(0, 0)
  w.gui.start(PackHor)
  w.gui.label($win.typ & " / " & $win.size)
  w.gui.stop()
  
  w.gui.start(PackHor)
  discard w.gui.button("Win", w.showWindowOpts)
  if w.showWindowOpts:
    var winTyp = win.typ
    var winBeta = win.beta
    discard w.gui.select("Window", winTyp, true)
    if winTyp == Gaussian or winTyp == Cauchy:
      discard w.gui.slider("beta", winbeta, 0.1, 40.0, true)
    if winTyp != win.typ or winBeta != win.beta:
      win.typ = winTyp
      win.beta = winBeta
      win.update()
  w.gui.stop()

  w.gui.start(PackHor)
  discard w.gui.button("Size", w.showXformSize)
  if w.showXformSize:
    var size = win.size
    if w.gui.slider("FFT size", size, 128, 16384, true):
      size = int(pow(2, floor(log2(float(size)))))
      win.size = size
      cv.win.update()

  w.gui.stop()

  w.gui.stop()

method handleMouse*(w: WidgetFFT, x, y: int): bool =
  w.gui.mouseMove(x, y)
  if not w.gui.isActive():
    w.cursorX = x
  return true

method handleButton*(w: WidgetFFT, x, y: int, button: int, state: bool): bool =
  w.gui.mouseButton(x, y, if state: 1 else: 0)
  return true

method handleKey(w: WidgetFFT, key: Keycode, x, y: int): bool =

  if key == K_LEFTBRACKET:
    discard
  
  if key == K_RIGHTBRACKET:
    discard


# vi: ft=nim sw=2 ts=2
