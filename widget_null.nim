
import sdl2/sdl
import sdl2/sdl_ttf as ttf
import app
import widget

type
  WidgetNull* = ref object of Widget

proc newWidgetNull*(): WidgetNull =
  var w = WidgetNull()


# vi: ft=nim sw=2 ts=2
