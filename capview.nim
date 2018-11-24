{.experimental: "notnil".}

import capbuf
import math

type
  
  WindowType* = enum
    Blackman, Gaussian, Cauchy, Hanning, Hamming, Welch, Rectangle

  Window = ref object
    typ*: WindowType
    size*: int
    beta*: float
    data: seq[float]
    winType: WindowType

  CapView* = ref object
    cb*: CapBuf not nil
    cursor: int
    sel_start: int
    sel_end: int
    win*: Window


proc update*(w: Window) =
  let beta = w.beta
  w.data.setLen(w.size)
  for x in 0..w.size-1:
    let i = 2 * float(x) / float(w.size-1)
    var v = 0.0
    case w.typ
      of Blackman:
        v = 0.42 - 0.5 * cos(PI * i) + 0.08 * cos(2 * PI * i)
      of Gaussian:
        v = pow(E, -0.5 * (beta * (1.0 - i))^2)
      of Cauchy:
        v = 1.0 / (1.0 + (beta * (1.0 - i))^2)
      of Hamming:
        v = 0.54 - 0.46 * cos(PI * i)
      of Hanning:
        v = 0.5 - 0.5 * cos(PI * i)
      of Welch:
        v = 1.0 - (i - 1.0)^2
      of Rectangle:
        v = 1.0
    w.data[x] = v
  w.data[w.data.low()] = 0.0
  w.data[w.data.high()] = 0.0


proc getData*(w: Window): seq[float] =
  return w.data


proc newWindow(): Window = 
  let w = Window(
    typ: Blackman,
    size: 1024,
    beta: 3.0,
  )
  w.update()
  return w


proc newCapView*(cb: CapBuf): CapView =
  var cv = CapView(
    cb: cb,
    cursor: 0,
    win: newWindow(),
  )
  return cv


proc getCursor*(cv: CapView): int =
  return cv.cursor


proc setCursor*(cv: CapView, c: int) =
  cv.cursor = c


# vi: ft=nim sw=2 ts=2
