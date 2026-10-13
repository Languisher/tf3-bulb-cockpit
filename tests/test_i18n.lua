local I=dofile('mod/content/gui/bulb_cockpit/localization.lua')
assert(#I.locales==14,'offer all 14 shipped languages')
ug_require=function(path)
  local name=assert(path:match('/locales/([%w-]+)%.lua$'),path)
  return dofile('mod/content/gui/bulb_cockpit/locales/'..name..'.lua')
end
local function formats(s)
  local out={};for spec in s:gmatch('%%[ds]')do out[#out+1]=spec end
  return table.concat(out)
end
local names={}
for index,locale in ipairs(I.locales)do
  assert(not names[locale.code] and I.index(locale.code)==index)
  names[locale.code]=true
  local config={__options={language=locale.code}}
  local tr=I.bind(config)
  assert(I.language(config)==locale.code)
  for key,en in pairs(I.english)do
    local value=tr(key)
    assert(type(value)=='string' and value~='')
    assert(formats(key)==formats(value),locale.code..': invalid placeholders for '..key)
    if locale.code~='zh' then
      local catalog=locale.code=='en' and I.english or I.catalog(locale.code)
      assert(catalog[key],locale.code..': missing key '..key)
    end
  end
  assert(tr('站名杭州 T1')=='站名杭州 T1','user data must remain literal')
  config.__options.language='en'
  assert(tr('语言')~='', 'bound translators remain usable after changing preferences')
end
assert(I.language({__options={language='EN-us'}})=='en')
assert(I.language({__options={language='zh-CN'}})=='zh')
assert(I.language({__options={language='zh-Hant'}})=='zh-tw')
assert(I.language({__options={language='pt_BR'}})=='pt-br')
assert(I.language({__options={language='xx'}})=='en')
local en=I.bind({})
local fr=I.catalog('fr');local old=fr['语言'];fr['语言']=nil
assert(I.bind({__options={language='fr'}})('语言')==en('语言'),'missing translations fall back to English')
fr['语言']=old
-- The GUI and simulation must accept every selectable code, preserving other options.
local env=setmetatable({},{__index=_G})
assert(loadfile('mod/content/game_mechanics/bulb_aliases/bulb_aliases.script.lua','t',env))()
local script=env.data()
local value={options={flashNextStop=true},lines={}}
local state={get=function()return value end,set=function(_,v)value=v end}
api={type={ComponentType={GAME_SCRIPT=1}},engine={system={gameScriptSystem={getEntityForGameScript=function()return 1 end}},
  getComponent=function()return {state=value}end},cmd={makeScriptingSendEventCmd=function(_,id,name,param)return {id=id,name=name,param=param}end,
  sendCommand=function(cmd,callback)script.handleEvent({},state,'',cmd.id,cmd.name,cmd.param);callback(nil,true)end}}
local A=dofile('mod/content/gui/bulb_cockpit/aliases.lua')
for _,locale in ipairs(I.locales)do
  A.saveOptions({language=locale.code},function(_,ok)assert(ok)end)
  assert(value.options.language==locale.code and value.options.flashNextStop)
  assert(I.language(A.read())==locale.code,'saved language survives a fresh read')
end
print('PASS: 14 complete catalogs, format placeholders, locale aliases, English fallback and saved GUI/simulation options')
