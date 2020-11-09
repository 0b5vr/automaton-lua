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
  self.__nodes = {}
  for _, node in ipairs( data.nodes ) do
    table.insert( self.__nodes, {
      time = node.time or 0.0,
      value = node.value or 0.0,
      [ 'in' ] = node[ 'in' ] or { time = 0.0, value = 0.0 },
      out = node.out or { time = 0.0, value = 0.0 }
    } )
  end

  self.__fxs = {}
  if data.fxs then
    for _, fx in ipairs( data.fxs ) do
      if not fx.bypass then
        table.insert( self.__fxs, {
          time = fx.time or 0.0,
          length = fx.length or 0.0,
          row = fx.row or 0,
          def = fx.def,
          params = fx.params
        } )
      end
    end
  end

  self:precalc()
end

AutomatonCurve.precalc = function( self )
  self:__generateCurve()
  self:__applyFxs()
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

AutomatonCurve.__generateCurve = function( self )
  local resolution = self.__automaton:getResolution()

  local nodeTail = self.__nodes[ 1 ]
  local iTail = 1
  for iNode = 1, ( table.getn( self.__nodes ) - 1 ) do
    local node0 = nodeTail
    nodeTail = self.__nodes[ iNode + 1 ]
    local i0 = iTail
    iTail = 1 + math.floor( nodeTail.time * resolution )

    self.__values[ i0 ] = node0.value
    for i = ( i0 + 1 ), iTail do
      local time = ( i - 1 ) / resolution
      local value = automatonBezierEasing( node0, nodeTail, time )
      self.__values[ i ] = value
    end
  end

  local valuesLength = math.ceil( resolution * nodeTail.time ) + 2
  for i = ( iTail + 1 ), valuesLength do
    self.__values[ i ] = nodeTail.value
  end
end

AutomatonCurve.__applyFxs = function( self )
  for iFx, fx in ipairs( self.__fxs ) do
    local fxDef = self.__automaton:getFxDefinition( fx.def )
    if fxDef then
      local availableEnd = math.min( self:getLength(), fx.time + fx.length )
      local i0 = math.ceil( resolution * fx.time )
      local i1 = math.floor( resolution * availableEnd )
      if i0 < i1 then
        local tempValues = {}
        local tempLength = i1 - i0 + 1

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
end
