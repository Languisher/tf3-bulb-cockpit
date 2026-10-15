local V=dofile('mod/content/gui/bulb_cockpit/presets.lua')
local game='#123456'
local function config(mode,preset)return {__options={linePresets={[mode]=preset}}}end
assert(V.resolve('METRO','1',game,{}).color==game)
for i=1,18 do assert(V.resolve('METRO',tostring(i),game,config('METRO','paris')).matched)end
assert(V.resolve('METRO','1',game,config('METRO','paris')).color=='#ffcd02')
assert(V.resolve('TRAM','T3b',game,config('TRAM','paris')).color=='#008c5a')
assert(V.resolve('RER','A',game,config('RER','paris')).color=='#ed1c2a')
assert(V.resolve('METRO','1',game,config('METRO','shanghai')).color=='#e3002b')
assert(V.resolve('RER','A',game,config('RER','shanghai')).color==game)
assert(V.resolve('RER','S1',game,config('RER','munich')).color=='#1fbae7')
assert(V.resolve('METRO','U7',game,config('METRO','munich')).secondary=='#c10831')
assert(V.resolve('TRAM','16',game,config('TRAM','munich')).color=='#0065ae')
assert(V.resolve('TRAM','T28',game,config('TRAM','munich')).outline)
assert(V.resolve('METRO','Z99',game,config('METRO','paris')).color==game)
assert(V.resolve('METRO','Custom 1 Express',game,config('METRO','paris'),'1').color=='#ffcd02')
local c={__options={linePresets={METRO='shanghai',RER='munich',TRAM='paris'}}}
assert(V.resolve('METRO','1',game,c).color=='#e3002b' and V.resolve('RER','1',game,c).color=='#1fbae7')
assert(V.resolve('TRAM','T1',game,c).color=='#006db8' and V.resolve('BUS','1',game,c).color==game)
assert(V.valid({METRO='paris',RER='munich'}))
for _,bad in ipairs({false,'paris',{}, {METRO='unknown'},{UNKNOWN='paris'}})do assert(not V.valid(bad))end
print('PASS: independent city palettes, all Paris metro numbers, T3b, Munich S/RER, Shanghai fallback and custom affixes')
-- Saving one type is a nested patch; duplicate saves do not dirty the game.
local env=setmetatable({},{__index=_G})
assert(loadfile('mod/content/game_mechanics/bulb_aliases/bulb_aliases.script.lua','t',env))()
local script=env.data()
local saved={options={language='fr',flashNextStop=true,routeMapScale=175,linePresets={TRAM='paris'}},lines={}}
local writes=0
local state={get=function()return saved end,set=function(_,v)saved=v;writes=writes+1 end}
api={type={ComponentType={GAME_SCRIPT=1}},engine={system={gameScriptSystem={getEntityForGameScript=function()return 1 end}},
  getComponent=function()return {state=saved}end},cmd={makeScriptingSendEventCmd=function(_,id,name,param)return {id=id,name=name,param=param}end,
  sendCommand=function(cmd,callback)script.handleEvent({},state,'',cmd.id,cmd.name,cmd.param);callback(nil,true)end}}
local A=dofile('mod/content/gui/bulb_cockpit/aliases.lua')
A.saveOptions({linePresets={METRO='shanghai'}},function(_,ok)assert(ok)end)
A.saveOptions({linePresets={RER='munich'}},function(_,ok)assert(ok)end)
local options=saved.options
assert(options.linePresets.TRAM=='paris' and options.linePresets.METRO=='shanghai' and options.linePresets.RER=='munich')
assert(options.language=='fr' and options.flashNextStop and options.routeMapScale==175)
local count=writes
A.saveOptions({linePresets={RER='munich'}},function()end)
assert(writes==count,'no-op palette changes must not dirty the save')
for _,bad in ipairs({false,'paris',{}, {METRO='unknown'}, {UNKNOWN='paris'}})do
  local before=saved
  assert(not pcall(A.saveOptions,{linePresets=bad},function()end))
  script.handleEvent({},state,'',A.id,A.optionsEvent,{linePresets=bad,language='zh'})
  assert(saved==before,'an invalid palette patch cannot partially overwrite language')
end
print('PASS: saved nested presets, concurrent option preservation, no-op and atomic validation')
