-- Build 40420 enters first person through FreeCamTool.push with
-- cockpitCameraForEntity. getFollowEntity describes the ordinary camera and
-- is -1 in the user's cockpit screenshots, so it is not a cockpit target.
local C={}
local current,installed=nil,nil
local generation=0
local enterListeners={}
local exitListeners={}
function C.getEntity()return current end
function C.getGeneration()return generation end
function C.onEnter(fn)
  enterListeners[fn]=true
  return function()enterListeners[fn]=nil end
end
function C.onExit(fn)
  exitListeners[fn]=true
  return function()exitListeners[fn]=nil end
end
function C.install(tool,beforeExit)
  if installed then return end
  assert(tool and type(tool.push)=='function' and type(tool.pop)=='function','FreeCam tool unavailable')
  local push,pop=tool.push,tool.pop
  tool.push=function(ctx,param,...)
    local result=table.pack(push(ctx,param,...))
    local target=param and param.cockpitCameraForEntity or nil
    if current==target then return table.unpack(result,1,result.n)end
    current=target
    generation=generation+1
    log.verbose('[BULB native r43] cockpit entered: entity='..tostring(current))
    if current then for fn in pairs(enterListeners)do pcall(fn)end
    else
      if beforeExit then beforeExit()end
      for fn in pairs(exitListeners)do pcall(fn)end
    end
    return table.unpack(result,1,result.n)
  end
  tool.pop=function(...)
    -- Native exit changes the proxy root's layout before the next HUD tick.
    -- Hide its independent overlay before that camera/layout transition.
    if beforeExit then beforeExit()end
    -- Invalidate queued work before notifying either the visible parent or
    -- the child. A hidden child may not get another render/step at all.
    current=nil;generation=generation+1
    for fn in pairs(exitListeners)do pcall(fn)end
    local result=table.pack(pop(...))
    log.verbose('[BULB native r43] cockpit exited')
    return table.unpack(result,1,result.n)
  end
  installed=tool
end
return C
