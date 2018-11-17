
import sdl2/sdl
import sdl2/sdl_ttf
import tables
    
type

  TextTex* = ref object
    tex*: Texture
    w*, h*: int
    age: int
  
  TextCache* = ref object
    font: Font
    cache: Table[string, TextTex]
    rend: Renderer
    ticks: int


proc newTextCache*(rend: Renderer, fontname: string): TextCache =
  var tc = TextCache(
    rend: rend,
    font: openFont("font.ttf", 12),
    cache: initTable[string, TextTex](),
  )
  assert(tc.font != nil)
  return tc

proc pruneCache(tc: TextCache) =
  tc.ticks = tc.ticks + 1
  if tc.ticks > 128:
    tc.ticks = 0
    for s, tex in pairs(tc.cache):
      inc(tex.age)
      if tex.age > 10:
        destroyTexture(tex.tex)
        tc.cache.del(s)

proc renderText*(tc: TextCache, text: string, x, y: int, color: Color): TextTex =
  if len(text) > 0:
    try:
      result = tc.cache[text]
    except KeyError:
      let s = tc.font.renderUTF8_Blended(text, color)
      let tex = tc.rend.createTextureFromSurface(s)
      result = TextTex(tex: tex, w: s.w, h: s.h)
      freeSurface(s)
      tc.cache[text] = result
  if result != nil:
    result.age = 0
  tc.pruneCache()

proc drawText*(tc: TextCache, text: string, x, y: int, color: Color) =
  let tt = tc.renderText(text, x, y, color)
  if tt != nil:
    var rect = sdl.Rect(x: x, y: y, w: tt.w, h: tt.h)
    discard tc.rend.renderCopy(tt.tex, nil, addr(rect))

proc drawText*(tc: TextCache, text: string, x, y: int, r, g, b: uint8) =
  let color = Color(r: r, g: g, b: b)
  drawText(tc, text, x, y, color)

proc drawText*(tc: TextCache, text: string, x, y: int) =
  let color = Color(r: 100, g: 100, b: 100)
  drawText(tc, text, x, y, color)



# vi: ft=nim et ts=2 sw=2

