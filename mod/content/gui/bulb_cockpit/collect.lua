local M = ug_require 'linnan_bulb_cockpit::/gui/bulb_cockpit/model.lua'
local G = ug_require 'linnan_bulb_cockpit::/gui/bulb_cockpit/merge.lua'
local P = ug_require 'linnan_bulb_cockpit::/gui/bulb_cockpit/native_model.lua'
local C = {}
local function comp(id, kind)
  if not id or id < 0 or not api.engine.entityExists(id) then return nil end
  return api.engine.getComponent(id, api.type.ComponentType[kind])
end
-- Only retain engine component userdata during this one scan. The HUD cache
-- below holds plain Lua display data, never engine components or old routes.
local function memoizedComponents()
  local values={}
  return function(id,kind)
    if not id then return nil end
    local row=values[id]
    if not row then row={};values[id]=row end
    if row[kind]==nil then row[kind]=comp(id,kind) or false end
    return row[kind] or nil
  end
end
local function name(id,get)
  local c = (get or comp)(id, 'NAME')
  return c and c.name or tostring(id)
end
local function color(id,get)
  local c = (get or comp)(id, 'COLOR')
  if not c then return '#006db8' end
  local function byte(x) return math.floor(math.max(0, math.min(1, x))*255+0.5) end
  return string.format('#%02x%02x%02x', byte(c.color.x), byte(c.color.y), byte(c.color.z))
end
local function passengerLine(id,get)
  local cargo = api.res.cargoTypeRep.getPassengerCargoTypeId()
  for _, vid in ipairs(api.engine.system.transportVehicleSystem.getLineVehicles(id)) do
    local v = get(vid, 'TRANSPORT_VEHICLE')
    if v and (v.config.capacities[cargo+1] or 0) > 0 then return true end
  end
  return false
end
local function mode(id,get)
  local l = (get or comp)(id, 'LINE')
  local modes = l and l.vehicleInfo and l.vehicleInfo.transportModes or {}
  for _, n in ipairs({'TRAM','ELECTRIC_TRAM','TRAM_TRACK','ELECTRIC_TRAM_TRACK','TRAIN','ELECTRIC_TRAIN','BUS','TRUCK','SHIP','SMALL_SHIP','AIRCRAFT','SMALL_AIRCRAFT','HELICOPTER'}) do
    local e = api.type['enum'].TransportMode[n]
    if e and modes[e] then
      if n:find('TRAM') then return 'TRAM' end
      if n:find('TRAIN') then return 'TRAIN' end
      if n:find('SHIP') then return 'BOAT' end
      if n:find('AIRCRAFT') or n == 'HELICOPTER' then return 'AIR' end
      if n == 'TRUCK' then return 'TRUCK' end
      return 'BUS'
    end
  end
  return 'BUS'
end

function C.listTowns()
  local result={}
  api.engine.forEachEntityWithComponent(function(id)
    result[#result+1]={id=id,name=name(id)}
  end,api.type.ComponentType.TOWN)
  table.sort(result,function(a,b)return a.name==b.name and a.id<b.id or a.name<b.name end)
  return result
end
function C.listStationGroups(links)
  local result,seen={},{}
  for _,link in pairs(links or {})do
    for _,side in ipairs({'a','b'})do
      local station=link[side];local id=station and station.id
      if type(id)=='number' and not seen[id]then
        seen[id]=true
        if comp(id,'STATION_GROUP')then result[#result+1]={id=id,name=name(id)}end
      end
    end
  end
  table.sort(result,function(a,b)return a.name==b.name and a.id<b.id or a.name<b.name end)
  return result
end

-- Native Selector hits can be group icons, platforms, or station buildings.
-- Prefer explicit station details, and never guess among different groups.
function C.resolveStation(entity,details)
  local function valid(id)return type(id)=='number' and id>=0 and id%1==0 end
  local function group(id)
    if valid(id) and comp(id,'STATION_GROUP')then return {id=id,name=name(id)}end
  end
  local data=details and details.data
  if data then
    local kinds=api.gui.SelectionDetails.Type
    if data.kind==kinds.Station then return group(data.stationGroup)end
    if data.kind==kinds.Stop then return group(data.station and data.station.stationGroup)end
  end
  if not valid(entity)then return nil end
  local selected=group(entity)
  if selected then return selected end
  if comp(entity,'STATION')then
    return group(api.engine.system.stationGroupSystem.getStationGroup(entity))
  end
  local construction=comp(entity,'CONSTRUCTION')
  if not construction then return nil end
  for _,station in ipairs(construction.stations or {})do
    local candidate=group(api.engine.system.stationGroupSystem.getStationGroup(station))
    if candidate then
      if selected and selected.id~=candidate.id then
        return nil,'这里包含多个独立车站，请点击目标车站的图标。'
      end
      selected=candidate
    end
  end
  return selected
end
-- Build connected components from explicit links only. Station IDs remain
-- independent; this graph expands transfer queries, never route stops.
local function stationNetwork(links,get,stops)
  local edges,valid,network={},{},{}
  local function exists(id)
    if type(id)~='number' or id<0 or id%1~=0 then return false end
    if valid[id]==nil then valid[id]=get(id,'STATION_GROUP')~=nil end
    return valid[id]
  end
  for _,link in pairs(links or {})do
    local a,b=type(link)=='table' and link.a,type(link)=='table' and link.b
    if type(a)=='table' and type(b)=='table' and type(a.id)=='number' and type(b.id)=='number'
      and a.id>=0 and b.id>=0 and a.id%1==0 and b.id%1==0 and a.id~=b.id then
      edges[a.id]=edges[a.id] or {};edges[b.id]=edges[b.id] or {}
      edges[a.id][b.id]=true;edges[b.id][a.id]=true
    end
  end
  for _,stop in ipairs(stops)do
    local id=stop.stationGroup
    if edges[id] and not network[id] and exists(id)then
      local members,seen={id},{[id]=true};local index=1
      while index<=#members do
        for other in pairs(edges[members[index]] or {})do
          if not seen[other] and exists(other)then seen[other]=true;members[#members+1]=other end
        end
        index=index+1
      end
      table.sort(members)
      for _,member in ipairs(members)do network[member]=members end
    end
  end
  return network
end
local function townLookup()
  local cache={}
  return function(station)
    if cache[station]==nil then cache[station]=api.engine.system.stationSystem.getTown(station) or false end
    return cache[station] or nil
  end
end
local function busCities(id,townForStation,get)
  local line=get(id,'LINE')
  local towns,seen,complete={}, {},true
  local stops=line and line.stops or {}
  for _,stop in ipairs(stops)do
    local group=get(stop.stationGroup,'STATION_GROUP')
    local stations=group and group.stations or {}
    if #stations==0 then complete=false end
    for _,station in ipairs(stations)do
      local town=townForStation(station)
      if town and get(town,'TOWN')then
        if not seen[town]then seen[town]=true;towns[#towns+1]={id=town,name=name(town,get)}end
      else complete=false end
    end
  end
  table.sort(towns,function(a,b)return a.id<b.id end)
  return towns,#towns>1 and 'express' or (#towns==1 and complete and #stops>0 and 'local' or 'unknown')
end
function C.listLines(withCities,get)
  get=get or memoizedComponents()
  local result = {}
  local townForStation=withCities and townLookup()
  for _, id in ipairs(api.engine.system.lineSystem.getLines()) do
    local line={id=id, name=name(id,get), color=color(id,get), mode=mode(id,get)}
    if withCities and line.mode=='BUS'then line.towns,line.busScope=busCities(id,townForStation,get)end
    result[#result+1]=line
  end
  table.sort(result, function(a,b) return a.name < b.name end)
  return result
end

local function mergeKey(main,aliases)
  local ids=G.candidates(main,aliases,P)
  return P.mode(main,aliases)..':'..P.alias(main,aliases,P.defaults({main},aliases))..':'..table.concat(ids,','),ids
end
local function servicesFor(main,aliases,get)
  local key,ids=mergeKey(main,aliases)
  local services={}
  local badge=P.alias(main,aliases,P.defaults({main},aliases))
  for _,id in ipairs(ids)do
    local route=get(id,'LINE')
    if route then
      local info={id=id,name=name(id,get),mode=mode(id,get),color=color(id,get)}
      local other=P.alias(info,aliases,P.defaults({info},aliases))
      local entry=aliases and aliases[tostring(id)]
      local fallback=aliases and aliases.__defaults and aliases.__defaults[tostring(id)]
      local live=id==main.id or (entry and entry.name==info.name) or (fallback and fallback.name==info.name)
      if live and P.mode(info,aliases)==P.mode(main,aliases) and other==badge then
        local stops={}
        for i,stop in ipairs(route.stops)do stops[i]={id=stop.stationGroup,name=name(stop.stationGroup,get),sourceIndex=i-1,transfers={}}end
        info.stops=M.servicePath(stops)
        services[#services+1]=info
      end
    end
  end
  return services,key
end
function C.mergeStatus(line,aliases)
  local get=memoizedComponents()
  local main={id=line.id,name=name(line.id,get),mode=mode(line.id,get)}
  local services=servicesFor(main,aliases,get)
  local graph,warning=G.build(services)
  return graph and #services or 1,warning
end
local function topology(lineId,withCities,stationLinks,aliases)
  local get=memoizedComponents()
  local line=get(lineId,'LINE')
  if not line then return nil end
  local main={id=lineId,name=name(lineId,get),color=color(lineId,get),mode=mode(lineId,get)}
  local services,key=servicesFor(main,aliases,get)
  local graph,warning=G.build(services)
  local allStops={};for _,stop in ipairs(line.stops)do allStops[#allStops+1]=stop end
  if graph then
    for _,service in ipairs(services)do
      for _,stop in ipairs(service.stops)do allStops[#allStops+1]={stationGroup=stop.id}end
    end
  end
  local stationCache, serviceCache,serviceInfo = {}, {},{}
  local network=stationNetwork(stationLinks,get,allStops)
  local stops = {}
  local function transfersFor(id)
    local transfers = stationCache[id]
    if not transfers then
      transfers = {}
      local seen = {}
      local members=network[id] or {id}
      for _,group in ipairs(members)do
        for _, other in ipairs(api.engine.system.lineSystem.getLinesForStationGroup(group)) do
          if other~=lineId and not(graph and graph.members[other]) and not seen[other] then
            seen[other]=true
            if serviceCache[other]==nil then serviceCache[other]=passengerLine(other,get)end
            if serviceCache[other]then
              if not serviceInfo[other]then
                serviceInfo[other]={id=other,name=name(other,get),color=color(other,get),mode=mode(other,get)}
              end
              transfers[#transfers+1]=serviceInfo[other]
            end
          end
        end
      end
      table.sort(transfers, function(a,b) return a.name < b.name end)
      for _,group in ipairs(members)do stationCache[group]=transfers end
    end
    return transfers
  end
  for i,stop in ipairs(line.stops)do
    local id=stop.stationGroup
    stops[i]={id=id,name=name(id,get),sourceIndex=i-1,transfers=transfersFor(id)}
  end
  if graph then
    -- Attach display transfers after membership validation, so an invalid
    -- group never expands queries beyond the current line.
    for _,node in ipairs(graph.nodes)do node.transfers=transfersFor(node.id)end
  end
  local townForStation=withCities and townLookup()
  local lines={main}
  if graph then for _,info in ipairs(services)do if info.id~=lineId then lines[#lines+1]=info end end end
  for _,info in pairs(serviceInfo)do lines[#lines+1]=info end
  for _,info in ipairs(lines)do
    if withCities and info.mode=='BUS'then
      local route=get(info.id,'LINE')
      local ids={};for _,stop in ipairs(route and route.stops or {})do ids[#ids+1]=stop.stationGroup end
      info.routeKey=table.concat(ids,',')
      info.towns,info.busScope=busCities(info.id,townForStation,get)
    end
  end
  table.sort(lines,function(a,b)return a.id<b.id end)
  return {stops=stops,main=main,lines=lines,network=graph,mergeWarning=warning,mergeKey=key}
end
-- Explicit directory navigation only. No timer, vehicle lookup, global roster
-- scan or retained snapshot: the static view owns this one plain-data graph.
function C.readLine(lineId,withCities,stationLinks,aliases)
  if type(lineId)~='number' or lineId<0 or lineId%1~=0 then return nil end
  local base=topology(lineId,withCities,stationLinks,aliases)
  if not base or #base.stops==0 then return nil end
  local stops=M.servicePath(base.stops) or base.stops
  if stops[#stops].id==base.stops[1].id and stops[1].id~=base.stops[1].id then
    local outbound={};for i=#stops,1,-1 do outbound[#outbound+1]=stops[i]end
    stops=outbound
  end
  return {static=true,route={lineId=lineId,name=base.main.name,color=base.main.color,mode=base.main.mode,stops=stops},
    lines=base.lines,network=base.network,mergeWarning=base.mergeWarning,next=0,passed=0}
end
local function linksKey(links)
  local edges={}
  for _,link in pairs(links or {})do
    local a,b=type(link)=='table' and link.a,type(link)=='table' and link.b
    a,b=type(a)=='table' and a.id,type(b)=='table' and b.id
    if type(a)=='number' and type(b)=='number' and a>=0 and b>=0 and a%1==0 and b%1==0 and a~=b then
      edges[tostring(math.min(a,b))..':'..tostring(math.max(a,b))]=true
    end
  end
  local keys={};for key in pairs(edges)do keys[#keys+1]=key end
  table.sort(keys);return table.concat(keys,',')
end
-- Initialize current-line metadata and real transfers once per cockpit entry.
-- Afterwards only read the followed vehicle; arrival and departure share the
-- same target, so leaving a station does not invalidate the arrival snapshot.
-- Explicit association/city settings or a different vehicle/line reinitialize.
-- No cache argument means an immediate fresh read (settings/tools/tests).
local function clearCache(cache)for k in pairs(cache)do cache[k]=nil end end
function C.read(vehicle,withCities,stationLinks,cache,aliases)
  if type(aliases)~='table'then aliases=nil end
  cache=cache or {}
  if type(vehicle)~='number' or vehicle<0 then clearCache(cache);return nil end
  local tv=comp(vehicle,'TRANSPORT_VEHICLE')
  local enums=api.type['enum'].TransportVehicleState
  if not tv or (tv.state~=enums.EN_ROUTE and tv.state~=enums.AT_TERMINAL)then clearCache(cache);return nil end
  local linkKey=cache.links==stationLinks and cache.linkKey or linksKey(stationLinks)
  local key=cache.base and (cache.aliases==aliases and cache.base.mergeKey or mergeKey(cache.base.main,aliases))
  if not cache.base or cache.base.mergeKey~=key or cache.vehicle~=vehicle or cache.lineId~=tv.line
    or cache.withCities~=withCities or cache.linkKey~=linkKey then
    local base=topology(tv.line,withCities,stationLinks,aliases)
    clearCache(cache)
    if not base then return nil end
    cache.base,cache.vehicle,cache.lineId=base,vehicle,tv.line
    cache.withCities,cache.linkKey=withCities,linkKey
  end
  if cache.links~=stationLinks then cache.links=stationLinks end
  cache.aliases=aliases
  local atTerminal=tv.state==enums.AT_TERMINAL
  local n,index=#cache.base.stops,tv.stopIndex
  if type(index)~='number' or index%1~=0 or index<0 or index>=n then clearCache(cache);return nil end
  local progress=n==1 and (atTerminal and 1 or 0) or (index+(atTerminal and 1 or 0))%n
  local previous=cache.snapshot
  if previous and previous.progress==progress then return previous end
  local journey=M.journey(cache.base.stops,tv.stopIndex,atTerminal)
  if not journey then clearCache(cache);return nil end
  local main=cache.base.main
  local route={lineId=tv.line,name=main.name,color=main.color,mode=main.mode,stops=journey.stops}
  local snapshot={route=route,lines=cache.base.lines,next=journey.next,passed=journey.passed,
    vehicle=vehicle,stopIndex=tv.stopIndex,atTerminal=atTerminal,progress=progress,
    network=cache.base.network,mergeWarning=cache.base.mergeWarning}
  cache.snapshot=snapshot
  return snapshot
end
return C
