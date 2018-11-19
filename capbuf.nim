

type

  Sample = cfloat
 
  CapChannel = ref object
    data: seq[Sample]

  CapBuf* = ref object
    memSize: int
    channelCount: int
    size: int
    head: int
    tail: int
    channels: seq[CapChannel]


proc realloc(cb: CapBuf) =
  cb.size = cb.memSize /% (cb.channelCount * sizeof(Sample))
  cb.head = 0
  cb.tail = 0
  cb.channels.setLen(0)

  for i in 0..cb.channelCount-1:
    var cc = CapChannel()
    cc.data = newSeq[Sample](cb.size)
    cb.channels.add(cc)

proc writeInterleaved*(cb: CapBuf, buf: seq[cfloat]) =

  if cb.size == 0:
    cb.realloc()

  var n = 0
  for ch in 0..cb.channelCount-1:
    let cc = cb.channels[ch]
    assert(cc != nil)
    cc.data[cb.head] = buf[n]
    inc(n)
  cb.head = (cb.head+1) mod cb.size


proc read*(cb: CapBuf, channel: int, index: int): float =

  if cb.size == 0:
    cb.realloc()

  let cc = cb.channels[channel]
  var i = cb.head - index
  while i < 0:
    i = i + cb.size
  return cc.data[i]


proc clear(cb: CapBuf) =
  cb.channels.setLen(0)
  cb.size = 0
  cb.head = 0
  cb.tail = 0


proc setChannelCount*(cb: CapBuf, channelCount: int) =
  cb.clear()
  cb.channelCount = channelCount



proc setMemSize*(cb: CapBuf, memSize: int) =
  cb.clear()
  cb.memSize = memSize


proc newCapBuf*(memSize: int = 1024*1024): CapBuf =
  var cb = CapBuf()
  cb.setMemSize(memSize)
  cb.setChannelCount(2)
  return cb


# vi: ft=nim sw=2 ts=2
