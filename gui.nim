import sdl2/sdl
import widget
import textcache
import typetraits

type

  Gui* = ref object
    x, y: int
    textCache: TextCache
    rend: Renderer
    mx, my, mb: int
    id_hot, id_active: int
    padding: int
    margin: int
    colText: Color


proc newGui*(rend: Renderer, textCache: TextCache): Gui =
  let g = Gui(rend: rend, textCache: textCache)
  g.colText = Color(r:255, g:255, b:255)
  g.padding = 5
  g.margin = 8
  return g


proc start*(g: Gui, x, y: int) =
  g.x = x
  g.y = y


proc mouseMove*(g: Gui, x, y: int) =
  g.mx = x
  g.my = y

proc mouseButton*(g: Gui, x, y: int, b: int) =
  g.mx = x
  g.my = y
  g.mb = b


proc drawBg(g: Gui, rect: ptr Rect, hot: bool) =

  if hot:
    discard g.rend.setRenderDrawColor(70, 70, 200, 255)
    discard g.rend.setRenderDrawColor(150, 120, 50, 255)
  else:
    discard g.rend.setRenderDrawColor(30, 50, 100, 255)
  discard g.rend.renderFillRect(rect)

  #discard g.rend.setRenderDrawColor(50, 50, 50, 255)
  #discard g.rend.renderDrawRect(rect)


proc inRect(x, y: int, r: Rect): bool =
  return x >= r.x and x <= r.x+r.w and
         y >= r.y and y <= r.y+r.h


proc hasMouse(g: Gui, rect: Rect): bool = 
  return inRect(g.mx, g.my, rect)



proc slider*(g: Gui, id: int, label: string, val: var float, val_min, val_max: float): bool =

  result = false
  let p = g.padding
  let m = g.margin
  let w = 200
  let knob_w = 15

  let tt = g.textCache.renderText(label, g.x+p, g.y+p, g.colText)
  
  var r_slider = Rect(x:g.x, y:g.y, w:w+p*2, h:tt.h+p*2)

  g.drawBg(addr r_slider, g.id_active == id)
  
  var r_knob = Rect(
    x: g.x + p + int(float(w-knob_w) * (val - val_min) / (val_max - val_min)), 
    y: g.y + p,
    w: knob_w,
    h: r_slider.h - p*2)
  discard g.rend.setRenderDrawColor(100, 200, 200, 255)
  discard g.rend.renderFillRect(addr r_knob)

  var r_label = Rect(x:g.x+p+m+w, y:g.y+p, w:tt.w, h:tt.h)
  discard g.rend.renderCopy(tt.tex, nil, addr r_label)

  g.y = g.y + r_slider.h + m

  var hot = false

  if g.hasMouse(r_slider) and g.id_active == 0:
    hot = true
    g.id_hot = id
  
  if g.id_active == id:
    if g.mb == 1:
      var val2 = val_min + float(g.mx - r_slider.x - p - knob_w/%2) * 
                 (val_max - val_min) / float(w-knob_w)
      val2 = min(val2, val_max)
      val2 = max(val2, val_min)
      if val2 != val:
        val = val2
        result = true
    else:
      result = true
      g.id_active = 0

  elif hot and g.mb == 1:
    g.id_active = id


proc slider*(g: Gui, id: int, label: string, val: var int, val_min, val_max: int): bool =
  var valf = float(val)
  result = g.slider(id, label, valf, float(val_min), float(val_max))
  val = int(valf)


proc is_inside(g: Gui, id: int, r: Rect): bool =
  result = g.hasMouse(r) and (g.id_active == 0 or g.id_active == id)
  if result:
    g.id_hot = id

proc button*(g: Gui, id: int, label: string): bool =

  result = false
  let p = g.padding
  let m = g.margin

  let tt = g.textCache.renderText(label, g.x+p, g.y+p, g.colText)
  
  var r1 = Rect(x:g.x, y:g.y, w:tt.w+p*2, h:tt.h+p*2)
  g.drawBg(addr r1, g.id_active == id)

  var r2 = Rect(x:g.x+p, y:g.y+p, w:tt.w, h:tt.h)
  discard g.rend.renderCopy(tt.tex, nil, addr r2)

  g.y = g.y + tt.h+p*2+m

  let inside = g.is_inside(id, r1)

  if inside:
    g.id_hot = id
  
  if g.id_active == id and g.mb == 0:
    if inside:
      result = true
    g.id_active = 0

  elif inside and g.mb == 1:
    g.id_active = id



proc select*(g: Gui, id: int, label: string, val: var int, items: seq[string]): bool =
  result = false
  var x = g.x
  var y = g.y
  let p = g.padding
  let m = g.margin

  for i in 0..len(items)-1:

    let item = items[i]
    let tt = g.textCache.renderText(item, x, y, g.colText)
    var r_bg = Rect(x: x, y: y, w: tt.w + p*2, h: tt.h + p*2)
    g.drawBg(addr r_bg, val == i)

    var r_text = Rect(x: x+g.padding, y: y+g.padding, w: tt.w, h: tt.h)
    discard g.rend.renderCopy(tt.tex, nil, addr r_text)
    x = x + tt.w + g.margin
 
    let inside = g.is_inside(id, r_bg)

    if g.id_active == id:
      if inside and g.mb == 0:
        echo "release ", i
        if inside:
          val = i
          result = true
        g.id_active = 0

    elif inside and g.mb == 1:
      g.id_active = id

    if i == 0:
      g.y = g.y + r_bg.h + m


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
