import sdl2/sdl
import widget
import math
import app
import gui
import capbuf
import capview

type
  WidgetScope = ref object of Widget
    hScale: float
    vScale: float
    mx: int
    gui: Gui
    showWindowOpts: bool
    showXformSize: bool
    winType: WindowType
    tex: Texture
    texw, texh: int
    algo: int
    amax: array[4, float]


proc newWidgetScope*(app: App): WidgetScope =
  let w = WidgetScope(
    hScale: 20.0,
    vScale: 1.0,
    algo: 2
  )
  w.gui = newGui(app.rend, app.textcache)
  return w


var accum: array[4096, array[4096, uint16]]

method draw(w: WidgetScope, rend: Renderer, app: App, cv: CapView) =

  let yc = w.h / 2
  let cb = cv.cb
 
  # Update mx

  let i = float(w.w - w.mx) * w.hScale
  cv.setCursor(int(i))

  # Grid

  discard setRenderDrawBlendMode(rend, BLENDMODE_ADD);
  discard rend.setRenderDrawColor(30, 30, 30, 255)
  discard rend.renderDrawLine(0, int(yc), w.w, int(yc))
  
  # Scope

  let vScale = w.vScale * float(w.h) * 0.5
    
  if w.texw != w.w or w.texh != w.h:
    if w.tex != nil:
      destroyTexture(w.tex)
    w.tex = createTexture(rend, PIXELFORMAT_ARGB32, TEXTUREACCESS_STREAMING, w.w, w.h)
    assert(w.tex != nil)
  
  var rect = Rect(x:0, y:0, w:w.w, h:w.h)
  var data: pointer
  var pitch: cint
  let rv = lockTexture(w.tex, addr rect, addr data, addr pitch)
  var usetex = false

  case w.algo

  of 0:

    for j in 0..1:
      var pmin = newSeq[Point](w.w)
      var pmax = newSeq[Point](w.w)
      for x in 0 .. w.w-1:
        let i1 = int(float(w.w-x+0) * w.hScale)
        let i2 = int(float(w.w-x+1) * w.hScale)
        var ymin = 1000
        var ymax = -1000
        for i in i1..i2:
          let v = cb.read(j, i)
          let y = int(v * vScale + yc)
          ymin = min(y, ymin)
          ymax = max(y, ymax)
        pmin[x].x = x
        pmin[x].y = cint(ymin)
        pmax[x].x = x
        pmax[x].y = cint(ymax)

      rend.channelColor(j)
      discard rend.renderDrawLines(addr(pmin[0]), w.w)
      discard rend.renderDrawLines(addr(pmax[0]), w.w)

  of 1:

    usetex = true
    zeromem(addr accum, sizeof(accum))
    var amax: int = 0
    let n = int(float(w.w) * w.hScale)
    for j in 0..1:
      var p = newSeq[Point](n)
      for i in 0 .. n-1:
        let x = int(float(i) / w.hScale)
        let v = cb.read(j, i)
        let y = int(v * vScale + yc)
        inc(accum[x][y])
        let a = accum[x][y] 
        amax = max(int(a), amax)

      let scale = 128 /% amax
      let a = cast[ByteAddress](data)

      for y in 0..w.h-1:
        var b = a + pitch * y
        for x in 0..w.w-1:
          var c = cast[ptr uint32](b)
          var v = c[]
          if j == 0:
            v += uint32(int(accum[x][y]) * scale) * uint32(0x01000100)
          else:
            v += uint32(int(accum[x][y]) * scale) * uint32(0x00010000)
          v = v or uint32(0x000000ff)
          c[] = v
          b = b + 4

  of 2:

    w.hScale = max(w.hScale, 1.0)

    usetex = true
    for j in 0..1:
      var amax = w.amax[j]
      if amax == 0: amax = 1.0
      var amax_next = 0.0
      for x in 0 .. w.w-1:
        let i1 = int(float(w.w-x+0) * w.hScale)
        let i2 = int(float(w.w-x+1) * w.hScale)
        var accum: array[1024, float]
        for i in i1..i2-1:
          let v1 = cb.read(j, i)
          let v2 = cb.read(j, i+1)
          var y1 = int(v1 * vScale + yc)
          var y2 = int(v2 * vScale + yc)
          if y1 > y2: swap(y1, y2)
          let dy = abs(y2-y1) + 1
          let intensity = 1.0 / float(dy)
          y1 = clamp(y1, 0, w.h-1)
          y2 = clamp(y2, 0, w.h-1)
          for y in y1..y2:
            accum[y] += intensity
        for y in 0..w.h-1:
          accum[y] = pow(accum[y], 0.4)
        for a in accum:
          amax_next = max(a, amax_next)
        let a = cast[ByteAddress](data)
        var b = a + x * 4
        for y in 0..w.h-1:
          var c = cast[ptr uint32](b)
          var pp = int(255.0 * accum[y] / amax)
          c[] = c[] or 0x000000ff
          if j == 0:
            c[] = c[] + uint32(int(pp) * 0x01000100)
          else:
            c[] = c[] + uint32(int(pp) * 0x00010000)
          b = b + pitch
      w.amax[j] = amax_next

  else:
    discard
  
  if usetex:
    unlockTexture(w.tex)
    discard rend.renderCopy(w.tex, nil, addr rect)
  
  discard setRenderDrawBlendMode(rend, BLENDMODE_BLEND)

  # Cursor

  if true:
    discard setRenderDrawBlendMode(rend, BLENDMODE_ADD);
    discard rend.setRenderDrawColor(255, 255, 255, 60)
    let x = w.w - int(float(cv.getCursor()) / w.hScale)
    discard rend.renderDrawLine(x, 0, x, w.h)
    discard setRenderDrawBlendMode(rend, BLENDMODE_BLEND);
  
  # Window

  if true:
    let d = cv.win.getData()
    let l = d.len()
    var p = newSeq[Point](l)
    for i in 0..l-1:
      let v = d[i]
      let y = v * float(w.h)
      p[i].x = w.w - cint(float(cv.getCursor() - i + l/%2) / w.hScale)
      p[i].y = w.h - cint(y)

    discard setRenderDrawBlendMode(rend, BLENDMODE_ADD);
    discard rend.setRenderDrawColor(0, 0, 255, 255)
    discard rend.renderDrawLines(addr(p[0]), l)
    discard setRenderDrawBlendMode(rend, BLENDMODE_BLEND);


  # Gui

  let win = cv.win

  w.gui.start(0, 0)
  w.gui.label($win.typ & " / " & $win.size)
  
  w.gui.start(PackHor)
  discard w.gui.button("Window", w.showWindowOpts)
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


  # Gui



  w.gui.stop()

method handleMouse*(w: WidgetScope, x, y: int): bool =
  w.mx = x
  w.gui.mouseMove(x, y)
  return true


method handleButton*(w: WidgetScope, x, y: int, state: bool): bool =
  w.gui.mouseButton(x, y, if state: 1 else: 0)
  return true


method handleWheel*(w: WidgetScope, x, y: int): bool =
  if y == 1:
    w.hScale *= 1.1
  if y == -1:
    w.hScale /= 1.1
  if x == 1:
    w.vScale *= 2.0;
  if x == -1:
    w.vScale /= 2.0;

method handleKey(w: WidgetScope, key: Keycode, x, y: int): bool =
  
  if key == K_a:
    w.algo = (w.algo + 1) mod 3

  if key == K_UP:
    w.vScale = w.vScale * 1.2;
  
  if key == K_DOWN:
    w.vScale = w.vScale / 1.2;
  
  if key == K_LEFTBRACKET:
    w.hScale = w.hScale * 1.2;
  
  if key == K_RIGHTBRACKET:
    w.hScale = w.hScale / 1.2;

# vi: ft=nim sw=2 ts=2
