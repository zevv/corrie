import sdl2/sdl
import widget
import textcache
import strutils
import typetraits

const DEF_MARGIN = 5
const DEF_PADDING = 4

type

  PackDir* = enum
    PackHor, PackVer

  Box = ref object
    x, y: int
    rect: Rect
    packDir: PackDir
    padding: int
    margin: int

  Gui* = ref object
    id_active: int
    debug: bool
    rect_hot: Rect
    textCache: TextCache
    rend: Renderer
    mx, my, mb: int
    colFg, colBg, colBgAct, colText, colHot, colBound: Color
    box: Box
    boxStack: seq[Box]


proc newGui*(rend: Renderer, textCache: TextCache): Gui =
  let g = Gui(rend: rend, textCache: textCache)
  g.colFg = Color(r: 150, g:120, b: 50, a:255)
  g.colBg = Color(r:30, g:50, b:100, a:255)
  g.colBgAct = Color(r:80, g:140, b:140, a:255)
  g.colText = Color(r:255, g:255, b:255, a:255)
  g.colHot = Color(r:255, g:0, b:0, a:255)
  g.colBound = Color(r:0, g:255, b:0, a:255)
  return g

proc updatePos(g: Gui, dx, dy: int) =
  if g.box.packDir == PackHor:
    g.box.x = g.box.x + dx + g.box.margin
  else:
    g.box.y = g.box.y + dy + g.box.margin

proc start*(g: Gui, x, y: int, packDir: PackDir = PackVer, margin: int = DEF_MARGIN) =
  g.box = Box(x: x, y: y, padding: DEF_PADDING, margin: margin, packDir: packDir)
  g.box.rect = Rect(x: x, y: y, w: 0, h: 0)
  g.boxStack.add(g.box)

proc start*(g: Gui, packDir: PackDir = PackVer, margin: int = DEF_MARGIN) =
  g.start(g.box.x, g.box.y, packDir, margin)

proc drawRect(g: Gui, r: var Rect, c: Color) =
  discard g.rend.setRenderDrawColor(c)
  discard g.rend.renderDrawRect(addr r)

proc fillRect(g: Gui, r: var Rect, c: Color) =
  discard g.rend.setRenderDrawColor(c)
  discard g.rend.renderFillRect(addr r)

proc drawTex(g: Gui, r: var Rect, t: Texture) =
  discard g.rend.renderCopy(t, nil, addr r)


proc horizontal*(g: Gui) =
  g.box.packDir = PackHor

proc vertical*(g: Gui) =
  g.box.packDir = PackVer

proc mouseMove*(g: Gui, x, y: int) =
  g.mx = x
  g.my = y

proc mouseButton*(g: Gui, x, y: int, b: int) =
  g.mx = x
  g.my = y
  g.mb = b

proc setBounds(g: Gui, rect: Rect) =
  let br = addr g.box.rect
  br.w = max(br.w, rect.x - br.x + rect.w)
  br.h = max(br.h, rect.y - br.y + rect.h)

proc drawBg(g: Gui, rect: var Rect, hot: bool) =
  g.fillRect(rect, if hot: g.colBgAct else: g.colBg)
  if g.debug: g.drawRect(g.rectHot, g.colHot)
  g.setBounds(rect)

proc stop*(g: Gui) =
  if g.debug:
    g.drawRect(g.box.rect, g.colBound) 

  let box_prev = g.boxStack.pop()
  let n = len(g.boxStack)
  g.box = if n > 0: g.boxStack[n-1] else: nil
  if g.box != nil:
    g.setBounds(box_prev.rect)
    g.updatePos(box_prev.rect.w, box_prev.rect.h)
  return

proc inRect(x, y: int, r: Rect): bool =
  return x >= r.x and x <= r.x+r.w and
         y >= r.y and y <= r.y+r.h


proc hasMouse(g: Gui, rect: Rect): bool = 
  return inRect(g.mx, g.my, rect)




proc is_inside(g: Gui, id: int, r: Rect): bool =
  result = g.hasMouse(r) and (g.id_active == 0 or g.id_active == id)
  if result:
    g.rect_hot = r


proc buttonAct(g: Gui, id: int, r: Rect, fn: proc(x, y: int): bool): bool =
  let inside = g.is_inside(id, r)

  if g.id_active == id and g.mb == 1:
    result = fn(g.mx, g.my)
  
  if g.id_active == id and g.mb == 0:
    if inside:
      result = true
    g.id_active = 0

  elif inside and g.mb == 1:
    g.id_active = id


proc buttonAct(g: Gui, id: int, r: Rect): bool =
  proc fn(x, y: int): bool = return false
  return buttonAct(g, id, r, fn)



proc slider*(g: Gui, id: int, label: string, val: var float, val_min, val_max: float): bool =

  result = false
  let p = g.box.padding
  let m = g.box.margin
  let w = 200
  let knob_w = 15

  proc val2x(val: float): int =
    return g.box.x + p + int(float(w-knob_w) * (val - val_min) / (val_max - val_min))

  proc x2val(x: int): float =
    result = val_min + float(x - g.box.x - p - knob_w/%2) *
               (val_max - val_min) / float(w-knob_w)
    result = clamp(result, val_min, val_max)

  let t = label & ": " & val.formatFloat(ffDecimal, 0)
  let tt = g.textCache.renderText(t, g.box.x+p, g.box.y+p, g.colText)
 
  var r_slider = Rect(x:g.box.x, y:g.box.y, w:w+p*2, h:tt.h+p*2)
  var r_label = Rect(x:g.box.x+(w - tt.w)/%2, y:g.box.y+p, w:tt.w, h:tt.h)
  var r_knob = Rect(x:val2x(val), y: g.box.y + p, w: knob_w, h: r_slider.h - p*2)
  g.drawBg(r_slider, g.id_active == id)
  g.fillRect(r_knob, g.colFg)
  g.drawTex(r_label, tt.tex)

  g.updatePos(r_slider.w + r_label.w, r_slider.h)

  let valp = addr val

  result = g.buttonAct(id, r_slider, proc(x, y: int): bool =
    var val2 = x2val(x)
    val2 = min(val2, val_max)
    val2 = max(val2, val_min)
    if val2 != valp[]:
      valp[] = val2
      return true
    )

proc slider*(g: Gui, id: int, label: string, val: var int, val_min, val_max: int): bool =
  var valf = float(val)
  result = g.slider(id, label, valf, float(val_min), float(val_max))
  val = int(valf)


proc button*(g: Gui, id: int, label: string): bool =
  let p = g.box.padding

  let tt = g.textCache.renderText(label, g.box.x+p, g.box.y+p, g.colText)
  var r1 = Rect(x:g.box.x, y:g.box.y, w:tt.w+p*2, h:tt.h+p*2)
  var r2 = Rect(x:g.box.x+p, y:g.box.y+p, w:tt.w, h:tt.h)

  g.drawBg(r1, g.id_active == id)
  g.drawTex(r2, tt.tex)
  g.updatePos(r1.w, r1.h)

  return g.buttonAct(id, r1)


proc button*(g: Gui, id: int, label: string, val: var bool): bool =
  let p = g.box.padding

  let tt = g.textCache.renderText(label, g.box.x+p, g.box.y+p, g.colText)
  var r1 = Rect(x:g.box.x, y:g.box.y, w:tt.w+p*2, h:tt.h+p*2)
  var r2 = Rect(x:g.box.x+p, y:g.box.y+p, w:tt.w, h:tt.h)

  g.drawBg(r1, val)
  g.drawTex(r2, tt.tex)

  g.updatePos(r1.w, r1.h)

  if g.buttonAct(id, r1):
    val = not val
    return true


proc select*(g: Gui, id: int, label: string, val: var int, items: seq[string]): bool =

  g.start(PackHor, 0)

  let n = len(items)
  var vals: seq[bool]
  for i in 0..len(items)-1:
    vals.add(i == val)

  g.horizontal()

  for i in 0..len(items)-1:
    let r = g.button(i+100, items[i], vals[i])
    if r:
      val = i
      result = true

  g.stop()


template select*(g: Gui, id: int, label: string, val: typed): bool =
  var names: seq[string]
  for i in low(val[].type)..high(val[].type):
    names.add $(val[].type)(i)
  var val2 = ord(val[])
  let rv = select(g, id, label, val2, names)
  if rv:
    val[] = (val[].type)(val2)
  rv


# vi: ft=nim sw=2 ts=2
