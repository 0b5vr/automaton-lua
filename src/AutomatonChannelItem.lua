AutomatonChannelItem = {}

AutomatonChannelItem.new = function( automaton, data )
  local item = {}

  item.__automaton = automaton

  setmetatable( item, { __index = AutomatonChannelItem } )

  item:deserialize( data )

  return item
end

AutomatonChannelItem.deserialize = function( self, data )
  self.time = data.time or 0.0
  self.length = data.length or 0.0
  self.value = data.value or 0.0
  self.offset = data.offset or 0.0
  self.speed = data.speed or 1.0
  self.amp = data.amp or 1.0

  if data.curve then
    self.curve = self.__automaton:getCurve( data.curve )
    self.length = data.length or self.curve:getLength() or 1.0
  end
end

AutomatonChannelItem.getValue = function( self, time )
  if self.curve then
    local t = self.offset + time * self.speed
    return self.value + self.amp * self.curve:getValue( t )
  end

  return self.value
end
