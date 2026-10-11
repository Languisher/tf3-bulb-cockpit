local M = {}

-- TF3 stopIndex is zero based. Keep occurrences, never deduplicate by name.
function M.journey(stops, next0, atTerminal)
  local n = #stops
  if n == 0 or next0 < 0 or next0 >= n then return nil end
  if n == 1 then
    return {stops=stops, passed=atTerminal and 1 or 0, next=atTerminal and 0 or 1, shuttle=false}
  end
  local target = (next0 + (atTerminal and 1 or 0)) % n + 1
  local function wrap(i) return (i - 1) % n + 1 end
  if n == 2 and stops[1].id ~= stops[2].id then
    return {stops={stops[wrap(target-1)],stops[target]}, passed=1, next=2, shuttle=true}
  end
  local pivots = {}
  if n > 2 then
    for i = 1, n do
      if stops[wrap(i-1)].id == stops[wrap(i+1)].id then pivots[#pivots+1] = i end
    end
  end
  local shuttle = #pivots == 2
  if shuttle then
    local a, b = pivots[1], pivots[2]
    if b-a ~= n/2 then shuttle = false end
    for offset = 1, math.floor(n/2)-1 do
      if stops[wrap(a+offset)].id ~= stops[wrap(a-offset)].id then shuttle = false end
    end
  end
  local first, last = 1, n
  if shuttle then
    -- Targeting a terminus still belongs to the arriving leg.
    first = wrap(target-1)
    while first ~= pivots[1] and first ~= pivots[2] do first = wrap(first-1) end
    last = wrap(first+1)
    while last ~= pivots[1] and last ~= pivots[2] do last = wrap(last+1) end
  end
  local result = {stops={}, passed=0, next=1, shuttle=shuttle}
  local i = first
  repeat
    result.stops[#result.stops+1] = stops[i]
    if i == target then result.next = #result.stops end
    if i == last then break end
    i = wrap(i+1)
  until #result.stops > n
  result.passed = result.next-1
  return result
end

-- A circular stop array may encode a mirrored outbound/return service. Its
-- last array entry is then NOT a terminus. Reuse the actual journey rules.
function M.servicePath(stops)
  if #stops==1 then return stops end
  local leg=M.journey(stops,0,false)
  return leg and leg.shuttle and leg.stops or nil
end
return M
