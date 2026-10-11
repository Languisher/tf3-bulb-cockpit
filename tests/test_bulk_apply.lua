local A=dofile('mod/content/gui/bulb_cockpit/aliases.lua')
local env=setmetatable({},{__index=_G})
assert(loadfile('mod/content/game_mechanics/bulb_aliases/bulb_aliases.script.lua','t',env))()
local S=env.data()
local original={revision=7,lines={['9']={name='未编辑线路',shortName='9'}},
  options={flashNextStop=true},stationLinks={keep=true},busNaming={enabled=false}}
local value,writes,commands=original,0,{}
local state={get=function()return value end,set=function(_,v)value=v;writes=writes+1 end}
api={type={ComponentType={GAME_SCRIPT=1}},engine={system={gameScriptSystem={getEntityForGameScript=function()return 1 end}},
  getComponent=function()return {state=value}end},cmd={
  makeScriptingSendEventCmd=function(src,id,name,param)return {src=src,id=id,name=name,param=param}end,
  sendCommand=function(cmd,callback)commands[#commands+1]={cmd=cmd,callback=callback}end}}
local changes={
  {line={id=1,name='电车甲'},shortName='T1',displayMode='TRAM',parts={prefix='T',identifier='1',suffix=''}},
  {line={id=2,name='铁路乙'},shortName='A',displayMode='RER',parts={prefix='',identifier='',suffix=''}},
}
local defaults={['2']={name='铁路乙',mode='RER',index=1,shortName='A'}}
local acknowledged=false
A.saveAll(changes,function(_,success)acknowledged=success end,defaults)
assert(#commands==1 and writes==0 and not acknowledged,'one bulk command waits for the simulation')
local pending=commands[1];local cmd=pending.cmd
S.handleEvent({},state,cmd.src,cmd.id,cmd.name,cmd.param);pending.callback(nil,true)
assert(acknowledged and writes==1 and value.revision==8,'one atomic state write for the entire batch')
local fresh=dofile('mod/content/gui/bulb_cockpit/aliases.lua').read()
assert(fresh['1'].prefix=='T' and fresh['1'].identifier=='1' and fresh['2'].identifier=='')
assert(fresh.__defaults['2'].shortName=='A','automatic assignments survive a fresh GUI load')
assert(value.lines['9']==original.lines['9'] and value.options==original.options
  and value.stationLinks==original.stationLinks and value.busNaming==original.busNaming,
  'bulk apply preserves unrelated configuration')
local applied=value
S.handleEvent({},state,cmd.src,cmd.id,cmd.name,cmd.param)
assert(writes==1 and value==applied,'identical batch is a no-op')
local invalid={entries={cmd.param.entries[1],{lineId=2,name='铁路乙',shortName='bad',prefix='',identifier='错误',suffix=''}},defaults=defaults}
S.handleEvent({},state,'',A.id,A.event,invalid)
assert(value==applied and writes==1,'invalid second row cannot partially apply the first')
assert(not pcall(A.saveAll,{
  changes[1],{line={id=2,name='铁路乙'},shortName='bad',parts={prefix='',identifier='1-2',suffix=''}}
},function()end),'reject the entire invalid batch before sending it')
assert(#commands==1)
local conflicting={lineId=1,name='电车甲',shortName='T999',prefix='T',identifier='999',suffix=''}
local duplicate={entries={cmd.param.entries[1],conflicting}}
S.handleEvent({},state,'',A.id,A.event,duplicate)
assert(value==applied,'duplicate line IDs must not introduce ambiguous writes')
print('PASS: atomic bulk apply, persistence, no-op writes, invalid-batch isolation and unrelated state preservation')
