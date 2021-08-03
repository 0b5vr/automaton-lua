AutomatonCurve = {}

AutomatonCurve.new = function( automaton, data )
  local curve = {}

  curve.__automaton = automaton
  curve.__values = {}
  curve.__shouldNotInterpolate = {}
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
      time = node[ 1 ] or 0.0,
      value = node[ 2 ] or 0.0,
      inTime = node[ 3 ] or 0.0,
      inValue = node[ 4 ] or 0.0,
      outTime = node[ 5 ] or 0.0,
      outValue = node[ 6 ] or 0.0
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

    if self.__shouldNotInterpolate[ indexi ] == 1 then
      local vp = self.__values[ math.max( indexi - 1, 1 ) ]
      v1 = 2.0 * v0 - vp -- v0 + ( v0 - vp )
    end

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

    if i0 == iTail and iTail ~= 1 then
      this.__shouldNotInterpolate[ iTail - 1 ] = 1
    else
      for i = ( i0 + 1 ), iTail do
        local time = ( i - 1 ) / resolution
        local value = automatonBezierEasing( node0, nodeTail, time )
        self.__values[ i ] = value
      end
    end
  end

  local valuesLength = math.ceil( resolution * nodeTail.time ) + 2
  for i = ( iTail + 1 ), valuesLength do
    self.__values[ i ] = nodeTail.value
  end
end

AutomatonCurve.__applyFxs = function( self )
  local resolution = self.__automaton:getResolution()

  for iFx, fx in ipairs( self.__fxs ) do
    local fxDef = self.__automaton:getFxDefinition( fx.def )
    if fxDef then
      local availableEnd = math.min( self:getLength(), fx.time + fx.length )
      local i0 = 1 + math.ceil( resolution * fx.time )
      local i1 = 1 + math.floor( resolution * availableEnd )
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
          elapsed = 0.0,
          resolution = resolution,
          length = fx.length,
          params = fx.params,
          array = self.__values,
          shouldNotInterpolate = self.__shouldNotInterpolate[ i0 ] == 1,
          setShouldNotInterpolate = function( shouldNotInterpolate )
            this.__shouldNotInterpolate[ context.index ] = shouldNotInterpolate and 1 or 0
          end,
          getValue = function( time ) return self:getValue( time ) end,
          init = true,
          state = {}
        }

        for i = 1, tempLength do
          context.index = ( i - 1 ) + i0
          context.time = context.index / resolution
          context.value = self.__values[ context.index ]
          context.elapsed = context.time - fx.time
          context.progress = context.elapsed / fx.length
          context.shouldNotInterpolate = self.__shouldNotInterpolate[ ( i - 1 ) + i0 ] == 1
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
