
import sdl2/sdl
import capview

type
  
  AudioBuffer = ref object

  App = ref object

  Widget* = ref object of RootObj
    w*, h*: int
    rend: Renderer
    hasFocus*: bool

method label*(w: Widget): string {.base.} = 
  return ""

method draw*(w: Widget, rend: Renderer, app: App, cv: CapView) {.base.} =
  return

method draw*(w: Widget, app: App, cv: CapView) {.base.} =
  echo "olddraw"
  return

method updateFocus*(w: Widget, x, y: int): bool {.base.} =
  return

method handleMouse*(w: Widget, x, y: int): bool {.base.} =
  return

method handleButton*(w: Widget, x, y: int, button: int, state: bool): bool {.base.} =
  return

method handleWheel*(w: Widget, x, y: int): bool {.base.} =
  return

# vi: ft=nim sw=2 ts=2
