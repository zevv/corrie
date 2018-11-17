import sdl2/sdl
import widget
import app
import widget_scope
import textcache
import capview

type

  Child = ref object
    widget: Widget
    x, y: int

  WidgetSplit = ref object of Widget
    children: seq[Child]
    horizontal: bool

proc newWidgetSplit*(horizontal: bool = false): WidgetSplit =
  let w = WidgetSplit()
  w.horizontal = horizontal
  return w


proc containsXY(c: Child, x, y: int): bool = 
  return x >= c.x and x <= c.x + c.widget.w and
         y >= c.y and y <= c.y + c.widget.h


method handleMouse*(w: WidgetSplit, x, y: int): bool =
  var handled: bool = false
  for child in w.children:
    if containsXY(child, x, y):
      let h = child.widget.handleMouse(x - child.x, y - child.y)
      if h: handled = true
  return handled

method handleButton*(w: WidgetSplit, x, y: int, state: bool): bool =
  var handled: bool = false
  for child in w.children:
    if containsXY(child, x, y):
      let h = child.widget.handleButton(x - child.x, y - child.y, state)
      if h: handled = true
  return handled

method handleKey(w: WidgetSplit, key: Keycode, x, y: int): bool =
  var handled: bool = false
  for child in w.children:
    if containsXY(child, x, y):
      let h = child.widget.handleKey(key, x, y)
      if h: handled = true

  if not handled:
    if key == K_i:
      var i = 0
      var iins = -1
      for child in w.children:
        if child.containsXY(x, y):
          iins = i
        i = i + 1
      if iins != -1:
        #let cnew = Child(widget: newWidgetScope())
        #w.children.insert(cnew, iins)
        handled = true

    if key == K_x:
      var i = 0
      var idel = -1
      for child in w.children:
        if child.containsXY(x, y):
          idel = i
        i = i + 1
      if idel != -1:
        w.children.del(idel)
        handled = true

    if key == K_f:
      w.horizontal = not w.horizontal
      handled = true

  return handled


method draw(w: WidgetSplit, rend: Renderer, app: App, cv: CapView) =

  let n = len(w.children)

  if n == 0:
    return

  let margin = 8

  var x = margin
  var y = margin
  let dx = (w.w - margin) /% n
  let dy = (w.h - margin) /% n

  for child in w.children:

    child.x = x
    child.y = y

    if w.horizontal:
      child.widget.w = dx - margin
      child.widget.h = w.h - margin*2
      x = x + dx
    else:
      child.widget.w = w.w - margin*2
      child.widget.h = dy - margin
      y = y + dy
    
    var rect = Rect(
      x: child.x,
      y: child.y,
      w: child.widget.w,
      h: child.widget.h)


    discard app.rend.setRenderDrawColor(0, 0, 0, 255)
    discard app.rend.renderFillRect(addr rect)
    discard app.rend.rendersetClipRect(addr rect)

    discard app.rend.renderSetViewPort(addr rect)
    child.widget.draw(rend, app, cv)
    discard app.rend.renderSetViewPort(nil)
   
    if child.widget.hasFocus:
      discard app.rend.setRenderDrawColor(255, 0, 0, 255)
    else:
      discard app.rend.setRenderDrawColor(80, 80, 80, 255)
    discard app.rend.renderDrawRect(addr rect)
    discard app.rend.rendersetClipRect(nil)
  
    app.textCache.drawText(child.widget.label, child.x+5, child.y+2)
    


method updateFocus(w: WidgetSplit, x, y: int): bool =
  result = false
  for child in w.children:
    child.widget.hasFocus = false
    let t = child.widget.updateFocus(x, y)
    if child.containsXY(x, y):
      if t == false:
        child.widget.hasFocus = true
        result = true


method addWidget*(w: WidgetSplit, wchild: Widget) =
  w.children.add(Child(widget: wchild))

# vi: ft=nim sw=2 ts=2
