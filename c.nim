
when defined(profiling):
  echo "PROFILING"
  import nimprof
  disableProfiling() 

import math
import sdl2/sdl
import sdl2/sdl_ttf as ttf
import fftw3
import tables
import widget
import widget_null
import widget_scope
import widget_split
import widget_fft
import widget_waterfall
import app

discard sdl.init(sdl.InitVideo or sdl.InitAudio)
discard ttf.init()


let a = newApp(600, 400)
let split2 = newWidgetSplit()
split2.addWidget(newWidgetScope(a))
split2.addWidget(newWidgetWaterfall(a))
split2.addWidget(newWidgetFFT(a))

when true:

  a.addWidget(split2)

  discard a.run()
  

# vi: ft=nim sw=2 ts=2
