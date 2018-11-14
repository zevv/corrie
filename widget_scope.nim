import sdl2/sdl
import widget
import app
import gui

type
  WidgetScope = ref object of Widget
    speed: int


proc newWidgetScope*(): WidgetScope =
  let w = WidgetScope()
  w.speed = 50
  return w


method draw(w: WidgetScope, app: App, buf: AudioBuffer) =

  discard setRenderDrawBlendMode(app.rend, BLENDMODE_ADD);

  let scale = w.h / 2
  for j in 0..1:
    var p: array[BLOCKSIZE_MAX, sdl.Point]
    for i in 0..BLOCKSIZE_MAX-1:
      let v = buf.data[i][j]
      let y = v*scale + scale
      p[i].x = cint(w.w * i / BLOCKSIZE_MAX)
      p[i].y = cint(y)

    app.rend.channelColor(j)

    discard app.rend.renderDrawLines(addr(p[0]), BLOCKSIZE_MAX)
  
  discard setRenderDrawBlendMode(app.rend, BLENDMODE_BLEND)

# vi: ft=nim sw=2 ts=2
