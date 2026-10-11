local function resource(path)
  local env=setmetatable({},{__index=_G})
  assert(loadfile(path,'t',env))()
  assert(type(env.data)=='function','Lua resources must expose data()')
  return env.data()
end
local S=resource('mod/content/game_mechanics/bulb_aliases/bulb_aliases.script.lua')
local definition=resource('mod/content/game_mechanics/bulb_aliases/bulb_aliases.gs.lua')
for _,slot in ipairs({'updateScript','handleEventScript'}) do
  local filename,callback=definition[slot].fileName:match('^(.-)@(.+)$')
  assert(filename=='bulb_aliases.script' and type(S[callback])=='function',
    'resource callback references must resolve through data()')
end
local A=dofile('mod/content/gui/bulb_cockpit/aliases.lua')
local value,subscribed={},{}
local state={get=function()return value end,set=function(_,v)value=v end,
  subscribeToEvent=function(_,event)subscribed[event]=true end}
local commands={}
local entity=80
api={type={ComponentType={GAME_SCRIPT='GAME_SCRIPT'}},engine={
  system={gameScriptSystem={getEntityForGameScript=function(path)assert(path==A.script);return entity end}},
  getComponent=function(id,kind)assert(id==80 and kind=='GAME_SCRIPT');return {state=value}end},cmd={
  makeScriptingSendEventCmd=function(src,id,name,param)return {src=src,id=id,name=name,param=param}end,
  sendCommand=function(command,callback)commands[#commands+1]={command=command,callback=callback}end}}
S.update({},state,0)
assert(subscribed[A.event],'subscribe even while paused')
local aliases,rev=A.read();assert(next(aliases)==nil and rev==0)
local unchanged,revision=A.read(rev)
assert(unchanged==nil and revision==rev,'unchanged revision skips configuration reconstruction')
local confirmed=false
A.save({id=10,name='tram 乘客-杭州-LO-1'},'  T1  ',function(_,success)confirmed=success end)
assert(not confirmed and next(value)==nil,'wait for the simulation command before confirming')
local pending=commands[1]
local cmd=pending.command
S.handleEvent({},state,cmd.src,cmd.id,cmd.name,cmd.param)
pending.callback(cmd,true)
aliases,rev=A.read()
assert(confirmed and aliases['10'].shortName=='T1' and rev==1)
S.handleEvent({},state,'','other',A.event,{lineId=10,name='wrong',shortName='bad'})
S.handleEvent({},state,'',A.id,A.event,{lineId=20,name='公交-1001',shortName='1001'})
assert(value.lines['10'].shortName=='T1' and value.lines['20'].shortName=='1001' and value.revision==2,
  'merge separate line changes without replacing other configuration')
-- A fresh GUI module reads the state that the game stores on its script entity.
local reloaded=dofile('mod/content/gui/bulb_cockpit/aliases.lua')
assert(reloaded.read()['20'].shortName=='1001','reload from saved script state, not a GUI-local cache')
S.handleEvent({},state,'',A.id,A.event,{lineId=20,name='公交-1001',shortName=''})
assert(reloaded.read()['20'].shortName=='','clearing an alias survives reload')
local last=commands[#commands]
A.save({id=20,name='公交-1001'},'1001',function()end,'METRO')
last=commands[#commands].command
S.handleEvent({},state,last.src,last.id,last.name,last.param)
assert(reloaded.read()['20'].displayMode=='METRO','persist the mode override with the alias')
S.handleEvent({},state,'',A.id,A.event,{lineId=20,name='公交-1001',shortName='M1'})
assert(reloaded.read()['20'].displayMode=='METRO','legacy alias-only updates preserve the selected mode')
S.handleEvent({},state,'',A.id,A.event,{lineId=20,name='公交-1001',shortName='1001',displayMode=''})
assert(reloaded.read()['20'].displayMode=='','automatic mode can be restored')
local before=value
S.handleEvent({},state,'',A.id,A.event,{lineId='../../invalid',name='bad',shortName='bad'})
assert(value==before,'reject malformed events')
S.handleEvent({},state,'',A.id,A.event,{lineId=20,name='公交-1001',shortName='1001',displayMode='invalid'})
assert(value==before,'reject unknown display modes')
for _,actual in ipairs({'TRAIN','TRAM'}) do
  local line={id=actual=='TRAIN' and 100 or 101,name=actual..' 可配置线路'}
  for _,choice in ipairs({'RER','METRO','TRAM'}) do
    A.save(line,'',function()end,choice)
    local command=commands[#commands].command
    S.handleEvent({},state,command.src,command.id,command.name,command.param)
    local stored=reloaded.read()[tostring(line.id)]
    assert(stored and stored.displayMode==choice and stored.shortName=='',
      'persist '..actual..' as '..choice..' with automatic numbering')
  end
end
local formatted={prefix='T',identifier='3',suffix='b'}
A.save({id=10,name='tram 乘客-杭州-LO-1'},'T3b',function()end,'TRAM',formatted)
local command=commands[#commands].command
S.handleEvent({},state,command.src,command.id,command.name,command.param)
local entry=reloaded.read()['10']
assert(entry.prefix=='T' and entry.identifier=='3' and entry.suffix=='b' and entry.shortName=='T3b',
  'all three fields survive command, simulation state and fresh GUI read')
assert(value.schemaVersion==2)
A.save({id=20,name='公交-1001'},'快 1001 支线',function()end,'BUS',
  {prefix='快 ',identifier='',suffix=' 支线'})
command=commands[#commands].command
S.handleEvent({},state,command.src,command.id,command.name,command.param)
entry=reloaded.read()['20']
assert(entry.prefix=='快 ' and entry.identifier=='' and entry.suffix==' 支线',
  'keep literal separators and an automatic center across reload')
local untouched=value
for _,invalid in ipairs({{prefix='T',identifier='1-2',suffix=''},
  {prefix='T',identifier='中文',suffix=''}, {prefix='T',identifier={},suffix=''},
  {prefix='T',identifier='1'}})do
  local param={lineId=10,name='tram 乘客-杭州-LO-1',shortName='bad',displayMode='TRAM'}
  for k,v in pairs(invalid)do param[k]=v end
  S.handleEvent({},state,'',A.id,A.event,param)
  assert(value==untouched,'malformed structured events cannot corrupt previous configuration')
end
assert(not pcall(A.save,{id=10,name='line'},'bad',function()end,'TRAM',
  {prefix='',identifier='1-2',suffix=''}),'GUI boundary rejects an invalid center')
S.handleEvent({},state,'',A.id,A.event,{lineId=10,name='tram 乘客-杭州-LO-1',shortName='T7'})
assert(reloaded.read()['10'].shortName=='T7' and reloaded.read()['10'].identifier==nil,
  'legacy alias-only write replaces structured override rather than leaving a stale code')
entity=-1
assert(A.read()==nil)
assert(not pcall(A.save,{id=10,name='line'},'T1',function()end),'do not silently save before script initialization')
print('PASS: native script-state alias write, confirmation, merge, reload and clear')
