local I=dofile('mod/content/gui/bulb_cockpit/localization.lua')
assert(I.language()=='en' and I.language({})=='en'
  and I.language({__options={language='unknown'}})=='en','unset or invalid language defaults to English')
assert(I.bind({})('线路图设置')=='Route maps','first load uses English without writing a preference')
local en=I.bind({__options={language='en'}})
local zh=I.bind({__options={language='zh'}})
assert(en('线路设置')=='Line settings' and zh('线路设置')=='线路设置')
assert(en('已应用 %d 条修改，请保存游戏。',3)=='Applied 3 changes. Please save your game.')
assert(en('杭州站')=='杭州站' and en('T1支线')=='T1支线','game data remains literal')
assert(zh('… %d站',4)=='… 4站' and en('… %d站',4)=='… 4 stops')
assert(en('线路设置')=='Line settings','another bound language cannot change an existing translator')
for source,target in pairs(I.english)do
  assert(not target:find('[\228-\233][\128-\191][\128-\191]'),'English entry contains Chinese: '..source)
  local function formats(s)
    local out={};for spec in s:gmatch('%%[ds]')do out[#out+1]=spec end
    return table.concat(out)
  end
  assert(formats(source)==formats(target),'format placeholders differ: '..source)
end
-- Every controlled Chinese translation key used by UI/model has an English entry.
for _,name in ipairs({'settings.lua','city_settings.lua','station_settings.lua','install.script.lua','native_model.lua'})do
  local file=assert(io.open('mod/content/gui/bulb_cockpit/'..name));local source=file:read('*a');file:close()
  for key in source:gmatch("tr%('([^']+)'")do
    if key:find('[\228-\233][\128-\191][\128-\191]')then assert(I.english[key],name..': missing translation '..key)end
  end
end
local env=setmetatable({},{__index=_G})
assert(loadfile('mod/content/game_mechanics/bulb_aliases/bulb_aliases.script.lua','t',env))()
local S=env.data()
local value={lines={['10']={name='杭州',shortName='T1'}},options={flashNextStop=true,other=true},revision=2}
local writes=0
local state={get=function()return value end,set=function(_,v)value=v;writes=writes+1 end}
local A=dofile('mod/content/gui/bulb_cockpit/aliases.lua')
api={type={ComponentType={GAME_SCRIPT=1}},engine={
  system={gameScriptSystem={getEntityForGameScript=function()return 1 end}},
  getComponent=function()return {state=value}end},cmd={
  makeScriptingSendEventCmd=function(_,id,name,param)return {id=id,name=name,param=param}end,
  sendCommand=function(cmd,callback)S.handleEvent({},state,'',cmd.id,cmd.name,cmd.param);callback(nil,true)end}}
A.saveOptions({language='en'},function(_,ok)assert(ok)end)
assert(writes==1 and value.options.language=='en' and value.options.flashNextStop and value.options.other)
A.saveOptions({flashNextStop=false},function()end)
assert(writes==2 and not value.options.flashNextStop and value.options.language=='en')
assert(dofile('mod/content/gui/bulb_cockpit/aliases.lua').read().__options.language=='en','fresh GUI reads saved language')
A.saveOptions({language='en'},function()end)
assert(writes==2,'unchanged language performs no state write')
local before=value
for _,patch in ipairs({{language='fr'},{language=false},{flashNextStop='false'},
  {language='zh',flashNextStop='bad'},{unknown=true}})do
  assert(not pcall(A.saveOptions,patch,function()end),'GUI rejects invalid patch')
  S.handleEvent({},state,'',A.id,A.optionsEvent,patch)
  assert(value==before,'invalid event cannot partially apply options')
end
A.saveOptions({language='zh',flashNextStop=true},function()end)
assert(value.options.language=='zh' and value.options.flashNextStop and value.lines['10'].shortName=='T1')
print('Localization dictionary and saved option patches pass')
