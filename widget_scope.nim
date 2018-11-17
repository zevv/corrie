import sdl2/sdl
import widget
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
    winType: WindowType


proc newWidgetScope*(app: App): WidgetScope =
  let w = WidgetScope(
    hScale: 2.0,
    vScale: 1.0
  )
  w.gui = newGui(app.rend, app.textcache)
  return w


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
  
  # Window

  if true:
    let d = cv.win.getData()
    let l = d.len()
    var p: array[BLOCKSIZE_MAX, sdl.Point]
    for i in 0..l-1:
      let v = d[i]
      let y = v * float(w.h)
      p[i].x = w.w - cint(float(w.w) * float(i) / float(l) / w.hScale)
      p[i].y = w.h - cint(y)

    discard rend.setRenderDrawColor(0, 0, 255, 255)
    discard rend.renderDrawLines(addr(p[0]), BLOCKSIZE_MAX)

  # Scope

  let vScale = w.vScale * float(w.h) * 0.5

  for j in 0..1:
    var p: array[BLOCKSIZE_MAX, sdl.Point]
    for x in 0 .. w.w-1:
      let i = float(w.w-x) * w.hScale
      let v = cb.read(j, int(i))
      let y = v * vScale + yc
      p[x].x = x
      p[x].y = cint(y)

    rend.channelColor(j)
    discard rend.renderDrawLines(addr(p[0]), w.w)
  
  discard setRenderDrawBlendMode(rend, BLENDMODE_BLEND)

  # Cursor

  if true:
    discard setRenderDrawBlendMode(rend, BLENDMODE_ADD);
    discard rend.setRenderDrawColor(255, 255, 255, 60)
    let x = w.w - int(float(cv.getCursor()) / w.hScale)
    discard rend.renderDrawLine(x, 0, x, w.h)
    discard setRenderDrawBlendMode(rend, BLENDMODE_BLEND);

  # Gui

  w.gui.start(100, 0)
  w.gui.start(PackHor)
  discard w.gui.button("Window", w.showWindowOpts)
  w.gui.stop()

  if w.showWindowOpts:
    var winTyp = cv.win.typ
    var winBeta = cv.win.beta
    w.gui.start(PackVer)
    discard w.gui.select("Window", winTyp, true)
    if winTyp == Gaussian or winTyp == Cauchy:
      discard w.gui.slider("beta", winbeta, 0.1, 40.0, true)
    w.gui.stop()
    if winTyp != cv.win.typ or winBeta != cv.win.beta:
      cv.win.typ = winTyp
      cv.win.beta = winBeta
      cv.win.update()
  w.gui.stop()


method handleMouse*(w: WidgetScope, x, y: int): bool =
  w.mx = x
  w.gui.mouseMove(x, y)
  return true


method handleButton*(w: WidgetScope, x, y: int, state: bool): bool =
  w.gui.mouseButton(x, y, if state: 1 else: 0)
  return true


method handleKey(w: WidgetScope, key: Keycode, x, y: int): bool =

  if key == K_UP:
    w.vScale = w.vScale * 1.2;
  
  if key == K_DOWN:
    w.vScale = w.vScale / 1.2;
  
  if key == K_LEFTBRACKET:
    w.hScale = w.hScale * 1.2;
  
  if key == K_RIGHTBRACKET:
    w.hScale = w.hScale / 1.2;

# vi: ft=nim sw=2 ts=2
