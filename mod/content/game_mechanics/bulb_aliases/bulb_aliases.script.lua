local S={}
local languages={en=true,zh=true,['zh-tw']=true,fr=true,de=true,es=true,it=true,['pt-br']=true,ru=true,pl=true,tr=true,uk=true,ja=true,ko=true}
local presetModes={TRAIN=true,RER=true,METRO=true,TRAM=true,BUS=true,BOAT=true,AIR=true,TRUCK=true,FREIGHT_TRAIN=true}
local presetNames={default=true,paris=true,shanghai=true,munich=true}
local function validPresets(value)
  if type(value)~='table' or not next(value)then return false end
  for mode,name in pairs(value)do if not presetModes[mode] or not presetNames[name]then return false end end
  return true
end
local EVENT='linnan.bulb.setAlias'
local BUS_EVENT='linnan.bulb.setBusNaming'
local STATION_EVENT='linnan.bulb.setStationLink'
local OPTIONS_EVENT='linnan.bulb.setOptions'
local DEFAULTS_EVENT='linnan.bulb.setDefaults'
local modes={['']=true,RER=true,METRO=true,TRAIN=true,TRAM=true,BUS=true,BOAT=true,AIR=true,TRUCK=true,FREIGHT_TRAIN=true}
-- Re-register once when the Lua script loads, including newly added events
-- absent from older saves. Afterwards only check the engine's read-only flag.
local subscriptionsInitialized=false
local function equal(a,b)
  if type(a)~=type(b)then return false end
  if type(a)~='table'then return a==b end
  for k,v in pairs(a)do if not equal(v,b[k])then return false end end
  for k in pairs(b)do if a[k]==nil then return false end end
  return true
end
local function replace(state,patch)
  local old=state:get() or {};local changed=false
  for k,v in pairs(patch)do
    if not equal(old[k],v)then changed=true;break end
  end
  if not changed then return end
  local nextState={}
  for k,v in pairs(old)do nextState[k]=v end
  for k,v in pairs(patch)do nextState[k]=v end
  nextState.schemaVersion=2;nextState.revision=(old.revision or 0)+1
  state:set(nextState)
end
local function letter(index)
  local result=''
  repeat index=index-1;result=string.char(65+index%26)..result;index=math.floor(index/26)until index==0
  return result
end
local function mergeDefaults(old,input,configured)
  if type(input)~='table'then return nil end
  local rows={}
  for id,v in pairs(input)do
    if type(id)~='string' or not id:match('^%d+$') or type(v)~='table' or type(v.name)~='string'
      or not({TRAIN=true,RER=true,TRAM=true,METRO=true,BUS=true,FREIGHT_TRAIN=true})[v.mode] or type(v.index)~='number'
      or v.index<1 or v.index%1~=0 or v.index>1000000
      or (v.railTypesVersion~=nil and v.railTypesVersion~=2)then return nil end
    if v.mode=='BUS'then
      if v.busAuto~=true or type(v.code)~='string' or not v.code:match('^%d+$')
        or type(v.busKey)~='string' or not(v.busKey=='express' or v.busKey:match('^town:%d+$'))
        or type(v.towns)~='table' or not({local_=true,express=true})[v.busScope=='local' and 'local_' or v.busScope]
        or (v.routeKey~=nil and type(v.routeKey)~='string')then return nil end
      for _,town in ipairs(v.towns)do
        if type(town)~='table' or type(town.id)~='number' or town.id<0 or town.id%1~=0
          or type(town.name)~='string'then return nil end
      end
    end
    rows[#rows+1]={id=id,value=v}
  end
  table.sort(rows,function(a,b)return tonumber(a.id)<tonumber(b.id)end)
  local defaults,used,counts={},{},{}
  local function category(v)return v.busAuto and v.busKey or v.mode end
  local function reserve(v,id)
    local key=category(v);used[key]=used[key] or {};used[key][v.index]=id
    counts[key]=math.max(counts[key] or 0,v.index)
  end
  for id,v in pairs(old or {})do
    local choice=configured and configured[id]
    if (v.mode=='TRAIN' or v.mode=='RER') and v.railTypesVersion~=2 then
      local copy={};for key,value in pairs(v)do copy[key]=value end
      if v.mode=='RER' and not(choice and choice.name==v.name and choice.displayMode=='RER')then copy.mode='TRAIN'end
      copy.railTypesVersion=2;v=copy
    end
    defaults[id]=v;reserve(v,id)
  end
  for _,row in ipairs(rows)do
    local id,v=row.id,row.value;local previous=defaults[id]
    local key=category(v);local index=v.index
    if previous and category(previous)==key then index=previous.index end
    if used[key] and used[key][index] and used[key][index]~=id then index=(counts[key] or 0)+1 end
    local entry={name=v.name,mode=v.mode,index=index,railTypesVersion=(v.mode=='TRAIN' or v.mode=='RER') and 2 or nil}
    if v.busAuto then
      entry.code=v.code;entry.busKey=v.busKey;entry.busAuto=true
      entry.prefix='';entry.suffix='';entry.identifier=v.code..string.format('%02d',index)
      entry.shortName=entry.identifier;entry.busScope=v.busScope;entry.routeKey=v.routeKey
      entry.towns={};for i,town in ipairs(v.towns)do entry.towns[i]={id=town.id,name=town.name}end
    else entry.shortName=v.mode=='FREIGHT_TRAIN' and tostring(72000+index) or (v.mode=='TRAIN' or v.mode=='RER') and letter(index) or (v.mode=='TRAM' and 'T' or '')..index end
    defaults[id]=entry;reserve(entry,id)
  end
  return defaults,not equal(old or {},defaults)
end
local function aliasEntry(param,previous)
  if type(param)~='table' or type(param.lineId)~='number' or param.lineId<0 or param.lineId%1~=0
    or type(param.name)~='string' or type(param.shortName)~='string' then return nil end
  if param.displayMode~=nil and not modes[param.displayMode] then return nil end
  local structured=param.prefix~=nil or param.identifier~=nil or param.suffix~=nil
  if structured and (type(param.prefix)~='string' or type(param.identifier)~='string'
    or type(param.suffix)~='string' or not param.identifier:match('^%s*[A-Za-z0-9]*%s*$'))then return nil end
  local displayMode=param.displayMode
  if displayMode==nil then displayMode=previous and previous.name==param.name and previous.displayMode or '' end
  local entry={name=param.name,shortName=param.shortName:match('^%s*(.-)%s*$'),displayMode=displayMode,autoBus=false}
  if structured then
    entry.prefix=param.prefix:gsub('[\r\n]','')
    entry.identifier=param.identifier:match('^%s*(.-)%s*$')
    entry.suffix=param.suffix:gsub('[\r\n]','')
  end
  return entry
end
function S.update(_,state)
  if subscriptionsInitialized and state:hasEventSubscriptions()then return end
  state:subscribeToEvent(EVENT)
  state:subscribeToEvent(BUS_EVENT)
  state:subscribeToEvent(STATION_EVENT)
  state:subscribeToEvent(OPTIONS_EVENT)
  state:subscribeToEvent(DEFAULTS_EVENT)
  subscriptionsInitialized=true
end
function S.handleEvent(_,state,_,id,name,param)
  if id=='linnan.bulb.aliases' and name==OPTIONS_EVENT then
    if type(param)~='table'
      or (param.flashNextStop~=nil and type(param.flashNextStop)~='boolean')
      or (param.language~=nil and languages[param.language]~=true)
      or (param.routeMapScale~=nil and (type(param.routeMapScale)~='number' or param.routeMapScale<10
        or param.routeMapScale>400 or param.routeMapScale%1~=0))
      or (param.linePresets~=nil and not validPresets(param.linePresets))then return end
    if param.flashNextStop==nil and param.language==nil and param.routeMapScale==nil and param.linePresets==nil then return end
    local old=state:get() or {}
    local options={};for k,v in pairs(old.options or {})do options[k]=v end
    -- Option commands are patches: language and blinking must never reset
    -- each other, including commands acknowledged after another UI edit.
    if param.flashNextStop~=nil then options.flashNextStop=param.flashNextStop end
    if param.language~=nil then options.language=param.language end
    if param.routeMapScale~=nil then options.routeMapScale=param.routeMapScale end
    if param.linePresets then
      local selections={};for k,v in pairs(options.linePresets or {})do selections[k]=v end
      for k,v in pairs(param.linePresets)do selections[k]=v end
      options.linePresets=selections
    end
    replace(state,{options=options})
    return
  end
  if id=='linnan.bulb.aliases' and name==DEFAULTS_EVENT then
    local old=state:get() or {}
    local defaults,changed=mergeDefaults(old.defaults,type(param)=='table' and param.defaults,old.lines)
    if defaults and changed then replace(state,{defaults=defaults})end
    return
  end
  if id=='linnan.bulb.aliases' and name==STATION_EVENT then
    local function valid(station)
      return type(station)=='table' and type(station.id)=='number' and station.id>=0
        and station.id%1==0 and type(station.name)=='string'
    end
    if type(param)~='table' or not valid(param.a) or not valid(param.b)
      or param.a.id==param.b.id or type(param.remove)~='boolean'then return end
    local a,b=param.a,param.b
    if a.id>b.id then a,b=b,a end
    local key=string.format('%.0f:%.0f',a.id,b.id)
    local old=state:get() or {};local links={}
    for k,v in pairs(old.stationLinks or {})do links[k]=v end
    if param.remove then links[key]=nil
    else links[key]={a={id=a.id,name=a.name},b={id=b.id,name=b.name}}end
    -- Update only this edge, so another settings action cannot overwrite
    -- concurrent station links, line aliases or the bus prefix table.
    replace(state,{lines=old.lines or {},stationLinks=links})
    return
  end
  if id=='linnan.bulb.aliases' and name==BUS_EVENT then
    if type(param)~='table' or type(param.enabled)~='boolean' or type(param.districts)~='table'
      or type(param.targets)~='table'then return end
    local mapped=param.format=='code_table'
    if param.format~=nil and not mapped then return end
    local used={}
    if mapped then
      if type(param.expressCode)~='string' or not param.expressCode:match('^%d*$')then return end
      if param.expressCode~=''then used[param.expressCode]=true end
    end
    local districts={}
    for key,district in pairs(param.districts)do
      if type(key)~='string' or not key:match('^%d+$') or type(district)~='table'
        or type(district.name)~='string' or type(district.code)~='string'then return end
      if mapped then
        if not district.code:match('^%d*$') or (district.code~='' and used[district.code])then return end
        if district.code~=''then used[district.code]=true end
      end
      districts[key]={name=district.name,code=district.code:gsub('[\r\n]','')}
    end
    for _,target in ipairs(param.targets)do
      if type(target)~='table' or type(target.id)~='number' or target.id<0 or target.id%1~=0
        or type(target.name)~='string'then return end
    end
    local old=state:get() or {};local lines={};local input={}
    for _,target in ipairs(param.targets)do
      if target.default then input[tostring(target.id)]=target.default end
    end
    local defaults=mergeDefaults(old.defaults,input,old.lines)
    if not defaults then return end
    for k,v in pairs(old.lines or {})do lines[k]=v end
    if param.enabled then
      for _,target in ipairs(param.targets)do
        local previous=lines[tostring(target.id)];local entry={name=target.name,shortName='',displayMode=''}
        if previous and previous.name==target.name then for k,v in pairs(previous)do entry[k]=v end end
        entry.autoBus=true;lines[tostring(target.id)]=entry
      end
    end
    replace(state,{lines=lines,defaults=defaults,busNaming={enabled=param.enabled,districts=districts,format=param.format,expressCode=param.expressCode}})
    return
  end
  if id~='linnan.bulb.aliases' or name~=EVENT then return end
  if type(param)~='table'then return end
  local old=state:get() or {}
  local lines={}
  for k,v in pairs(old.lines or {}) do lines[k]=v end
  if param.entries~=nil then
    if type(param.entries)~='table' or #param.entries==0 then return end
    local seen={}
    for _,value in ipairs(param.entries)do
      local entry=aliasEntry(value,lines[tostring(type(value)=='table' and value.lineId)])
      if not entry or seen[value.lineId]then return end
      seen[value.lineId]=true;lines[tostring(value.lineId)]=entry
    end
    local patch={lines=lines}
    if param.defaults~=nil then
      patch.defaults=mergeDefaults(old.defaults,param.defaults,lines)
      if not patch.defaults then return end
    end
    replace(state,patch)
  else
    local entry=aliasEntry(param,lines[tostring(param.lineId)])
    if not entry then return end
    lines[tostring(param.lineId)]=entry
    replace(state,{lines=lines})
  end
end
-- Lua script resources expose callbacks through data(), like the base game.
function data()
  return S
end
