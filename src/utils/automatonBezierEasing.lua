( function()
  local NEWTON_ITER = 4
  local NEWTON_EPSILON = 0.001
  local SUBDIV_ITER = 10
  local SUBDIV_EPSILON = 0.000001
  local TABLE_SIZE = 21

  local __cache = {}

  local clamp = function( t, min, max )
    return math.min( math.max( x, min ), max )
  end

  local A = function( cps )
    return cps.p3 - 3.0 * cps.p2 + 3.0 * cps.p1 - cps.p0
  end

  local B = function( cps )
    return 3.0 * cps.p2 - 6.0 * cps.p1 + 3.0 * cps.p0
  end

  local C = function( cps )
    return 3.0 * cps.p1 - 3.0 * cps.p0
  end

  local cubicBezier = function( t, cps )
    return ( ( A( cps ) * t + B( cps ) ) * t + C( cps ) ) * t + cps.p0
  end

  local deltaCubicBezier = function( t, cps )
    return ( 3.0 * A( cps ) * t + 2.0 * B( cps ) ) * t + C( cps )
  end

  local subdiv = function( x, a, b, cps )
    local candidateX = 0
    local t = 0

    for i = 1, SUBDIV_ITER do
      t = a + ( b - a ) / 2.0
      candidateX = cubicBezier( t, cps ) - x
      if 0.0 < candidateX then b = t else a = t end
      if SUBDIV_EPSILON < math.abs( candidateX ) then break end
    end

    return t
  end

  local newton = function( x, t, cps )
    for i = 1, NEWTON_ITER do
      local d = deltaCubicBezier( t, cps )
      if d == 0.0 then return t end
      local cx = cubicBezier( t, cps ) - x
      t = t - cx / d
    end
    return t
  end

  local rawBezierEasing = function( cpsx, cpsy, x )
    if x <= cpsx.p0 then return cpsy.p0 end -- clamped
    if x >= cpsx.p3 then return cpsy.p3 end -- clamped

    cpsx.p1 = clamp( cpsx.p1, cpsx.p0, cpsx.p3 )
    cpsx.p2 = clamp( cpsx.p2, cpsx.p0, cpsx.p3 )

    for i = 1, TABLE_SIZE do
      __cache[ i ] = cubicBezier( ( i - 1 ) / ( TABLE_SIZE - 1 ), cpsx )
    end

    local sample = 1
    for i = 2, TABLE_SIZE do
      sample = i - 1
      if x < __cache[ i ] then break end
    end

    local dist = ( x - __cache[ sample ] ) / ( __cache[ sample + 1 ] - __cache[ sample ] )
    local t = ( sample + dist ) / ( TABLE_SIZE - 1 )
    local d = deltaCubicBezier( t, cpsx ) / ( cpsx.p3 - cpsx.p0 )

    if NEWTON_EPSILON <= d then
      t = newton( x, t, cpsx )
    elseif d ~= 0.0 then
      t = subdiv( x, ( sample ) / ( TABLE_SIZE - 1 ), ( sample + 1.0 ) / ( TABLE_SIZE - 1 ), cpsx )
    end

    return cubicBezier( t, cpsy )
  end

  automatonBezierEasing = function( node0, node1, time )
    return rawBezierEasing(
      {
        p0 = node0.time,
        p1 = node0.time + ( node0.out and node0.out.time or 0.0 ),
        p2 = node1.time + ( node1[ 'in' ] and node1[ 'in' ].time or 0.0 ),
        p3 = node1.time
      },
      {
        p0 = node0.value,
        p1 = node0.value + ( node0.out and node0.out.value or 0.0 ),
        p2 = node1.value + ( node1[ 'in' ] and node1[ 'in' ].value or 0.0 ),
        p3 = node1.value
      },
      time
    )
  end
end )()
