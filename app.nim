
import sdl2/sdl
import random
import widget
import tables
import math
import textcache
import capbuf
import capview


proc c_malloc(size: csize): pointer {.importc: "malloc", header: "<stdlib.h>".}
proc c_memcpy(dst, src: pointer, len: csize) {.importc: "memcpy", header: "<stdlib.h>".}
proc c_free(p: pointer) {.importc: "free", header: "<stdlib.h>".}

type
  
  App* = ref object
    win: sdl.Window
    rend*: sdl.Renderer
    adevs: seq[sdl.AudioDeviceID]
    w, h: int
    widgets: seq[Widget]
    textCache*: TextCache
    cb*: CapBuf
    cv*: CapView

proc channelColor*(rend: Renderer, ch: int) =
  if ch == 0:
    discard rend.setRenderDrawColor(180, 0, 255, 255)
  else:
    discard rend.setRenderDrawColor(0, 255, 0, 255)

method draw*(w: Widget, rend: Renderer, app: App, cv: CapView) {.base.} =
  return


method handleKey*(w: Widget, key: Keycode, mx, my: int): bool {.base.} =
  return false


proc updateFocus*(app: App, x, y: int) =
  for w in app.widgets:
    discard w.updateFocus(x, y)


proc addWidget*(app: App, widget: Widget) =
  app.widgets.add(widget)
  return


proc draw*(app: App) =

  discard app.rend.setRenderDrawColor(30, 30, 30, 255)
  discard app.rend.renderClear

  for w in app.widgets:
    w.w = app.w
    w.h = app.h
    w.draw(app.rend, app, app.cv)
  
  app.rend.renderPresent


proc run*(app: App): bool =

  var e: sdl.Event
  var ticks = 0

  while true:

    while sdl.waitEvent(addr e) != 0:

      if e.kind == sdl.Quit:
        quit 0

      if e.kind == sdl.KeyDown:
        let key = e.key.keysym.sym
        if key == K_ESCAPE or key == K_Q:
          quit(0)
        var mx, my: cint
        discard getMouseState(addr(mx), addr(my))
        echo (repr key) & " " & $mx & " " & $my
        for w in app.widgets:
          discard w.handleKey(key, mx, my)

      if e.kind == sdl.MouseMotion:
        app.updateFocus(e.motion.x, e.motion.y)
        for w in app.widgets:
          discard w.handleMouse(e.motion.x, e.motion.y)

      if e.kind == sdl.MouseButtonDown:
        for w in app.widgets:
          discard w.handleButton(e.motion.x, e.motion.y, true)
      
      if e.kind == sdl.MouseButtonUp:
        for w in app.widgets:
          discard w.handleButton(e.motion.x, e.motion.y, false)

      if e.kind == sdl.WindowEvent:
        if e.window.event == WINDOWEVENT_RESIZED:
          app.w = e.window.data1
          app.h = e.window.data2

      if e.kind == sdl.UserEvent:
        let bytes = e.user.code
        let count = bytes /% sizeof(cfloat)
        let p = e.user.data1
        let buf = cast[ptr array[2048, cfloat]](p)[]
        app.cb.writeInterlaced(buf, count)
        cfree p

      if e.kind == EventKind(ord(sdl.UserEvent)+1):
        app.draw
        inc(ticks)
        if ticks == 100:
          for adev in app.adevs:
            pauseAudioDevice(adev, 1)



{.push stackTrace: off.}
proc on_audio(userdata: pointer, stream: ptr uint8, len: cint) {.cdecl.} =
  var e = sdl.Event()
  e.user.kind = UserEvent
  e.user.code = len
  e.user.data1 = c_malloc(len)
  e.user.data2 = userdata
  c_memcpy(e.user.data1, stream, len)
  discard pushEvent(addr e)

proc on_timer(interval: uint32, userdata: pointer): uint32 {.cdecl.} =
  var e = sdl.Event()
  e.user.kind = EventKind(ord(UserEvent)+1)
  discard pushEvent(addr e)
  return interval
{.pop.}


proc newApp*(w, h: int): App =

  let app = App()

  app.w = w
  app.h = h

  app.win = createWindow("corrie",
    WindowPosUndefined, WindowPosUndefined,
    app.w, app.h, WINDOW_RESIZABLE)

  app.rend = createRenderer(app.win, -1, sdl.RendererAccelerated and sdl.RendererPresentVsync)
  app.textCache = newTextCache(app.rend, "font.ttf")
  app.cb = newCapBuf(10 * 1024 * 1024)
  app.cv = newCapView(app.cb)

  discard addTimer(1000 /% 30, on_timer, nil)

  let n = sdl.getNumAudioDevices(1)

  for i in 1..n:
    closureScope:
      
      var want = AudioSpec(
        freq: 48000,
        format: AUDIO_F32,
        channels: 2,
        samples: 4096,
        callback: on_audio,
        userdata: cast[pointer](i)
      )
      var got = AudioSpec()
  
      let adev = openAudioDevice(nil, 1, addr want, addr got, 0)
      #pauseAudioDevice(adev, 0)
      app.adevs.add(adev)

  for i in 0..4095:
    var a: array[2048, cfloat]
    a[0] = cos(float(i) * 0.8) * 0.2
    a[1] = cos(float(i) * sqrt(float(i)) * 0.1) * 0.25
    a[0] = a[0] + rand(0.001)
    a[1] = a[1] + rand(0.001)
    app.cb.writeInterlaced(a, 2)

  return app


# vi: ft=nim sw=2 ts=2

