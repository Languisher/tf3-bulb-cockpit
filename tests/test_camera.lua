local C=dofile('mod/content/gui/bulb_cockpit/camera_state.lua')
local calls={}
local fail=false
local nativeEntered,beforeExit,notifications=false,0,0
local tool={
  push=function(ctx,param,extra)
    if fail then error('camera failed') end
    calls[#calls+1]={'push',ctx,param,extra};nativeEntered=true;return 'native',nil,42
  end,
  pop=function(...)calls[#calls+1]={'pop',...};return 'left' end,
}
log={verbose=function()end}
C.install(tool,function()beforeExit=beforeExit+1 end)
local unsubscribe=C.onEnter(function()
  assert(nativeEntered and C.getEntity()==82579,'notify only after successful native entry and target update')
  notifications=notifications+1
end)
local exitNotifications=0
local unsubscribeExit=C.onExit(function()
  assert(beforeExit==1 and C.getEntity()==nil,'invalidate camera work after hiding and before the native exit')
  exitNotifications=exitNotifications+1
end)
local push=tool.push;C.install(tool);assert(tool.push==push,'install once without replacing tool identity')
local ctx,param={}, {cockpitCameraForEntity=82579}
local a,b,c=tool.push(ctx,param,'unchanged')
assert(a=='native' and b==nil and c==42)
assert(calls[1][2]==ctx and calls[1][3]==param and calls[1][4]=='unchanged')
assert(C.getEntity()==82579,'use the cockpit parameter even if getFollowEntity is -1')
assert(notifications==1)
local unchangedGeneration=C.getGeneration()
tool.push(ctx,param,'same vehicle')
assert(notifications==1 and C.getGeneration()==unchangedGeneration,'same-vehicle camera updates cannot reset the route session')
fail=true
local ok=pcall(tool.push,ctx,{cockpitCameraForEntity=100})
assert(not ok and C.getEntity()==82579,'preserve original errors and previous camera state')
assert(notifications==1,'failed native entry must not wake the HUD')
fail=false
assert(tool.pop(ctx)=='left' and C.getEntity()==nil,'clear the target when the cockpit tool exits')
assert(beforeExit==1)
assert(exitNotifications==1)
unsubscribeExit();unsubscribeExit()
unsubscribe();unsubscribe()
tool.push(ctx,{cockpitCameraForEntity=100})
assert(notifications==1,'unmounted HUD listeners must be released')
tool.push(ctx,{})
assert(C.getEntity()==nil,'free camera has no vehicle route')
tool.pop(ctx);assert(exitNotifications==1,'unmounted exit listeners must be released')
print('PASS: cockpit target follows real FreeCam tool entry/exit; arguments, returns and errors preserved')
