
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
import app

discard sdl.init(sdl.InitVideo or sdl.InitAudio)
discard ttf.init()


let a = newApp(600, 400)
let scope = newWidgetScope()
let split1 = newWidgetSplit(true)
let split2 = newWidgetSplit()

split1.addWidget(newWidgetScope())
split1.addWidget(newWidgetScope())
split2.addWidget(newWidgetScope())
split2.addWidget(newWidgetFFT(a))

when true:

  a.addWidget(split2)

  discard a.run()
  

# vi: ft=nim sw=2 ts=2
