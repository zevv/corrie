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
    vScale: float
    posFrom: int
    posTo: int
    mx: int
    gui: Gui
    winType: WindowType
    tex: Texture
    texw, texh: int
    algo: int
    intNorm: float
    intensity: float
    peakHilite: bool
    dragging: int
    dragX, dragY: int



proc newWidgetScope*(app: App): WidgetScope =
  let w = WidgetScope(
    vScale: 1.0,
    algo: 2,
    intensity: 50,
    peakHilite: false,
    posFrom: 0,
    posTo: 100000,
  )
  w.gui = newGui(app.rend, app.textcache)
  return w

  
proc zoom(w: WidgetScope, f: float) =
  var a = w.mx / w.w
  let n = float(w.posTo - w.posFrom) * f
  w.posFrom += int(n * (1.0-a))
  w.posTo -= int(n * a)


proc pan(w: WidgetScope, f: float) = 
  let dx = int(float(w.posTo - w.posFrom) * f)
  w.posFrom += dx
  w.posTo += dx


var accum: array[4096, array[4096, uint16]]

method draw(w: WidgetScope, rend: Renderer, app: App, cv: CapView) =

  if w.dragging == 1:
    var dx = w.mx - w.dragX
    w.pan(dx / 10000)
  
  if w.dragging == 3:
    var dx = w.mx - w.dragX
    w.zoom(dx / 1000)

  when defined(profiling):
    enableProfiling()

  let yc = w.h / 2
  let cb = cv.cb
 
  # Update cursor
    
  let ic = w.posFrom + (w.posTo - w.posFrom) * (w.w - w.mx) /% w.w
  cv.setCursor(ic)

  
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

  case w.algo

  of 1:
    
    var accum: seq[float]
    accum.setLen(w.h)
    var amax = 0.0
    var acnt = 0

    usetex = true
    for j in 0..1:
      var ymin = w.h
      var ymax = 0
      var y1 = 0
      var y2 = 0
      var px = 0

      for i in w.posFrom .. w.posTo:
        y1 = y2
        y2 = int(cb.read(j, i) * vScale + yc)
        
        let x = w.w - w.w * (i - w.posFrom) /% (w.posTo - w.posFrom)
        if x != px:
          if w.peakHilite:
            accum[ymin] += 1.0
            accum[ymax] += 1.0
          for y in ymin..ymax:
            accum[y] = sqrt(accum[y])
            amax += accum[y]
            acnt += 1
            var c = pixptr(x, y)
            var pp = min(int(accum[y] * w.intNorm), 255)
            if j == 0:
              c[] = c[] + uint32(int(pp) * 0x01000100)
            else:
              c[] = c[] + uint32(int(pp) * 0x00010000)
          px = x

          zeroMem(accum[0].addr, len(accum) * sizeof(accum[0]))
          ymin = w.h
          ymax = 0

        var y3 = min(y1, y2)
        var y4 = max(y1, y2)
        let dy = y4 - y3 + 1
        let v = 1.0 / float(dy)
        y3 = clamp(y3, 0, w.h-1)
        y4 = clamp(y4, 0, w.h-1)
        ymin = min(ymin, y3)
        ymax = max(ymax, y4)
        y4 = max(y3+1, y4)
        
        for y in y3..y4-1:
          accum[y] += v

    amax = amax / float(acnt)
    w.intNorm = if amax>0: (w.intensity / 50.0 * 128.0)/amax else: 0

  of 2:
    
    var accum: seq[float]
    accum.setLen(w.h)
    var amax = 0.0
    var acnt = 0

    usetex = true
    for j in 0..1:
      var ymin = w.h
      var ymax = 0
      var y1 = 0
      var y2 = 0
      var px = 0

      for i in w.posFrom .. w.posTo:
        y1 = y2
        y2 = int(cb.read(j, i) * vScale + yc)
        
        let x = w.w - w.w * (i - w.posFrom) /% (w.posTo - w.posFrom)
        if x != px:
          if w.peakHilite:
            accum[ymin] += 1.0
            accum[ymax] += 1.0
          for y in ymin..ymax:
            accum[y] = sqrt(accum[y])
            amax += accum[y]
            acnt += 1
            var c = pixptr(x, y)
            var pp = min(int(accum[y] * w.intNorm), 255)
            if j == 0:
              c[] = c[] + uint32(int(pp) * 0x01000100)
            else:
              c[] = c[] + uint32(int(pp) * 0x00010000)
          px = x

          zeroMem(accum[0].addr, len(accum) * sizeof(accum[0]))
          ymin = w.h
          ymax = 0

        var y3 = min(y1, y2)
        var y4 = max(y1, y2)
        let dy = y4 - y3 + 1
        let v = 1.0 / float(dy)
        y3 = clamp(y3, 0, w.h-1)
        y4 = clamp(y4, 0, w.h-1)
        ymin = min(ymin, y3)
        ymax = max(ymax, y4)
        y4 = max(y3+1, y4)
        
        for y in y3..y4-1:
          accum[y] += v

    amax = amax / float(acnt)
    w.intNorm = if amax>0: (w.intensity / 50.0 * 128.0)/amax else: 0

  else:
    discard
  
  if usetex:
    unlockTexture(w.tex)
    discard rend.renderCopy(w.tex, nil, addr rect)
  
  discard setRenderDrawBlendMode(rend, BLENDMODE_BLEND)
  
  # Grid

  discard setRenderDrawBlendMode(rend, BLENDMODE_ADD);
  discard rend.setRenderDrawColor(30, 30, 30, 255)
  discard rend.renderDrawLine(0, int(yc), w.w, int(yc))

  # Cursor

  when true:
    discard setRenderDrawBlendMode(rend, BLENDMODE_ADD);
    discard rend.setRenderDrawColor(255, 255, 255, 60)
    let i = cv.getCursor()
    let x = w.w - w.w * (i - w.posFrom) /% (w.posTo - w.posFrom)
    discard rend.renderDrawLine(x, 0, x, w.h)
    discard setRenderDrawBlendMode(rend, BLENDMODE_BLEND);
  
  # Window

  when true:
    let icursor = cv.getCursor()
    let d = cv.win.getData()
    let l = d.len()
    var p = newSeq[Point](l)
    for i in 0..l-1:
      let v = d[i]
      let y = v * float(w.h)
      p[i].x = w.w - w.w * (icursor + i - w.posFrom) /% (w.posTo - w.posFrom)
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
  discard w.gui.slider("int", w.intensity, 1, 100.0)
  discard w.gui.button("peak", w.peakHilite)
  w.gui.stop()
  w.gui.stop()

  when defined(profiling):
    disableProfiling()


method handleMouse*(w: WidgetScope, x, y: int): bool =
  w.gui.mouseMove(x, y)
  if not w.gui.isActive:
    w.mx = x
  return true


method handleButton*(w: WidgetScope, x, y: int, button: int, state: bool): bool =
  w.gui.mouseButton(x, y, if state: 1 else: 0)

  if state:
    w.dragging = button
    w.dragX = x
    w.dragY = y
  else:
    w.dragging = 0
  return true


method handleWheel*(w: WidgetScope, x, y: int): bool =
  
  let shift = (ord(getModState()) and ord(KMOD_LSHIFT)) == ord(KMOD_LSHIFT)


  if y == 1:
    if shift:
      w.vScale /= 1.2
    else:
      discard
  if y == -1:
    if shift:
      w.vScale *= 1.2
    else:
      discard
  if x == 1:
    if shift:
      w.zoom(-1/10.0)
    else:
      w.pan(-1/20.0)
  if x == -1:
    if shift:
      w.zoom(1/10.0)
      discard
    else:
      w.pan(1/20.0)

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
  

# vi: ft=nim sw=2 ts=2
