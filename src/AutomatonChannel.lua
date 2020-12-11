AutomatonChannel = {}

AutomatonChannel.new = function( automaton, data )
  local channel = {}

  channel.__automaton = automaton
  channel.__items = {}
  channel.__value = 0.0
  channel.__time = -1E999 -- -math.huge
  channel.__head = 1
  channel.__listeners = {}

  setmetatable( channel, { __index = AutomatonChannel } )

  channel:deserialize( data );

  return channel
end

AutomatonChannel.getCurrentValue = function( self )
  return self.__value
end

AutomatonChannel.getCurrentTime = function( self )
  return self.__time
end

AutomatonChannel.deserialize = function( self, data )
  self.__items = {}
  for iItem, item in ipairs( data.items or {} ) do
    self.__items[ iItem ] = AutomatonChannelItem.new( self.__automaton, item )
  end
end

AutomatonChannel.reset = function( self )
  self.__time = -1E999 -- -math.huge
  self.__value = 0.0
  self.__head = 1
end

AutomatonChannel.subscribe = function( self, listener )
  table.insert( self.__listeners, listener )
end

AutomatonChannel.getValue = function( self, time )
  local next = table.getn( self.__items )
  for iItem, item in ipairs( self.__items ) do
    if time < item.time then
      next = iItem
      break
    end
  end

  -- it's the first one!
  if next == 1 then
    return 0.0
  end

  local item = self.__items[ next ]
  if item.getEnd() < time then
    return item:getValue( item.length )
  else
    return item:getvalue( time - item.time )
  end
end

AutomatonChannel.consume = function( self, time )
  local ret = {}

  local prevTime = self.__time

  for iItem = self.__head, table.getn( self.__items ) do
    local item = self.__items[ iItem ]
    local begin = item.time
    local length = item.length
    local elapsed = time - begin

    if elapsed < 0.0 then
      break
    else
      local progress = 0.0
      local init = false
      local uninit = false

      if length <= elapsed then
        elapsed = length
        progress = 1.0
        uninit = true

        if iItem == self.__head then
          self.__head = self.__head + 1
        end
      else
        progress = length ~= 0.0
          and ( elapsed / length )
          or 1.0
      end

      if prevTime < begin then
        init = true
      end

      table.insert( ret, { begin + elapsed, function()
        self.__value = item:getValue( elapsed )

        for _, listener in ipairs( self.__listeners ) do
          listener( {
            time = time,
            elapsed = elapsed,
            begin = begin,
            [ 'end' ] = begin + length,
            length = length,
            value = self.__value,
            progress = progress,
            init = init,
            uninit = uninit
          } )
        end
      end } )
    end
  end

  self.__time = time

  return ret
end
