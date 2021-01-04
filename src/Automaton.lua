Automaton = {}

Automaton.new = function( data, options )
  local automaton = {}

  automaton.curves = {}
  automaton.channels = {}
  automaton.mapNameToChannel = {}

  automaton.__time = 0.0
  automaton.__version = '@version'
  automaton.__resolution = 1000
  automaton.__fxDefinitions = {}

  setmetatable( automaton, { __index = Automaton } )

  automaton.auto = function( name, callback ) return automaton:__auto( name, callback ) end

  if options and options.fxDefinitions then
    automaton:addFxDefinitions( options.fxDefinitions )
  end

  automaton:deserialize( data )

  return automaton
end

Automaton.getTime = function( self )
  return self.__time
end

Automaton.getVersion = function( self )
  return self.__version
end

Automaton.getResolution = function( self )
  return self.__resolution
end

Automaton.deserialize = function( self, data )
  self.__length = data.length
  self.__resolution = data.resolution

  self.curves = {}
  for iCurve, data in ipairs( data.curves ) do
    table.insert( self.curves, AutomatonCurve.new( self, data ) )
  end

  self.mapNameToChannel = {}
  self.channels = {}
  for iChannel, tuple in ipairs( data.channels ) do
    local channel = AutomatonChannel.new( self, tuple[ 2 ] )
    table.insert( self.channels, channel )
    self.mapNameToChannel[ tuple[ 1 ] ] = channel
  end
end

Automaton.addFxDefinitions = function( self, fxDefinitions )
  for id, fxDef in pairs( fxDefinitions ) do
    if type( fxDef.func ) == 'function' then
      self.__fxDefinitions[ id ] = fxDef
    end
  end

  self:precalcAll()
end

Automaton.getFxDefinition = function( self, id )
  return self.__fxDefinitions[ id ] or nil
end

Automaton.getCurve = function( self, index )
  return self.curves[ index + 1 ] or nil
end

Automaton.precalcAll = function( self )
  for _, curve in ipairs( self.curves ) do
    curve:precalc()
  end
end

Automaton.reset = function( self )
  for _, channel in ipairs( self.channels ) do
    channel:reset()
  end
end

Automaton.update = function( self, time )
  local t = math.max( time, 0.0 )

  -- cache the time
  self.__time = t

  -- consume channel items
  local array = {}
  for chIndex, channel in ipairs( self.channels ) do
    for _, v in ipairs( channel:consume( self.__time ) ) do
      table.insert( array, { v[ 1 ], v[ 2 ], chIndex } )
      --                                     ^^^^^^^ because lua table.sort is not stable,,,
    end
  end

  -- sort items
  table.sort( array, function( a, b )
    if a[ 1 ] ~= b[ 1 ] then
      return a[ 1 ] < b[ 1 ]
    else
      -- because lua table.sort is not stable,,,
      return a[ 3 ] < b[ 3 ]
    end
  end )

  -- execute items
  for _, item in ipairs( array ) do
    item[ 2 ]()
  end
end

Automaton.__auto = function( self, name, listener )
  local channel = self.mapNameToChannel[ name ]
  if not channel then return end

  if listener then
    channel:subscribe( listener )
  end

  return channel:getCurrentValue()
end
