import sdl2/sdl
import widget
import app
import gui
import capbuf

type
  WidgetScope = ref object of Widget
    hScale: float
    vScale: float
    mx: int


proc newWidgetScope*(): WidgetScope =
  let w = WidgetScope(
    hScale: 100.0,
    vScale: 5.0
  )
  return w


method draw(w: WidgetScope, app: App, buf: AudioBuffer) =

  let cb = app.capBuf
  let yc = w.h / 2
 
  # Update mx

  let i = float(w.w - w.mx) * w.hScale
  cb.setCursor(int(i))

  # Grid

  discard setRenderDrawBlendMode(app.rend, BLENDMODE_ADD);
  discard app.rend.setRenderDrawColor(30, 30, 30, 255)
  discard app.rend.renderDrawLine(0, int(yc), w.w, int(yc))

  # Scope

  let vScale = w.vScale * float(w.h) * 0.5

  for j in 0..1:
    var p: array[BLOCKSIZE_MAX, sdl.Point]
    for x in 0 .. w.w-1:
      let i = float(w.w-x) * w.hScale
      let v = cb.read(0, int(i))
      let y = v * vScale + yc
      p[x].x = x
      p[x].y = cint(y)

    app.rend.channelColor(j)

    discard app.rend.renderDrawLines(addr(p[0]), w.w)
  
  discard setRenderDrawBlendMode(app.rend, BLENDMODE_BLEND)

  # Cursor

  if true:
    discard setRenderDrawBlendMode(app.rend, BLENDMODE_ADD);
    discard app.rend.setRenderDrawColor(255, 255, 255, 60)
    let x = w.w - int(float(cb.getCursor()) / w.hScale)
    discard app.rend.renderDrawLine(x, 0, x, w.h)
    discard setRenderDrawBlendMode(app.rend, BLENDMODE_BLEND);


method handleMouse*(w: WidgetScope, x, y: int): bool =
  w.mx = x


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
