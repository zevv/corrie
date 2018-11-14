
import sdl2/sdl

type
  
  AudioBuffer = ref object

  App = ref object

  Widget* = ref object of RootObj
    w*, h*: int
    hasFocus*: bool

method label*(w: Widget): string {.base.} = 
  return ""

method draw*(w: Widget, app: App, buf: AudioBuffer) {.base.} =
  return

method updateFocus*(w: Widget, x, y: int): bool {.base.} =
  return

method handleMouse*(w: Widget, x, y: int): bool {.base.} =
  return

method handleButton*(w: Widget, x, y: int, state: bool): bool {.base.} =
  return

# vi: ft=nim sw=2 ts=2
