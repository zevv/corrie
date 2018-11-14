
import sdl2/sdl
import sdl2/sdl_ttf as ttf
import app
import widget

type
  WidgetNull* = ref object of Widget

proc newWidgetNull*(): WidgetNull =
  var w = WidgetNull()

method draw(w: WidgetNull, app: App, buf: AudioBuffer) =
  return


# vi: ft=nim sw=2 ts=2
