
import sdl2/sdl
import widget
import tables
import textcache

const BLOCKSIZE_MAX* = 1024

proc c_malloc(size: csize): pointer {.importc: "malloc", header: "<stdlib.h>".}
proc c_memcpy(dst, src: pointer, len: csize) {.importc: "memcpy", header: "<stdlib.h>".}
proc c_free(p: pointer) {.importc: "free", header: "<stdlib.h>".}

type
  
  AudioBuffer* = object
    size*: int
    data*: array[BLOCKSIZE_MAX, array[2, cfloat]]

  App* = ref object
    win: sdl.Window
    rend*: sdl.Renderer
    adevs: seq[sdl.AudioDeviceID]
    w, h: int
    widgets: seq[Widget]
    textCache*: TextCache

proc channelColor*(rend: Renderer, ch: int) =
  if ch == 0:
    discard rend.setRenderDrawColor(180, 0, 255, 255)
  else:
    discard rend.setRenderDrawColor(0, 255, 0, 255)

method draw*(w: Widget, app: App, buf: AudioBuffer) {.base.} =
  return

method handleKey*(w: Widget, key: Keycode, mx, my: int): bool {.base.} =
  return false


proc updateFocus*(app: App, x, y: int) =
  for w in app.widgets:
    discard w.updateFocus(x, y)


proc addWidget*(app: App, widget: Widget) =
  app.widgets.add(widget)
  return


proc handle_audio*(app: App, buf: AudioBuffer) =

  for w in app.widgets:
    w.w = app.w
    w.h = app.h
    w.draw(app, buf)

  app.rend.renderPresent
  discard setRenderDrawBlendMode(app.rend, BLENDMODE_BLEND);


proc run*(app: App): bool =

  var e: sdl.Event

  while true:

    discard app.rend.setRenderDrawColor(30, 30, 30, 255)
    discard app.rend.renderClear

    if sdl.waitEvent(addr e) != 0:

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
        let len = e.user.code
        let p = e.user.data1
        let i = cast[int](e.user.data2)
        let buf = cast[ptr AudioBuffer](p)[]
        app.handle_audio buf
        cfree p


{.push stackTrace: off.}
proc on_audio(userdata: pointer, stream: ptr uint8, len: cint) {.cdecl.} =
  var e = sdl.Event()
  e.user.kind = USEREVENT
  e.user.code = len
  e.user.data1 = c_malloc(len)
  e.user.data2 = userdata
  c_memcpy(e.user.data1, stream, len)
  discard pushEvent(addr e)
{.pop.}


proc newApp*(w, h: int): App =

  let app = App()

  app.w = w
  app.h = h

  app.win = createWindow("corrie",
    WindowPosUndefined, WindowPosUndefined,
    app.w, app.h, WINDOW_RESIZABLE)

  app.rend = createRenderer(app.win, -1, sdl.RendererAccelerated)
  app.textCache = newTextCache(app.rend, "font.ttf")

  let n = sdl.getNumAudioDevices(1)
  for i in 1..n:
    closureScope:

      var want = AudioSpec(
        freq: 48000,
        format: AUDIO_F32,
        channels: 2,
        samples: BLOCKSIZE_MAX,
        callback: on_audio,
        userdata: cast[pointer](i)
      )
      var got = AudioSpec()
  
      let adev = openAudioDevice(nil, 1, addr want, addr got, 0)
      pauseAudioDevice(adev, 0)
      app.adevs.add(adev)


  return app


# vi: ft=nim sw=2 ts=2

