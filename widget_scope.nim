import sdl2/sdl
import widget
import times
import math
import app
import gui
import capbuf
import capview

when defined(profiling):
  import nimprof

type
  WidgetScope = ref object of Widget
    hScale: float
    vScale: float
    pos: int
    mx: int
    gui: Gui
    showWindowOpts: bool
    showXformSize: bool
    winType: WindowType
    tex: Texture
    texw, texh: int
    algo: int
    intNorm: array[4, float]
    amax: array[4, float]
    intensity: float


proc newWidgetScope*(app: App): WidgetScope =
  let w = WidgetScope(
    hScale: 250.0,
    vScale: 1.0,
    algo: 2,
    intensity: 1.0
  )
  w.gui = newGui(app.rend, app.textcache)
  return w


var accum: array[4096, array[4096, uint16]]

method draw(w: WidgetScope, rend: Renderer, app: App, cv: CapView) =


  when defined(profiling):
    enableProfiling()

  let yc = w.h / 2
  let cb = cv.cb
 
  # Update mx

  let i = float(w.w - w.mx) * w.hScale
  cv.setCursor(int(i) + w.pos)

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
  var texData: pointer
  var texPitch: cint
  let rv = lockTexture(w.tex, addr rect, addr texData, addr texPitch)

  proc pixPtr(x, y: int): ptr uint32 =
    let texDataAddr = cast[ByteAddress](texData)
    return cast[ptr uint32](texDataAddr + texPitch * y + sizeof(uint32) * x)


  var usetex = false

  let t1 = epochTime()

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
        let x = w.w - int(float(i) / w.hScale)
        let v = cb.read(j, i)
        let y = int(v * vScale + yc)
        inc(accum[x][y])
        let a = accum[x][y] 
        amax = max(int(a), amax)

      let scale = 255 /% amax

      for y in 0..w.h-1:
        for x in 0..w.w-1:
          var c = pixPtr(x, y)
          var v = c[]
          if j == 0:
            v += uint32(int(accum[x][y]) * scale) * uint32(0x01000000)
          else:
            v += uint32(int(accum[x][y]) * scale) * uint32(0x00010000)
          c[] = v

  of 2:
    
    w.hScale = max(w.hScale, 1.0)
    let n = int(float(w.w) * w.hScale)
      
    var accum: seq[float]
    accum.setLen(w.h)

    usetex = true
    for j in 0..1:
      var amax = 0.0
      var ymin = w.h
      var ymax = 0
      var y1 = 0
      var y2 = 0
      var px = 0

      for i in 0..n-1:
        y1 = y2
        y2 = int(cb.read(j, i+w.pos) * vScale + yc)
        
        let x = w.w - int(float(i) / w.hScale)
        if x != px:
          px = x
          for y in ymin..ymax:
            accum[y] = sqrt(accum[y])
            amax = max(amax, accum[y])
            var c = pixptr(x, y)
            var pp = min(int(accum[y] * w.intNorm[j] * w.intensity), 255)
            if j == 0:
              c[] = c[] + uint32(int(pp) * 0x01000100)
            else:
              c[] = c[] + uint32(int(pp) * 0x00010000)

          zeroMem(accum[0].addr, len(accum) * sizeof(accum[0]))
          ymin = w.h
          ymax = 0

        var y3 = min(y1, y2)
        var y4 = max(y1, y2)
        let dy = y4 - y3 + 1
        let intensity = 1.0 / float(dy)
        y3 = clamp(y3, 0, w.h-1)
        y4 = clamp(y4, 0, w.h-1)
        ymin = min(ymin, y3)
        ymax = max(ymax, y4)
        y4 = max(y3+1, y4)
        
        for y in y3..y4-1:
          accum[y] += intensity

      w.intNorm[j] = if amax>0: 255.0/amax else: 0

    
  of 3:

    w.hScale = max(w.hScale, 1.0)
    let n = int(float(w.w) * w.hScale)
      
    var accum: seq[float]
    accum.setLen(w.h)

    usetex = true
    for j in 0..1:
      var amax = 0.0
      var ymin = w.h
      var ymax = 0
      var y1 = 0
      var y2 = 0
      var px = 0

      for i in 0..n-1:
        y1 = y2
        y2 = int(cb.read(j, i) * vScale + yc)
        
        let x = w.w - int(float(i) / w.hScale)
        if x != px:
          px = x
          for y in ymin..ymax:
            accum[y] = sqrt(accum[y])
            amax = max(amax, accum[y])
            var c = pixptr(x, y)
            var pp = min(int(accum[y] * w.intNorm[j] * w.intensity), 255)
            if j == 0:
              c[] = c[] + uint32(int(pp) * 0x01000100)
            else:
              c[] = c[] + uint32(int(pp) * 0x00010000)

          zeroMem(accum[0].addr, len(accum) * sizeof(accum[0]))
          ymin = w.h
          ymax = 0

        var y3 = min(y1, y2)
        var y4 = max(y1, y2)
        let dy = y4 - y3 + 1
        let intensity = 1.0 / float(dy)
        y3 = clamp(y3, 0, w.h-1)
        y4 = clamp(y4, 0, w.h-1)
        ymin = min(ymin, y3)
        ymax = max(ymax, y4)
        y4 = max(y3+1, y4)
        
        for y in y3..y4-1:
          accum[y] += intensity

      w.intNorm[j] = if amax>0: 255.0/amax else: 0


  else:
    discard
  
  
  let t2 = epochTime()
  #echo "                 ", 1000.0 * (t2-t1)
  
  if usetex:
    unlockTexture(w.tex)
    discard rend.renderCopy(w.tex, nil, addr rect)
  
  discard setRenderDrawBlendMode(rend, BLENDMODE_BLEND)

  # Cursor

  if true:
    discard setRenderDrawBlendMode(rend, BLENDMODE_ADD);
    discard rend.setRenderDrawColor(255, 255, 255, 60)
    let x = w.w - int(float(cv.getCursor() - w.pos) / w.hScale)
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
      p[i].x = w.w - cint(float(cv.getCursor() - i + l/%2 - w.pos) / w.hScale)
      p[i].y = w.h - cint(y)

    discard setRenderDrawBlendMode(rend, BLENDMODE_ADD);
    discard rend.setRenderDrawColor(0, 0, 255, 255)
    discard rend.renderDrawLines(addr(p[0]), l)
    discard setRenderDrawBlendMode(rend, BLENDMODE_BLEND);


  # Gui

  let win = cv.win

  w.gui.start(0, 0)
  w.gui.start(PackHor)
  w.gui.label($win.typ & " / " & $win.size)
  discard w.gui.slider("hscale", w.hScale, 1.0, 100.0, true)
  discard w.gui.slider("vscale", w.vScale, 0.1, 100.0, true)
  discard w.gui.slider("int", w.intensity, 1.0, 10.0, true)
  w.gui.stop()
  
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

  w.gui.stop()

  when defined(profiling):
    disableProfiling()


method handleMouse*(w: WidgetScope, x, y: int): bool =
  w.mx = x
  w.gui.mouseMove(x, y)
  return true


method handleButton*(w: WidgetScope, x, y: int, state: bool): bool =
  w.gui.mouseButton(x, y, if state: 1 else: 0)
  return true


method handleWheel*(w: WidgetScope, x, y: int): bool =
  
  let shift = (ord(getModState()) and ord(KMOD_LSHIFT)) == ord(KMOD_LSHIFT)

  if y == 1:
    if shift:
      w.hScale *= 1.1
    else:
      w.pos += int(float(w.w) * w.hScale * 0.1)
  if y == -1:
    if shift:
      w.hScale /= 1.1
    else:
      w.pos -= int(float(w.w) * w.hScale * 0.1)
  if x == 1:
    w.vScale *= 2.0;
  if x == -1:
    w.vScale /= 2.0;

method handleKey(w: WidgetScope, key: Keycode, x, y: int): bool =
  
  
  if key == K_0: w.algo = 0
  if key == K_1: w.algo = 1
  if key == K_2: w.algo = 2
  if key == K_3: w.algo = 3

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
