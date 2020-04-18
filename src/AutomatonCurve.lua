AutomatonCurve = {}

AutomatonCurve.new = function( automaton, data )
  local curve = {}

  curve.__automaton = automaton
  curve.__values = {}
  curve.__nodes = {}
  curve.__fxs = {}

  setmetatable( curve, { __index = AutomatonCurve } )

  curve:deserialize( data )

  return curve
end

AutomatonCurve.getLength = function( self )
  return self.__nodes[ table.getn( self.__nodes ) ].time
end

AutomatonCurve.deserialize = function( self, data )
  self.__nodes = data.nodes
  self.__fxs = data.fxs or {}

  self:precalc()
end

AutomatonCurve.precalc = function( self )
  local resolution = self.__automaton:getResolution()

  for iNode = 1, ( table.getn( self.__nodes ) - 1 ) do
    local node0 = self.__nodes[ iNode ]
    local node1 = self.__nodes[ iNode + 1 ]
    local i0 = 1 + math.floor( node0.time * resolution )
    local i1 = 1 + math.floor( node1.time * resolution )

    self.__values[ i0 ] = node0.value
    for i = ( i0 + 1 ), ( i1 + 1 ) do
      local time = ( i - 1 ) / resolution
      local value = automatonBezierEasing( node0, node1, time )
      self.__values[ i ] = value
    end
  end

  for iFx, fx in ipairs( self.__fxs ) do
    local fxDef = self.__automaton:getFxDefinition( fx.def )
    if fxDef then
      local i0 = math.ceil( resolution * fx.time )
      local i1 = math.floor( resolution * ( fx.time + fx.length ) )

      local tempValues = {}
      local tempLength = i1 - i0

      local context = {
        index = i0,
        i0 = i0,
        i1 = i1,
        time = fx.time,
        t0 = fx.time,
        t1 = fx.time + fx.length,
        deltaTime = 1.0 / resolution,
        value = 0.0,
        progress = 0.0,
        resolution = resolution,
        length = fx.length,
        params = fx.params,
        array = self.__values,
        getValue = function( time ) return self:getValue( time ) end,
        init = true,
        state = {}
      }

      for i = 1, tempLength do
        context.index = ( i - 1 ) + i0
        context.time = context.index / resolution
        context.value = self.__values[ context.index ]
        context.progress = ( context.time - fx.time ) / fx.length
        tempValues[ i ] = fxDef.func( context )

        context.init = false
      end

      for i = 1, tempLength do
        self.__values[ ( i - 1 ) + i0 ] = tempValues[ i ]
      end
    end
  end
end

AutomatonCurve.getValue = function( self, time )
  if time < 0.0 then
    -- clamp left
    return self.__values[ 1 ]

  elseif self:getLength() <= time then
    -- clamp right
    return self.__values[ table.getn( self.__values ) ]

  else
    -- fetch two values then do the linear interpolation
    local resolution = self.__automaton:getResolution()
    local index = time * resolution
    local indexi = math.floor( index )
    local indexf = index - indexi
    indexi = indexi + 1

    local v0 = self.__values[ indexi ]
    local v1 = self.__values[ indexi + 1 ]

    local v = v0 + ( v1 - v0 ) * indexf

    return v

  end
end
