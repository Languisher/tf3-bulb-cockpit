local M = dofile('mod/content/gui/bulb_cockpit/model.lua')
local function check(ids, next0, at, expected, passed, nextDisplay)
  local stops = {}
  for i, id in ipairs(ids) do stops[i] = {id=id, name=tostring(id), sourceIndex=i-1} end
  local r = M.journey(stops, next0, at)
  local actual = {}
  for _, s in ipairs(r.stops) do actual[#actual+1]=s.id end
  assert(table.concat(actual, ',') == expected, table.concat(actual, ','))
  assert(r.passed == passed, 'passed='..r.passed)
  assert(r.next == nextDisplay, 'next='..r.next)
end
check({'A','B','C','D','C','B'}, 2, false, 'A,B,C,D', 2, 3)
check({'A','B','C','D','C','B'}, 4, false, 'D,C,B,A', 1, 2)
check({'A','B','C','D','C','B'}, 3, true, 'D,C,B,A', 1, 2)
check({'A','B','C','D'}, 0, false, 'A,B,C,D', 0, 1)
check({'A','B','C','D'}, 2, true, 'A,B,C,D', 3, 4)
check({'A','B'}, 1, false, 'A,B', 1, 2)
check({'A','B'}, 0, false, 'B,A', 1, 2)
check({'A','B'}, 1, true, 'B,A', 1, 2)
check({'A'}, 0, false, 'A', 0, 1)
check({'A'}, 0, true, 'A', 1, 0)
check({'A','B','C','B','D'}, 4, false, 'A,B,C,B,D', 4, 5)
assert(M.journey({},0,false) == nil)
assert(M.journey({{id='A'}},-1,false) == nil)
print('13 journey cases passed')
