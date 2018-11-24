
import sdl2/sdl
import sdl2/sdl_ttf as ttf
import app
import times
import gui
import math
import capview
import capbuf
import widget
import fftw3
import tables

type
  WidgetWaterfall* = ref object of Widget
    gui: Gui
    fftIn: seq[cdouble]
    fftOut: seq[fftw_complex]
    plan: fftw_plan
    size: int
    tex: Texture
    texw, texh: int
    overlap: int
    db_range: float
    cache: Table[float, seq[cfloat]]
    apertureMid, apertureRange: float

proc setSize(w: WidgetWaterfall, size: int) =

  if size != w.size:
    w.size = size
    if w.plan != nil:
      fftw_destroy_plan(w.plan)

    w.fftIn.setLen(size)
    w.fftOut.setLen(size)
    w.plan = fftw_plan_dft_r2c_1d(size, addr(w.fftIn[low(w.fftIn)]),
               addr(w.fftOut[low(w.fftOut)]), FFTW_ESTIMATE)


proc newWidgetWaterfall*(app: App): WidgetWaterfall =
  var w = WidgetWaterfall(
    apertureMid: -60,
    apertureRange: 120,
    gui: newGui(app.rend, app.textcache)
  )
  w.setSize(1024)
  w.overlap = 16
  w.db_range = 120
  w.cache = inittable[float, seq[cfloat]]()
  return w


proc abs(v: fftw_complex): cdouble =
  return sqrt(v[0] * v[0] + v[1] * v[1])


method draw(w: WidgetWaterfall, rend: Renderer, app: App, cv: CapView) =
  let cb = cv.cb
  
  let size = cv.win.size
  
  let n = size /% 2 - 1
  w.setSize(size)
  let scale = 1.0 / float(n)

  if w.texw != n or w.texh != w.h:
    if w.tex != nil:
      destroyTexture(w.tex)
    discard setHint(HINT_RENDER_SCALE_QUALITY, "1")
    w.texw = n
    w.texh = w.h
    w.tex = createTexture(rend, PIXELFORMAT_ARGB32, TEXTUREACCESS_STREAMING, w.texw, w.texh)
    assert(w.tex != nil)
  
  var rect = Rect(x:0, y:0, w:w.texw, h:w.texh)
  var texData: pointer
  var texPitch: cint
  let rv = lockTexture(w.tex, addr rect, addr texData, addr texPitch)
  zeroMem(texData, texPitch * w.texh)

  proc pixPtr(x, y: int): ptr uint32 =
    let texDataAddr = cast[ByteAddress](texData)
    return cast[ptr uint32](texDataAddr + texPitch * y + sizeof(uint32) * x)
      
  let winData = cv.win.getData()

  for y in 0..w.h-1:
    var i0 = cv.getCursor() + y * w.overlap
    i0 = i0 /% w.overlap * w.overlap

    for j in 0..1:

      var key: cfloat = 0.0
      for i in 0..size-1:
        var v = cb.read(j, i+i0)
        w.fftIn[i] = v * scale * winData[i]
        key = key + w.fftIn[i] * 1000
      key = key * float(size)

      var fft: seq[cfloat]

      if w.cache.hasKey(key):
        fft = w.cache[key]
      else:
        fft = newSeq[cfloat](n)
        fftw_execute(w.plan)

        for x in 0..n-1:
          var v = abs(w.fftOut[x])
          let vdb = w.db_range - (if v>0 : -20 * log10(v) else: w.db_range)
          fft[x] = vdb
        w.cache[key] = fft

      for x in 0..n-1:
        var c = pixptr(x, w.h-y-1)
        var v = fft[x]

        v = (v + w.apertureMid) / w.apertureRange

        v = v * 128 + 128

        var pp = clamp(int(v), 0, 255)
        if j == 0:
          c[] = c[] + uint32(int(pp) * 0x01000100)
        else:
          c[] = c[] + uint32(int(pp) * 0x00010000)

  unlockTexture(w.tex)
  var rect2 = Rect(x:30, y:0, w:w.w-30, h:w.h)
  discard rend.renderCopy(w.tex, nil, addr rect2)

  w.gui.start(0, 0, PackHor)
  discard w.gui.slider("mid", w.apertureMid, -120, 0, true)
  discard w.gui.slider("rng", w.apertureRange, 1, 120, true)
  w.gui.stop()


method handleKey(w: WidgetWaterfall, key: Keycode, x, y: int): bool =

  if key == K_LEFTBRACKET:
    w.overlap = int(float(w.overlap) * 1.1) + 1
  
  if key == K_RIGHTBRACKET:
    w.overlap = int(float(w.overlap) / 1.1) - 1
    discard

  w.overlap = clamp(w.overlap, 1, 16384)



method handleMouse*(w: WidgetWaterfall, x, y: int): bool =
  w.gui.mouseMove(x, y)
  return true

method handleButton*(w: WidgetWaterfall, x, y: int, button: int, state: bool): bool =
  w.gui.mouseButton(x, y, if state: 1 else: 0)
  return true


# vi: ft=nim sw=2 ts=2
