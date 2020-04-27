Automaton = {}

Automaton.new = function( data )
  local automaton = {}

  automaton.__time = 0.0
  automaton.__version = @version
  automaton.__resolution = 1000
  automaton.__curves = {}
  automaton.__channels = {}
  automaton.__fxDefinitions = {}

  setmetatable( automaton, { __index = Automaton } )

  automaton.auto = function( name, callback ) return automaton:__auto( name, callback ) end

  automaton:deserialize( data );

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

  self.__curves = {}
  for iCurve, data in ipairs( data.curves ) do
    table.insert( self.__curves, AutomatonCurve.new( self, data ) )
  end

  self.__channels = {}
  for name, channel in pairs( data.channels ) do
    self.__channels[ name ] = AutomatonChannel.new( self, channel )
  end
end

Automaton.addFxDefinitions = function( self, fxDefinitions )
  for id, fxDef in pairs( fxDefinitions ) do
    self.__fxDefinitions[ id ] = fxDef
  end

  self:precalcAll()
end

Automaton.getFxDefinition = function( self, id )
  return self.__fxDefinitions[ id ] or nil
end

Automaton.getCurve = function( self, index )
  return self.__curves[ index + 1 ] or nil
end

Automaton.precalcAll = function( self )
  for _, curve in ipairs( self.__curves ) do
    curve:precalc()
  end
end

Automaton.reset = function( self )
  for _, channel in pairs( self.__channels ) do
    channel:reset()
  end
end

Automaton.update = function( self, time )
  local t = math.max( time, 0.0 )

  -- cache the time
  self.__time = t

  -- grab the current value for each channels
  for _, channel in pairs( self.__channels ) do
    channel:update( self.__time )
  end
end

Automaton.__auto = function( self, name, listener )
  if listener then
    self.__channels[ name ]:subscribe( listener )
  end

  return self.__channels[ name ]:getCurrentValue()
end
