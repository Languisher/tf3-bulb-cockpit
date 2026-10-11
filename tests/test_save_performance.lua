-- Count writes to the engine interface, not hypothetical duplicate saved events.
local script=arg[1] or 'mod/content/game_mechanics/bulb_aliases/bulb_aliases.script.lua'
local function loadScript()
  local env=setmetatable({},{__index=_G})
  assert(loadfile(script,'t',env))()
  return env.data()
end
local events={'linnan.bulb.setAlias','linnan.bulb.setBusNaming',
  'linnan.bulb.setStationLink','linnan.bulb.setOptions','linnan.bulb.setDefaults'}
local function savedState(value,subscriptions)
  local counts={subscribe=0,get=0,set=0,checks=0}
  local state={}
  function state:get()counts.get=counts.get+1;return value end
  function state:set(v)counts.set=counts.set+1;value=v end
  function state:hasEventSubscriptions()counts.checks=counts.checks+1;return next(subscriptions)~=nil end
  function state:subscribeToEvent(event)
    counts.subscribe=counts.subscribe+1;subscriptions[event]=true
  end
  return state,counts,function()return value end,subscriptions
end
local S=loadScript()
local initial={schemaVersion=2,revision=17,lines={['1']={name='线路',shortName='T1',displayMode='TRAM',autoBus=false}},
  stationLinks={['10:11']={a={id=10,name='火车站'},b={id=11,name='公交站'}}},
  options={flashNextStop=true},defaults={['1']={name='线路',mode='TRAM',index=1,shortName='T1'}}}
local state,counts,current,subscriptions=savedState(initial,{})
for i=1,10000 do S.update({},state,i%2==0 and 0 or 0.05)end
print(string.format('10,000 updates: subscribe=%d get=%d set=%d checks=%d',
  counts.subscribe,counts.get,counts.set,counts.checks))
assert(counts.subscribe==5,'idle simulation must not keep calling subscription write APIs')
assert(counts.get==0 and counts.set==0 and current()==initial,
  'paused/running idle updates leave the saved config untouched, without copying it')
for _,event in ipairs(events)do assert(subscriptions[event],'all settings actions still receive events')end
-- A load/upgrade can start with an older, incomplete subscription set.
local restored=loadScript()
local saved,restoredCounts,restoredValue,restoredSubscriptions=savedState(initial,{[events[1]]=true})
restored.update({},saved,0)
for _,event in ipairs(events)do assert(restoredSubscriptions[event],'upgrade restores '..event)end
restored.update({},saved,0.05)
assert(restoredCounts.subscribe==5 and restoredValue()==initial,
  'repair older subscriptions once on script load, without rewriting user configuration')
-- Engine removal/recreation must work even when the same Lua module survives.
local fresh,freshCounts=savedState({},{});S.update({},fresh,0);S.update({},fresh,0.05)
assert(freshCounts.subscribe==5,'an empty new state must not inherit a Lua-global ready flag')
-- Re-applying identical settings must not dirty the save or invalidate the HUD.
local before=counts.set
S.handleEvent({},state,'','linnan.bulb.aliases',events[1],
  {lineId=1,name='线路',shortName='T1',displayMode='TRAM'})
S.handleEvent({},state,'','linnan.bulb.aliases',events[3],
  {a={id=11,name='公交站'},b={id=10,name='火车站'},remove=false})
assert(counts.set==before and current()==initial,'identical alias/link commands must perform zero state writes')
S.handleEvent({},state,'','linnan.bulb.aliases',events[1],
  {lineId=1,name='线路',shortName='T2',displayMode='TRAM'})
assert(counts.set==before+1 and current().revision==18 and current().lines['1'].shortName=='T2',
  'an actual edit writes once and retains stable revision semantics')
assert(current().stationLinks==initial.stationLinks and current().options==initial.options
  and current().defaults==initial.defaults,'edits preserve the other saved features')
local bus={enabled=true,format='code_table',expressCode='51',
  districts={['100']={name='杭州',code='10'}},targets={}}
S.handleEvent({},state,'','linnan.bulb.aliases',events[2],bus)
local configured=current();local writes=counts.set
S.handleEvent({},state,'','linnan.bulb.aliases',events[2],bus)
assert(counts.set==writes and current()==configured,'re-applying the bus prefix table must not write a new revision')
S.handleEvent({},state,'','linnan.bulb.aliases',events[3],
  {a={id=10,name='火车站'},b={id=11,name='公交站'},remove=true})
local removed=current();writes=counts.set
S.handleEvent({},state,'','linnan.bulb.aliases',events[3],
  {a={id=10,name='火车站'},b={id=11,name='公交站'},remove=true})
assert(counts.set==writes and current()==removed,'removing an already removed link must not dirty the save')
print('PASS: idle subscription budget, restored/fresh state initialization, no-op save writes, real edits')
