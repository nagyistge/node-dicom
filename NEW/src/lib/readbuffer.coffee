#! /usr/bin/env python
#

##
# ReadBuffer for TransformStream
#
# can push buffers into it
# maintains stream position
##
class ReadBuffer
  constructor: () ->
    if not (this instanceof ReadBuffer)
      return new ReadBuffer()
    # current offset in the first buffer
    @offset = 0
    # read position in the stream of input buffers
    @stream_position = 0
    # additional queued buffers
    @buffers = []
    # sum of all buffers minus offset
    @length = 0

  push: (buffer) ->
    rc = @buffers.push buffer
    @length += buffer.length
    rc

  has: (num_bytes) ->
    num_bytes <= @length

  # will consume exactly bytes
  # only call this if the buffer has bytes
  consume: (bytes) ->
    end = @offset + bytes
    buff = @buffers[0]
    # easy/fast case: first buffer sufficient
    if end <= buff.length
      dst = buff.slice(@offset, end)
      @offset += bytes
    else
      # more complicated case: have to combine multiple buffers
      dst = new Buffer(bytes)
      buff.copy(dst, 0, @offset, buff.length)
      dstPos = len = buff.length - @offset
      @offset = 0
      @buffers.shift()
      numBytes = bytes - len
      while numBytes > 0
        buff = @buffers[0]
        len = Math.min(numBytes, buff.length)
        buff.copy(dst, dstPos, 0, len)
        numBytes -= len
        dstPos += len
        if len == buff.length
          @buffers.shift()
          len = 0
      @offset = len

    @length -= bytes
    @streamPosition += bytes
    if @offset == buff.length
      @offset = 0
      @buffers.shift()
    return dst

  # will consume at most bytes, as much as we have right now
  # this will avoid copying if streaming out bulk data
  easy_consume: (bytes) ->
    end = @offset + bytes
    buff = @buffers[0]
    if end > buff.length
      end = buff.length
      bytes = buff.length - @offset
    dst = buff.slice(@offset, end)
    @offset += bytes
    @length -= bytes
    @streamPosition += bytes
    if @offset == buff.length
      @offset = 0
      @buffers.shift()
    return dst

  # this only works for ascii range separators, probably
  # lf or cr should be safe
  indexOf: (needle) ->
    if @length == 0
      return -1

    what = (new Buffer(needle))[0]
    buffers = @buffers
    buffers_length = @buffers.length
    buff = buffers[0]
    buff_length = buff.length
    offset = @offset

    for i in [offset...buff_length]
      if buff[i] == what
        return i - offset

    dpos = buff_length - offset
    for j in [1...buffers_length]
      buff = buffers[j]
      buff_length = buff.length

      for i in [0...buff_length]
        if buff[i] == what
          return dpos + i

      dpos += buff_length

    return -1

  # is a full line present in the buffer?
  # returns line length (including newline)
  # 0 if no full line present
  has_line: () ->
    idx = @indexOf '\n'
    return if idx >= 0 then idx + 1 else 0
  

module.exports = ReadBuffer
