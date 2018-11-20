
import sdl2/sdl
import random
import times
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

  var tnext = epochTime()

  while true:

    app.draw
    inc(ticks)
    if ticks == 100:
      for adev in app.adevs:
        pauseAudioDevice(adev, 1)

    var tnow = epochTime()
    var dt = tnext - tnow
    if dt > 0:
      delay(uint32(dt * 1024))
    t_next = t_next + 1/30.0

    while sdl.pollEvent(addr e) != 0:

      if e.kind == sdl.Quit:
        quit 0

      if e.kind == sdl.KeyDown:
        let key = e.key.keysym.sym
        if key == K_ESCAPE or key == K_Q:
          return
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
          discard w.handleButton(e.button.x, e.button.y, e.button.button, true)
      
      if e.kind == sdl.MouseButtonUp:
        for w in app.widgets:
          discard w.handleButton(e.button.x, e.button.y, e.button.button, false)
      
      if e.kind == sdl.MouseWheel:
        for w in app.widgets:
          discard w.handleWheel(e.wheel.x, e.wheel.y)

      if e.kind == sdl.WindowEvent:
        if e.window.event == WINDOWEVENT_RESIZED:
          app.w = e.window.data1
          app.h = e.window.data2

      #if e.kind == sdl.UserEvent:
        #let bytes = e.user.code
        #let count = bytes /% sizeof(cfloat)
        #let p = e.user.data1
        #let buf = cast[ptr array[2048, cfloat]](p)[]
        #app.cb.writeInterlaced(buf, count)
        #cfree p

      if e.kind == EventKind(ord(sdl.UserEvent)+1):
        app.draw
        var fbuf = newSeq[cfloat](2)
        app.cb.writeInterleaved(fbuf)



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


proc loadsample(cb: CapBuf, fname: string) =
  var spec: AudioSpec
  var buf: ptr uint8
  var len: uint32
  let r = loadWAV(fname, addr spec, addr buf, addr len)
  if r != nil:
    assert spec.format == AUDIO_S16LSB
    var a = cast[ByteAddress](buf)
    var fbuf = newSeq[cfloat](3)
    let samples = int(len) /% 2
    for i in 0..samples:
      let pv = cast[ptr int16](a)
      a += sizeof(int16)
      fbuf[1] = cfloat(pv[]) / 32767.0
      fbuf[0] = fbuf[1]
      cb.writeInterleaved(fbuf)


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

  let n = sdl.getNumAudioDevices(1)

  for i in 1..n:
    closureScope:
      
      var want = AudioSpec(
        freq: 48000,
        format: AUDIO_F32,
        channels: 2,
        samples: 1024,
        callback: on_audio,
        userdata: cast[pointer](i)
      )
      var got = AudioSpec()
  
      let adev = openAudioDevice(nil, 1, addr want, addr got, 0)
      pauseAudioDevice(adev, 1)
      app.adevs.add(adev)


  discard addTimer(100, on_timer, nil)

  if true:
    for i in 1..32:
      loadsample(app.cb, "/tmp/" & $i & ".wav")

  if true:
    var a = newSeq[cfloat](3)

    for i in 0..(10*1024):
      a[0] = cos(float(i) * 0.4) * cos(float(i) * 0.001)
     
      a[1] = cos(float(i) * PI * 0.1001) * 0.3 - 0.5

      var f = 2.2
      if a[0] > 0:
         a[0] =  pow(a[0], f);
      else:
         a[0] = -pow(-a[0], f);

      a[0] = a[0] + cos(float(i) * 0.003) * 0.2
      a[0] = a[0] * 0.25 + 0.5

      if rand(1.0) < 0.01:
        a[0] = rand(1.0)

      app.cb.writeInterleaved(a)

  return app


# vi: ft=nim sw=2 ts=2

