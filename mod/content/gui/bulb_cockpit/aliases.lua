-- Custom app.saveUserdata directories are rejected by Build 40420.
-- Use the game's saved GAME_SCRIPT state, scoped to the current save.
local A={}
local languages={en=true,zh=true,['zh-tw']=true,fr=true,de=true,es=true,it=true,['pt-br']=true,ru=true,pl=true,tr=true,uk=true,ja=true,ko=true}
A.script='linnan_bulb_cockpit::/game_mechanics/bulb_aliases/bulb_aliases.gs'
A.id='linnan.bulb.aliases'
A.event='linnan.bulb.setAlias'
A.busEvent='linnan.bulb.setBusNaming'
A.stationEvent='linnan.bulb.setStationLink'
A.optionsEvent='linnan.bulb.setOptions'
A.defaultsEvent='linnan.bulb.setDefaults'
function A.read(previousRevision)
  local entity=api.engine.system.gameScriptSystem.getEntityForGameScript(A.script)
  if not entity or entity<0 then return nil end
  local component=api.engine.getComponent(entity,api.type.ComponentType.GAME_SCRIPT)
  local state=component and component.state
  if not state then return nil end
  local revision=state.revision or 0
  if revision==previousRevision then return nil,revision end
  local lines=state.lines or {}
  if state.busNaming or state.stationLinks or state.options or state.defaults then
    local copy={};for k,v in pairs(lines)do copy[k]=v end
    copy.__busNaming=state.busNaming;copy.__stationLinks=state.stationLinks
    copy.__options=state.options;copy.__defaults=state.defaults;lines=copy
  end
  return lines,revision
end
function A.saveOptions(options,callback)
  assert(A.read(),'线路配置尚未初始化，请稍后重试。')
  assert(type(options)=='table','Invalid options.')
  assert(options.flashNextStop==nil or type(options.flashNextStop)=='boolean','Invalid blink option.')
  assert(options.language==nil or languages[options.language]==true,'Invalid language.')
  local patch={flashNextStop=options.flashNextStop,language=options.language}
  assert(next(patch),'Empty options patch.')
  api.cmd.sendCommand(api.cmd.makeScriptingSendEventCmd('',A.id,A.optionsEvent,patch),callback)
end
function A.saveDefaults(defaults,callback)
  if not next(defaults) or not A.read()then return end
  api.cmd.sendCommand(api.cmd.makeScriptingSendEventCmd('',A.id,A.defaultsEvent,{defaults=defaults}),callback)
end
function A.stationKey(a,b)
  if type(a)~='number' or type(b)~='number' or a<0 or b<0 or a%1~=0 or b%1~=0 or a==b then return nil end
  return string.format('%.0f:%.0f',math.min(a,b),math.max(a,b))
end
function A.saveStationLink(a,b,remove,callback)
  assert(A.read(),'线路配置尚未初始化，请稍后重试。')
  assert(type(a)=='table' and type(b)=='table' and A.stationKey(a.id,b.id)
    and type(a.name)=='string' and type(b.name)=='string' and type(remove)=='boolean','请选择两个不同的车站。')
  local command=api.cmd.makeScriptingSendEventCmd('',A.id,A.stationEvent,
    {a={id=a.id,name=a.name},b={id=b.id,name=b.name},remove=remove})
  api.cmd.sendCommand(command,callback)
end
function A.saveBusNaming(config,lines,callback,defaults)
  assert(A.read(),'线路配置尚未初始化，请稍后重试。')
  local targets={}
  for _,line in ipairs(lines)do
    if line.mode=='BUS' and (line.busScope=='local' or line.busScope=='express')then
      targets[#targets+1]={id=line.id,name=line.name,default=defaults and defaults[tostring(line.id)]}
    end
  end
  local command=api.cmd.makeScriptingSendEventCmd('',A.id,A.busEvent,
    {enabled=config.enabled,districts=config.districts,format=config.format,
      expressCode=config.expressCode,targets=targets})
  api.cmd.sendCommand(command,callback)
end
local function aliasValue(line,shortName,displayMode,parts)
  assert(type(line)=='table' and type(line.id)=='number' and line.id>=0 and line.id%1==0
    and type(line.name)=='string' and type(shortName)=='string','无效的线路配置。')
  assert(displayMode==nil or ({['']=true,RER=true,METRO=true,TRAIN=true,TRAM=true,BUS=true,BOAT=true,AIR=true,TRUCK=true})[displayMode],
    '无效的显示类型。')
  local value={lineId=line.id,name=line.name,shortName=shortName:match('^%s*(.-)%s*$')}
  value.displayMode=displayMode
  if parts then
    assert(type(parts.prefix)=='string' and type(parts.identifier)=='string' and type(parts.suffix)=='string',
      '线路标号的三个字段必须是文字。')
    local identifier=parts.identifier:match('^%s*(.-)%s*$')
    assert(identifier:match('^[A-Za-z0-9]*$'),'编号仅支持数字或英文字母；留空自动编号。')
    value.prefix=parts.prefix:gsub('[\r\n]','')
    value.identifier=identifier
    value.suffix=parts.suffix:gsub('[\r\n]','')
  end
  return value
end
function A.save(line,shortName,callback,displayMode,parts)
  assert(A.read(),'线路配置尚未初始化，请稍后重试。')
  local value=aliasValue(line,shortName,displayMode,parts)
  local command=api.cmd.makeScriptingSendEventCmd('',A.id,A.event,value)
  api.cmd.sendCommand(command,callback)
  return value
end
function A.saveAll(changes,callback,defaults)
  assert(A.read(),'线路配置尚未初始化，请稍后重试。')
  local entries,seen={},{}
  for _,change in ipairs(changes)do
    local value=aliasValue(change.line,change.shortName,change.displayMode,change.parts)
    assert(not seen[value.lineId],'同一线路不能重复应用。')
    seen[value.lineId]=true;entries[#entries+1]=value
  end
  assert(#entries>0,'没有待应用的修改。')
  -- Reuse the existing subscribed event. Validate every row before sending
  -- one command; the simulation applies the patch with a single state write.
  local command=api.cmd.makeScriptingSendEventCmd('',A.id,A.event,{entries=entries,defaults=defaults})
  api.cmd.sendCommand(command,callback)
end
return A
