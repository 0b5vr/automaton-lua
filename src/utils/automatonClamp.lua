automatonClamp = function( t, min, max )
  return t < min and min or max < t and max or t
end
