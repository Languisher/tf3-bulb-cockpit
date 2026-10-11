local base='mod/content/gui/bulb_cockpit/'
local P=dofile(base..'native_model.lua');local A=dofile(base..'aliases.lua')
local env=setmetatable({},{__index=_G})
assert(loadfile('mod/content/game_mechanics/bulb_aliases/bulb_aliases.script.lua','t',env))()
local S=env.data();local value={};local sends=0
local state={get=function()return value end,set=function(_,v)value=v end,subscribeToEvent=function()end}
api={type={ComponentType={GAME_SCRIPT=1}},engine={system={gameScriptSystem={getEntityForGameScript=function()return 1 end}},
  getComponent=function()return {state=value}end},cmd={
    makeScriptingSendEventCmd=function(src,id,name,param)return {src=src,id=id,name=name,param=param}end,
    sendCommand=function(cmd,callback)
      sends=sends+1;S.handleEvent({},state,cmd.src,cmd.id,cmd.name,cmd.param);if callback then callback(cmd,true)end
    end}}
local rail={id=40,name='铁路',mode='TRAIN'};local tram={id=30,name='电车',mode='TRAM'}
local confirmed=false
A.saveDefaults(P.pendingDefaults({rail,tram},A.read()),function(_,ok)confirmed=ok end)
assert(confirmed,'default label persistence confirms completion without polling saved state')
local aliases=A.read();assert(aliases.__defaults['40'].shortName=='A' and aliases.__defaults['30'].shortName=='T1')
local lowerRail={id=10,name='另一条铁路',mode='TRAIN'}
A.saveDefaults(P.pendingDefaults({lowerRail},aliases));aliases=A.read()
assert(P.alias(rail,aliases,P.defaults({rail},aliases))=='A','unrelated lower IDs cannot renumber a known route')
assert(P.alias(lowerRail,aliases,P.defaults({lowerRail},aliases))=='B')
local ordered=P.defaults({lowerRail,rail,tram,{id=5,name='新电车',mode='TRAM'}},aliases)
assert(ordered['30'].shortName=='T1' and ordered['5'].shortName=='T2','explicit full settings list preserves saved assignments')
rail.name='改名铁路';A.saveDefaults(P.pendingDefaults({rail},aliases));aliases=A.read()
assert(aliases.__defaults['40'].shortName=='A','main line rename preserves its reserved number')
local before=sends;A.saveDefaults(P.pendingDefaults({rail,lowerRail,tram},aliases));assert(sends==before,'unchanged assignments send no event')
local revision=value.revision
S.handleEvent({},state,'',A.id,A.defaultsEvent,{defaults=aliases.__defaults})
assert(value.revision==revision,'no-op merge cannot invalidate UI configuration')
-- Resolve commands composed against the same older revision without duplicate labels.
S.handleEvent({},state,'',A.id,A.defaultsEvent,{defaults={['15']={name='race',mode='RER',index=2,shortName='B'}}})
assert(value.defaults['15'].shortName=='C','simulation state resolves conflicting reserved indices')
A.saveOptions({flashNextStop=true},function(_,ok)assert(ok)end)
assert(A.read().__options.flashNextStop and value.defaults['40'].shortName=='A')
A.save(rail,'RE9',function()end,'RER',{prefix='RE',identifier='9',suffix=''})
assert(A.read().__options.flashNextStop and A.read().__defaults['40'].shortName=='A','alias writes preserve options/defaults')
A.saveStationLink({id=100,name='火车站'},{id=101,name='公交站'},false,function()end)
assert(A.read().__options.flashNextStop and A.read().__defaults['40'].shortName=='A','station writes preserve options/defaults')
A.saveOptions({flashNextStop=false},function()end)
assert(not A.read().__options.flashNextStop and A.read().__stationLinks['100:101'],'options preserve associations')
local old=value
S.handleEvent({},state,'',A.id,A.optionsEvent,{flashNextStop='true'});assert(value==old)
S.handleEvent({},state,'',A.id,A.defaultsEvent,{defaults={bad={name='bad',mode='RER',index=1}}});assert(value==old)
-- Bus indices and local city classification persist and can be used without other routes.
local config={enabled=true,format='code_table',expressCode='51',districts={['100']={name='杭州',code='10'}}}
local buses={{id=60,name='市内甲',mode='BUS',busScope='local',towns={{id=100,name='杭州'}},routeKey='1,2'},
  {id=61,name='市内乙',mode='BUS',busScope='local',towns={{id=100,name='杭州'}},routeKey='2,1'}}
local candidate=A.read();candidate.__busNaming=config
A.saveBusNaming(config,buses,function()end,P.defaults(buses,candidate));aliases=A.read()
assert(aliases.__defaults['60'].shortName=='1001' and aliases.__defaults['61'].shortName=='1002')
assert(P.alias({id=61,name='市内乙',mode='BUS'},aliases,P.defaults({{id=61,name='市内乙',mode='BUS'}},aliases))=='1002')
local newBus={id=8,name='新增公交',mode='BUS',busScope='local',towns={{id=100,name='杭州'}},routeKey='1,2'}
A.saveDefaults(P.pendingDefaults({newBus},aliases));aliases=A.read()
assert(aliases.__defaults['8'].shortName=='1003','newly encountered buses append without renumbering existing ones')
assert(aliases.__options.flashNextStop==false and aliases.__stationLinks['100:101'],'batch naming preserves options and links')
print('PASS: saved stable local label allocation, concurrent merge, no-op events, options persistence/validation, all-feature state preservation, incremental bus naming')
