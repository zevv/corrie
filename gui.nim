import sdl2/sdl
import widget
import textcache
import typetraits

type

  PackDir = enum
    PackHor, PackVer

  Box = ref object
    x, y: int
    rect: Rect
    packDir: PackDir
    padding: int
    margin: int

  Gui* = ref object
    id_active: int
    rect_hot: Rect
    textCache: TextCache
    rend: Renderer
    mx, my, mb: int
    colText: Color
    box: Box
    boxStack: seq[Box]


proc newGui*(rend: Renderer, textCache: TextCache): Gui =
  let g = Gui(rend: rend, textCache: textCache)
  g.colText = Color(r:255, g:255, b:255)
  return g


proc start*(g: Gui, x, y: int) =
  g.box = Box(x: x, y: y, padding: 5, margin: 5, packDir: PackVer)
  g.boxStack.add(g.box)


proc stop*(g: Gui) =
  return


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

proc updatePos(g: Gui, dx, dy: int) =
  if g.box.packDir == PackHor:
    g.box.x = g.box.x + dx + g.box.margin
  else:
    g.box.y = g.box.y + dy + g.box.margin

proc drawBg(g: Gui, rect: ptr Rect, hot: bool) =

  if hot:
    discard g.rend.setRenderDrawColor(70, 70, 200, 255)
    discard g.rend.setRenderDrawColor(150, 120, 50, 255)
  else:
    discard g.rend.setRenderDrawColor(30, 50, 100, 255)
  discard g.rend.renderFillRect(rect)

  discard g.rend.setRenderDrawColor(255, 50, 50, 255)
  discard g.rend.renderDrawRect(addr g.rect_hot)


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

  let tt = g.textCache.renderText(label, g.box.x+p, g.box.y+p, g.colText)
  
  var r_slider = Rect(x:g.box.x, y:g.box.y, w:w+p*2, h:tt.h+p*2)

  g.drawBg(addr r_slider, g.id_active == id)
  
  var r_knob = Rect(
    x: g.box.x + p + int(float(w-knob_w) * (val - val_min) / (val_max - val_min)), 
    y: g.box.y + p,
    w: knob_w,
    h: r_slider.h - p*2)
  discard g.rend.setRenderDrawColor(100, 200, 200, 255)
  discard g.rend.renderFillRect(addr r_knob)

  var r_label = Rect(x:g.box.x+p+m+w, y:g.box.y+p, w:tt.w, h:tt.h)
  discard g.rend.renderCopy(tt.tex, nil, addr r_label)

  g.updatePos(r_slider.w + r_label.w, r_slider.h)

  let valp = addr val
  proc on_move(x, y: int): bool =
    var val2 = val_min + float(x - r_slider.x - p - knob_w/%2) * 
               (val_max - val_min) / float(w-knob_w)
    val2 = min(val2, val_max)
    val2 = max(val2, val_min)
    if val2 != valp[]:
      valp[] = val2
      return true

  result = g.buttonAct(id, r_slider, on_move)


proc slider*(g: Gui, id: int, label: string, val: var int, val_min, val_max: int): bool =
  var valf = float(val)
  result = g.slider(id, label, valf, float(val_min), float(val_max))
  val = int(valf)

proc button*(g: Gui, id: int, label: string): bool =

  result = false
  let p = g.box.padding
  let m = g.box.margin

  let tt = g.textCache.renderText(label, g.box.x+p, g.box.y+p, g.colText)
  
  var r1 = Rect(x:g.box.x, y:g.box.y, w:tt.w+p*2, h:tt.h+p*2)
  g.drawBg(addr r1, g.id_active == id)

  var r2 = Rect(x:g.box.x+p, y:g.box.y+p, w:tt.w, h:tt.h)
  discard g.rend.renderCopy(tt.tex, nil, addr r2)

  g.updatePos(r1.w, r1.h)

  return g.buttonAct(id, r1)



proc button*(g: Gui, id: int, label: string, val: var bool): bool =
  let p = g.box.padding
  let m = g.box.margin

  let tt = g.textCache.renderText(label, g.box.x+p, g.box.y+p, g.colText)
  
  var r1 = Rect(x:g.box.x, y:g.box.y, w:tt.w+p*2, h:tt.h+p*2)
  g.drawBg(addr r1, val)

  var r2 = Rect(x:g.box.x+p, y:g.box.y+p, w:tt.w, h:tt.h)
  discard g.rend.renderCopy(tt.tex, nil, addr r2)

  g.updatePos(r1.w, r1.h)

  if g.buttonAct(id, r1):
    val = not val
    return true


proc select*(g: Gui, id: int, label: string, val: var int, items: seq[string]): bool =

  let m = g.box.margin
  let d = g.box.packDir

  g.box.margin = 0
  g.box.packDir = PackHor

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

  g.box.margin = m
  g.box.packdir = d



proc select2*(g: Gui, id: int, label: string, val: var int, items: seq[string]): bool =
  result = false
  var x = g.box.x
  var y = g.box.y
  let p = g.box.padding
  let m = g.box.margin

  var hTot = 0
  var wTot = 0

  for i in 0..len(items)-1:

    let item = items[i]
    let tt = g.textCache.renderText(item, x, y, g.colText)
    var r_bg = Rect(x: x, y: y, w: tt.w + p*2, h: tt.h + p*2)
    g.drawBg(addr r_bg, val == i)

    var r_text = Rect(x: x+g.box.padding, y: y+g.box.padding, w: tt.w, h: tt.h)
    discard g.rend.renderCopy(tt.tex, nil, addr r_text)
    x = x + tt.w + g.box.margin

    let inside = g.is_inside(id, r_bg)

    if g.id_active == id and g.mb == 0:
      if inside:
        echo "release ", i
        if inside:
          val = i
          result = true
        g.id_active = 0
    elif inside and g.mb == 1:
      g.id_active = id

    wTot = wTot + r_bg.w
    hTot = r_bg.h

  g.updatePos(wTot, hTot)


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
