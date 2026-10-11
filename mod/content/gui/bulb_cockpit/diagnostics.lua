-- Opt-in development observer, disabled in normal gameplay. Build 40420 exposes
-- main-thread join processor. Observing it avoids depending on a hidden or
-- expired component's onMount/onStepTimer. No GUI state is changed here.
local D={}
local counts,watched={},{}
local original,frames,lastSignature=nil,0,nil
local cameraReader
local enabled=false
local stages={'root.render','root.mount','root.timer','root.measure','root.expired',
  'hud.render','hud.timer','hud.refresh','hud.expired','settings.render'}
local components={
  {'host','linnan.bulb.host'}, {'native','react.game-free-cam'},
  {'gauge','linnan.bulb.gauge'}, {'hud','linnan.bulb.hud'},
  {'canvas','linnan.bulb.canvas'},
  {'settings','linnan.bulb.settings'}, {'gameUI','react.game-ui-root'},
}
local function read(fn)
  local ok,value=pcall(fn)
  return ok and tostring(value) or 'unavailable: '..tostring(value)
end
function D.note(stage,detail)
  if not enabled then return end
  counts[stage]=(counts[stage] or 0)+1
  if counts[stage]==1 then
    log.verbose('[BULB native r43] stage='..stage..(detail and '; '..detail or ''))
  end
end
function D.watch(name,reference,state)
  if not enabled then return end
  watched[name]={reference=reference,state=state}
end
function D.setCameraReader(reader)cameraReader=reader end
local function observe()
  local geometry={}
  geometry[#geometry+1]='follow='..read(function()
    return api.gui.camera.getFollowEntity()[1]
  end)
  if cameraReader then geometry[#geometry+1]='cockpit='..read(cameraReader) end
  for _,component in ipairs(components) do
    geometry[#geometry+1]=component[1]..'='..read(function()
      local id=component[2]
      local size=api.gui.byId.getSize(id)
      return string.format('raw=%.6fx%.6f, visible=%s, recursive=%s',size.x,size.y,
        tostring(api.gui.byId.isVisible(id)),tostring(api.gui.byId.isVisibleRecursive(id)))
    end)
  end
  for _,name in ipairs({'root','hud'}) do
    local watch=watched[name]
    if watch then
      geometry[#geometry+1]=name..'.stateExpired='..read(function()return watch.state:hasExpired()end)
      geometry[#geometry+1]=name..'.state='..read(function()
        if watch.state:hasExpired() then return 'expired' end
        local value=watch.state:old()
        if not value then return 'empty' end
        if name=='root' then return string.format('%.0fx%.0f',value.x,value.y) end
        return value.route and string.format('line=%s, stops=%d, next=%s, passed=%s',
          tostring(value.route.lineId),#value.route.stops,tostring(value.next),tostring(value.passed)) or 'no route'
      end)
      geometry[#geometry+1]=name..'.ref='..read(function()
        local node=watch.reference:get()
        if not node then return 'not mounted' end
        local first,last=node:getPosition(0,0),node:getPosition(1,1)
        return string.format('%.3f,%.3f..%.3f,%.3f',first.x,first.y,last.x,last.y)
      end)
    end
  end
  local lifecycle,presence={},{}
  for _,name in ipairs(stages) do
    local count=counts[name] or 0
    lifecycle[#lifecycle+1]=name..'='..count
    presence[#presence+1]=name..'='..(count>0 and 'seen' or 'absent')
  end
  local signature=table.concat(geometry,'; ')..'; '..table.concat(presence,', ')
  if signature~=lastSignature or frames==600 or frames%3600==0 then
    lastSignature=signature
    log.verbose('[BULB native r43] observer; joins='..frames..'; '..table.concat(geometry,'; ')
      ..'; lifecycle: '..table.concat(lifecycle,', '))
  end
end
function D.install(development)
  if development~=true then return false end
  if original then return true end
  if type(_reactDoExecuteJoins)~='function' then
    log.warning('[BULB native r43] diagnostic join processor unavailable')
    return false
  end
  original=_reactDoExecuteJoins
  enabled=true
  _reactDoExecuteJoins=function(...)
    local result=table.pack(original(...))
    frames=frames+1
    if frames==1 or frames%120==0 then
      local ok,err=pcall(observe)
      if not ok then
        -- Even a diagnostic failure must leave the original join intact.
        pcall(log.warning,'[BULB native r43] observer failed: '..tostring(err))
      end
    end
    return table.unpack(result,1,result.n)
  end
  return true
end
return D
