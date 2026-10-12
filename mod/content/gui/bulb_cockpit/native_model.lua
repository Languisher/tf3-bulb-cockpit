local P = {}
local displayModes={RER=true,METRO=true,TRAIN=true,TRAM=true,BUS=true,BOAT=true,AIR=true,TRUCK=true}
function P.mode(line,aliases)
  local entry=aliases and aliases[tostring(line.lineId or line.id)]
  local mode=entry and entry.name==line.name and displayModes[entry.displayMode] and entry.displayMode or line.mode or 'TRAIN'
  -- TRAIN is the engine's rail mode and the previous version's saved choice.
  return mode=='TRAIN' and 'RER' or mode
end
local function letter(index)
  local value=''
  repeat
    index=index-1
    value=string.char(65+index%26)..value
    index=math.floor(index/26)
  until index==0
  return value
end
function P.busCodeTable(towns,config)
  config=config or {}
  local old=config.districts or {}
  local byId,ordered,used={},{},{}
  for key,value in pairs(old)do
    local id=tonumber(key)
    if id then byId[id]={id=id,name=value.name}end
    if type(value.code)=='string' and value.code:match('^%d+$')then used[value.code]=true end
  end
  for _,town in ipairs(towns)do byId[town.id]=town end
  for _,town in pairs(byId)do ordered[#ordered+1]=town end
  table.sort(ordered,function(a,b)return a.id<b.id end)
  local express=config.format=='code_table' and config.expressCode or '51'
  if type(express)~='string' or not express:match('^%d*$')then express='51'end
  used[express]=true
  local result={enabled=config.enabled==true,format='code_table',expressCode=express,districts={}}
  local nextCode=10
  for _,town in ipairs(ordered)do
    local previous=old[tostring(town.id)]
    local code=previous and previous.name==town.name and previous.code
    if type(code)~='string' or not code:match('^%d+$') then
      if not(config.format=='code_table' and code=='')then
        while used[tostring(nextCode)]do nextCode=nextCode+1 end
        code=tostring(nextCode);used[code]=true
      end
    end
    result.districts[tostring(town.id)]={name=town.name,code=code}
  end
  return result
end
function P.validateBusCodes(config,tr)
  tr=tr or string.format
  local used={}
  local function check(code,name)
    if type(code)~='string' or not code:match('^%d*$')then return false,tr('%s的前缀只能填写数字；留空跳过。',name)end
    if code~='' and used[code]then return false,tr('%s与%s的前缀重复。',name,used[code])end
    if code~=''then used[code]=name end
    return true
  end
  local ok,message=check(config.expressCode,'Express');if not ok then return false,message end
  for _,district in pairs(config.districts)do
    ok,message=check(district.code,district.name);if not ok then return false,message end
  end
  return true
end
function P.defaults(lines,aliases)
  -- Saved assignments reserve their numbers. Discovering another route
  -- must not renumber an existing badge or require reading the whole map.
  local saved=aliases and aliases.__defaults or {}
  local ordered,seen,result,counts={},{},{},{}
  for _,value in pairs(saved)do
    if value.index and value.mode then
      local key=value.busAuto and value.busKey or value.mode
      if key then counts[key]=math.max(counts[key] or 0,value.index)end
    end
  end
  for _,line in ipairs(lines)do
    local id=line.lineId or line.id
    if type(id)=='number' and not seen[id]then seen[id]=true;ordered[#ordered+1]=line end
  end
  table.sort(ordered,function(a,b)return (a.lineId or a.id)<(b.lineId or b.id)end)
  for _,line in ipairs(ordered)do
    local mode=P.mode(line,aliases);local key=tostring(line.lineId or line.id)
    if mode=='RER' or mode=='TRAM' or mode=='METRO'then
      local old=saved[key]
      local index=old and old.mode==mode and old.index
      if not index then index=(counts[mode] or 0)+1;counts[mode]=index end
      result[key]={name=line.name,mode=mode,index=index,
        shortName=mode=='RER' and letter(index) or (mode=='TRAM' and 'T' or '')..index}
    end
  end
  local naming=aliases and aliases.__busNaming
  if naming and naming.enabled then
    local towns={}
    for _,line in ipairs(ordered)do
      local old=saved[tostring(line.lineId or line.id)]
      for _,town in ipairs(line.towns or (old and old.name==line.name and old.towns) or {})do towns[#towns+1]=town end
    end
    local effective={};for k,v in pairs(naming)do effective[k]=v end
    effective.districts={};for k,v in pairs(naming.districts or {})do effective.districts[k]=v end
    for _,old in pairs(saved)do
      local town=old.busAuto and old.busScope=='local' and old.towns and old.towns[1]
      if town and not effective.districts[tostring(town.id)]then
        effective.districts[tostring(town.id)]={name=town.name,code=old.code}
      end
    end
    local mapping=P.busCodeTable(towns,effective)
    for _,line in ipairs(ordered)do
      local id=tostring(line.lineId or line.id);local old=saved[id]
      if old and old.name~=line.name then old=nil end
      local scope=line.busScope or (old and old.busScope)
      local lineTowns=line.towns or (old and old.towns)
      if line.mode=='BUS' and (scope=='local' or scope=='express')then
        local town=lineTowns and lineTowns[1]
        if scope=='express' or town then
          local key=scope=='express' and 'express' or 'town:'..town.id
          local index=old and old.busAuto and old.busKey==key and old.index
          if not index then index=(counts[key] or 0)+1;counts[key]=index end
          local district=town and mapping.districts[tostring(town.id)]
          local code=scope=='express' and mapping.expressCode or district.code
          if code~=''then
            local identifier=code..string.format('%02d',index)
            result[id]={name=line.name,mode='BUS',index=index,code=code,busKey=key,
              prefix='',identifier=identifier,suffix='',shortName=identifier,busAuto=true,
              towns=lineTowns,busScope=scope,routeKey=line.routeKey or (old and old.routeKey)}
          end
        end
      end
    end
  end
  return result
end
local function same(a,b)
  if type(a)~=type(b)then return false end
  if type(a)~='table'then return a==b end
  for k,v in pairs(a)do if not same(v,b[k])then return false end end
  for k in pairs(b)do if a[k]==nil then return false end end
  return true
end
function P.pendingDefaults(lines,aliases)
  local result={};local saved=aliases and aliases.__defaults or {}
  for key,value in pairs(P.defaults(lines,aliases))do
    if not same(value,saved[key])then result[key]=value end
  end
  return result
end
function P.viewport(host,gauge,units)
  units=units or 100
  local function positive(v)return type(v)=='number' and v>0 and v<math.huge end
  if not host or not gauge or not positive(host.x) or not positive(host.y)
    or not positive(gauge.x) or not positive(gauge.y) or not positive(units)then return nil end
  -- Ratios cancel the API's screen-coordinate units. The gauge is exactly
  -- a known number of GUI units, independent of Retina/render scaling.
  local width,height=units*host.x/gauge.x,units*host.y/gauge.y
  if not positive(width) or not positive(height) then return nil end
  return {x=math.floor(width+0.5),y=math.floor(height+0.5)}
end
function P.defaultIdentifier(line,defaults)
  local fallback=defaults and defaults[tostring(line.lineId or line.id)]
  if fallback and fallback.name==line.name then
    if fallback.identifier then return fallback.identifier end
    return fallback.shortName:match('^T(%d+)$') or fallback.shortName
  end
  return tostring(line.name or ''):match('%d+') or tostring(line.lineId or line.id or '')
end
local function automaticBus(line,aliases,defaults)
  local entry=aliases and aliases[tostring(line.lineId or line.id)]
  local fallback=defaults and defaults[tostring(line.lineId or line.id)]
  return fallback and fallback.name==line.name and fallback.busAuto
    and not(entry and entry.name==line.name and entry.autoBus==false) and fallback or nil
end
function P.parts(line,aliases,defaults)
  local automatic=automaticBus(line,aliases,defaults)
  if automatic then return {prefix=automatic.prefix,identifier='',suffix=''}end
  local entry=aliases and aliases[tostring(line.lineId or line.id)]
  if entry and entry.name==line.name then
    if type(entry.identifier)=='string' then
      return {prefix=entry.prefix or '',identifier=entry.identifier,suffix=entry.suffix or ''}
    elseif type(entry.shortName)=='string' and entry.shortName~='' then
      local prefix,identifier,suffix=entry.shortName:match('^(.-)(%d+)(.*)$')
      return {prefix=prefix or '',identifier=identifier or entry.shortName,suffix=suffix or ''}
    end
  end
  return {prefix=P.mode(line,aliases)=='TRAM' and 'T' or '',identifier='',suffix=''}
end
function P.identifier(line,aliases,defaults)
  local parts=P.parts(line,aliases,defaults)
  return parts.identifier~='' and parts.identifier or P.defaultIdentifier(line,defaults)
end
function P.alias(line, aliases, defaults)
  local automatic=automaticBus(line,aliases,defaults)
  if automatic then return automatic.shortName,true end
  local entry = aliases and aliases[tostring(line.lineId or line.id)]
  if entry and entry.name==line.name and type(entry.identifier)=='string' then
    return (entry.prefix or '')..P.identifier(line,aliases,defaults)..(entry.suffix or ''),true
  end
  if entry and entry.name==line.name and type(entry.shortName)=='string' and entry.shortName~='' then return entry.shortName,true end
  local fallback=defaults and defaults[tostring(line.lineId or line.id)]
  if fallback and fallback.name==line.name then return fallback.shortName,true end
  return line.name,false
end
function P.wrap(value, columns, uniform)
  local lines, part, used = {}, '', 0
  for c in tostring(value):gmatch('[%z\1-\127\194-\244][\128-\191]*') do
    local weight = (uniform or #c > 1) and 2 or 1
    if c == '\n' or used+weight > columns then
      lines[#lines+1] = part
      part, used = '', 0
    end
    if c ~= '\n' then part, used = part..c, used+weight end
  end
  lines[#lines+1] = part
  return table.concat(lines,'\n'), #lines
end
local function textWidth(value,size,uniform)
  local longest,used=0,0
  for c in value:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
    if c=='\n' then longest=math.max(longest,used);used=0
    else used=used+((uniform or #c>1) and 2 or 1) end
  end
  return math.max(longest,used)*size/2+4
end
function P.ellipsize(value,columns,uniform)
  local chars,used={},0
  for c in tostring(value):gsub('[\r\n]',' '):gmatch('[%z\1-\127\194-\244][\128-\191]*') do
    chars[#chars+1]=c;used=used+((uniform or #c>1) and 2 or 1)
  end
  if used<=columns then return table.concat(chars) end
  local result,count={},0
  for _,c in ipairs(chars) do
    local weight=(uniform or #c>1) and 2 or 1
    if count+weight>columns-2 then break end
    result[#result+1]=c;count=count+weight
  end
  return table.concat(result)..'…'
end
local modeOrder={METRO=1,RER=2,TRAM=3,BUS=4,BOAT=5,AIR=6,TRUCK=7}
local function labelKey(value)
  return tostring(value):lower():gsub('%d+',function(digits)
    return string.format('%04d',#digits)..digits
  end)
end
function P.transferGroups(transfers,maxWidth)
  local groups,byMode={},{}
  for _,transfer in ipairs(transfers)do
    local group=byMode[transfer.mode]
    if not group then
      group={mode=transfer.mode,lines={},rows={}}
      byMode[transfer.mode]=group;groups[#groups+1]=group
    end
    group.lines[#group.lines+1]=transfer
  end
  table.sort(groups,function(a,b)return (modeOrder[a.mode] or 8)<(modeOrder[b.mode] or 8)end)
  local widest,rowCount,totalHeight=0,0,0
  for _,group in ipairs(groups)do
    table.sort(group.lines,function(a,b)
      local ka,kb=labelKey(a.text),labelKey(b.text)
      return ka==kb and a.fullName<b.fullName or ka<kb
    end)
    -- Match mode_marks.geometry's fixed small badges. One mode symbol is
    -- centered below the station; its line badges extend to the right.
    local badge=group.mode=='BUS' and 34 or (group.mode=='TRUCK' and 38 or 24)
    local icon,gap=18,5
    local capacity=math.max(1,math.floor((maxWidth-icon)/(badge+gap)))
    if group.mode=='BUS'then capacity=math.min(3,capacity)end
    local rowStep=group.mode=='BUS' and 18 or 28
    group.width=0
    for first=1,#group.lines,capacity do
      local row={lines={},y=#group.rows*rowStep}
      for index=first,math.min(first+capacity-1,#group.lines)do
        row.lines[#row.lines+1]=group.lines[index]
      end
      row.width=icon+gap+#row.lines*badge+(#row.lines-1)*gap
      group.rows[#group.rows+1]=row
      group.width=math.max(group.width,row.width)
      widest=math.max(widest,row.width);rowCount=rowCount+1
    end
    group.height=24+(#group.rows-1)*rowStep
    totalHeight=totalHeight+group.height+4
  end
  return groups,widest,rowCount,totalHeight
end
function P.trackStyle(mode)
  if mode=='METRO'then
    return {rail=6,stripe=0,ordinarySize=18,interchangeSize=18,terminusSize=18,ordinaryFill='line'}
  elseif mode=='RER' or mode=='TRAIN'then
    return {rail=18,stripe=0,ordinarySize=10,interchangeSize=14,terminusSize=16,ordinaryFill='white'}
  elseif mode=='TRAM'then
    return {rail=8,stripe=2.5,ordinarySize=14,interchangeSize=14,terminusSize=16,ordinaryFill='line'}
  end
  return {rail=6,stripe=0,ordinarySize=14,interchangeSize=14,terminusSize=16,ordinaryFill='line'}
end
local function occurrenceKey(route,stop,index)
  return tostring(route.lineId)..':'..tostring(stop.id or stop.name)..':'..tostring(stop.sourceIndex or index-1)
end
function P.nextKey(snapshot)
  if not snapshot or not snapshot.route then return nil end
  local route=snapshot.route
  local stop=route.stops[snapshot.next]
  if not stop then return nil end
  return tostring(snapshot.vehicle or '')..':'..occurrenceKey(route,route.stops[1],1)
    ..'>'..occurrenceKey(route,stop,snapshot.next)
end
-- Each station reserves only its actual rotated name and transfer footprint.
-- Hidden stretches are rail labels, not fictitious stop markers.
local function arrange(stops,tr)
  local g={left=24,fontSize=14,transferStep=28,iconSize=26,lampSize=14}
  local gaps,furthest={},0
  for index,stop in ipairs(stops)do
    local previous=stops[index-1]
    stop.x=g.left
    if previous then
      local distance=math.max(52,previous.nameWidth*math.cos(math.pi/6)+stop.nameRows*18/2+10,
        previous.rowWidth>0 and previous.rowWidth+14 or 0)
      local count=stop.index-previous.index-1
      if count>0 then
        local caption=tr('… %d站',count)
        local gap={first=previous.index+1,last=stop.index-1,count=count,text=caption,
          labelWidth=textWidth(caption,10,false)+8}
        distance=math.max(distance,gap.labelWidth+(previous.markerSize+stop.markerSize)/2+12)
        gap.x=previous.x+distance/2
        gaps[#gaps+1]=gap
      end
      stop.x=previous.x+distance
    end
    furthest=math.max(furthest,stop.x+stop.nameWidth*math.cos(math.pi/6),
      stop.x+stop.markerSize/2,stop.x-9+stop.rowWidth)
  end
  g.right=stops[#stops] and stops[#stops].x or g.left
  g.width=math.ceil(furthest+12);g.rightMargin=g.width-g.right
  return g,gaps
end
function P.plan(snapshot, aliases, blink, width,tr)
  tr=tr or string.format
  if snapshot.network then return P.branchPlan(snapshot,aliases,blink,width,tr)end
  local route=snapshot.route
  local defaults=P.defaults(snapshot.lines or {route},aliases)
  local n=#route.stops
  local result={name=route.name,mode=P.mode(route,aliases),total=n}
  result.badge,result.hasBadge=P.alias(route,aliases,defaults)
  result.track=P.trackStyle(result.mode)
  local prepared={}
  -- Leave room for origin, next stop and terminus even on a narrow GUI.
  local maxRowWidth=math.min(180,math.max(60,math.floor((width-36)/math.min(3,math.max(1,n)))-14))
  local function prepare(index)
    if prepared[index]then return prepared[index]end
    local stop=route.stops[index]
    local transfers={}
    for _,transfer in ipairs(stop.transfers)do
      transfers[#transfers+1]={id=transfer.id,text=P.alias(transfer,aliases,defaults),fullName=transfer.name,
        color=transfer.color,mode=P.mode(transfer,aliases)}
    end
    local groups,rowWidth,rows,height=P.transferGroups(transfers,maxRowWidth)
    prepared[index]={transfers=transfers,groups=groups,rowWidth=rowWidth,rows=rows,height=height}
    return prepared[index]
  end
  local function build(indices,labelWidth)
    local stops={}
    local columns=math.max(4,math.floor((labelWidth-4)/14)*2)
    for _,i in ipairs(indices)do
      local stop,data=route.stops[i],prepare(i)
      local value,rows=P.wrap(P.ellipsize(stop.name,columns*2,true),columns,true)
      local kind=(i==1 or i==n) and 'terminus' or (#data.transfers>0 and 'interchange' or 'ordinary')
      stops[#stops+1]={index=i,key=occurrenceKey(route,stop,i),name=value,fullName=stop.name,nameRows=rows,
        nameWidth=math.min(labelWidth,textWidth(value,14,true)),rowWidth=data.rowWidth,
        transfers=data.transfers,transferGroups=data.groups,transferRows=data.rows,transferHeight=data.height,markerKind=kind,
        markerSize=result.track[kind..'Size'],
        lit=i<=snapshot.passed or (i==snapshot.next and blink),endpoint=i==1 or i==n}
    end
    local geometry,gaps=arrange(stops,tr)
    return {stops=stops,geometry=geometry,gaps=gaps}
  end
  local layout
  -- No full-route fit can beat the minimum 52-unit station spacing. Avoid
  -- preparing hidden stops when this lower bound already exceeds the GUI.
  if 36+math.max(0,n-1)*52<=width then
    local all={};for i=1,n do all[i]=i end
    layout=build(all,128)
  end
  if not layout or layout.geometry.width>width then
    local target=math.max(1,math.min(n,snapshot.next>0 and snapshot.next or math.max(1,snapshot.passed)))
    local selected={}
    for _,i in ipairs({1,target,n})do if i>0 then selected[i]=true end end
    local function indices()
      local values={};for i in pairs(selected)do values[#values+1]=i end
      table.sort(values);return values
    end
    local labelWidth=128
    for _,limit in ipairs({128,96,72,56,44})do
      labelWidth=limit;layout=build(indices(),limit)
      if layout.geometry.width<=width then break end
    end
    -- Keep context around the next stop, then near both ends. The candidate
    -- count is bounded; a very long line does not trigger quadratic fitting.
    for _,i in ipairs({target-1,target+1,target+2,target-2,n-1,2,target+3,target-3,target+4,target-4})do
      if i>=1 and i<=n and not selected[i]then
        selected[i]=true
        local candidate=build(indices(),labelWidth)
        if candidate.geometry.width<=width then layout=candidate else selected[i]=nil end
      end
    end
  end
  result.stops,result.geometry,result.gaps=layout.stops,layout.geometry,layout.gaps
  result.first,result.last=1,n
  result.nameRows,result.transferRows,result.transferHeight=1,0,0
  for _,stop in ipairs(result.stops)do
    result.nameRows=math.max(result.nameRows,stop.nameRows)
    result.transferRows=math.max(result.transferRows,stop.transferRows)
    result.transferHeight=math.max(result.transferHeight,stop.transferHeight)
  end
  return result
end
-- Fillet a polyline with circular arcs, as BULB's SvgLine does before
-- stroking. Native GUI rectangles approximate each arc to < .12 GUI units
-- for normal bends, with an absolute twelve-chord limit per corner. This
-- runs only when a diagram is rebuilt; no textures or persistent cache.
function P.roundedTrack(points,thickness,ink,key)
  local path,result={},{}
  for _,p in ipairs(points)do
    local prior=path[#path]
    if not prior or math.abs(p.x-prior.x)+math.abs(p.y-prior.y)>.00001 then path[#path+1]=p end
  end
  local function stroke(a,b,suffix,curve)
    if math.abs(a.x-b.x)+math.abs(a.y-b.y)<.00001 then return end
    result[#result+1]={x1=a.x,y1=a.y,x2=b.x,y2=b.y,color=ink,key=key..suffix,curve=curve or nil}
  end
  local cursor=path[1]
  for i=2,#path-1 do
    local a,b,c=path[i-1],path[i],path[i+1]
    local ux,uy,vx,vy=b.x-a.x,b.y-a.y,c.x-b.x,c.y-b.y
    local incoming,outgoing=math.sqrt(ux*ux+uy*uy),math.sqrt(vx*vx+vy*vy)
    ux,uy,vx,vy=ux/incoming,uy/incoming,vx/outgoing,vy/outgoing
    local turn=math.acos(math.max(-1,math.min(1,ux*vx+uy*vy)))
    local cross=ux*vy-uy*vx
    if turn<.00001 or math.abs(cross)<.00001 then
      stroke(cursor,b,':straight:'..i);cursor=b
    else
      local tangent=math.tan(turn/2)
      local radius=math.min(thickness*2.5,math.min(incoming,outgoing)*.45/tangent)
      local trim=radius*tangent
      local first,last={x=b.x-ux*trim,y=b.y-uy*trim},{x=b.x+vx*trim,y=b.y+vy*trim}
      stroke(cursor,first,':straight:'..i)
      local sign=cross>0 and 1 or -1
      local cx,cy=first.x-uy*sign*radius,first.y+ux*sign*radius
      local rx,ry=first.x-cx,first.y-cy
      local step=math.min(math.pi/15,math.sqrt(.96/radius))
      local count=math.min(12,math.max(2,math.ceil(turn/step)))
      local previous=first
      for j=1,count do
        local angle=sign*turn*j/count
        local point=j==count and last or {x=cx+rx*math.cos(angle)-ry*math.sin(angle),
          y=cy+rx*math.sin(angle)+ry*math.cos(angle)}
        stroke(previous,point,':curve:'..i..':'..j,true);previous=point
      end
      cursor=last
    end
  end
  if cursor and #path>1 then stroke(cursor,path[#path],':end')end
  return result
end
-- Convert the station union into a layered diagram. Paths are oriented from
-- their shared station order; a longest-path rank keeps unequal parallel
-- branches aligned at their shared ends. Cyclic connections use a return lane.
function P.branchPlan(snapshot,aliases,blink,width,tr)
  tr=tr or string.format
  local graph,route=snapshot.network,snapshot.route
  local mode=P.mode(route,aliases)
  local result={name=route.name,mode=mode,track=P.trackStyle(mode),stops={},segments={},rails={},gaps={},total=#graph.nodes}
  result.badge,result.hasBadge=P.alias(route,aliases,P.defaults(snapshot.lines,aliases))
  local active,selected={},{}
  for i,stop in ipairs(route.stops)do active[stop.id]=i end
  for _,node in ipairs(graph.nodes)do
    if node.degree~=2 or node.terminal then selected[node.id]=true end
  end
  local target=route.stops[snapshot.next] and route.stops[snapshot.next].id
  selected[route.stops[1].id]=true;selected[route.stops[#route.stops].id]=true
  if target then selected[target]=true end
  local budget=math.max(4,math.floor(width/110))
  if #graph.nodes<=budget then
    for _,node in ipairs(graph.nodes)do selected[node.id]=true end
  else
    -- Keep a real station on each alternative path, even when all its other
    -- intermediate stations are omitted. Distinct parallel branches survive.
    for _,service in ipairs(graph.services)do
      local represented=false
      for i=2,#service.stops-1 do if selected[service.stops[i].id]then represented=true;break end end
      if not represented then selected[service.stops[math.ceil(#service.stops/2)].id]=true end
    end
    for _,i in ipairs(budget>=6 and {snapshot.next-1,snapshot.next+1} or {})do
      if route.stops[i]then selected[route.stops[i].id]=true end
    end
  end
  local paths={{id=route.lineId,color=route.color,stops=route.stops}}
  -- Orient whole services from station ORDER, never distance to an endpoint.
  -- Unequal forks can have their two origins on the same side of a common
  -- destination. A shortest-path heuristic incorrectly appends the second
  -- origin beyond that destination and changes all terminus markers.
  local current
  for _,service in ipairs(graph.services)do if service.id==route.lineId then current=service;break end end
  local canonical={}
  for i,stop in ipairs(current.stops)do canonical[stop.id]=i end
  local flipped=canonical[route.stops[1].id]>canonical[route.stops[#route.stops].id]
  local references={{positions=active,flipped=flipped,
    endpoints={[route.stops[1].id]=true,[route.stops[#route.stops].id]=true}}}
  local pending={}
  for _,service in ipairs(graph.services)do if service.id~=route.lineId then pending[#pending+1]=service end end
  while #pending>0 do
    local chosen,bestFlip,bestCount
    for pi,service in ipairs(pending)do
      for _,ref in ipairs(references)do
        local first,last,count=nil,nil,0
        for _,stop in ipairs(service.stops)do
          local position=ref.positions[stop.id]
          if position then first=first or position;last=position;count=count+1 end
        end
        local sharedEnd=ref.endpoints[service.stops[1].id] or ref.endpoints[service.stops[#service.stops].id]
        if (count>1 or count==1 and sharedEnd) and (not bestCount or count>bestCount)then
          chosen,bestCount=pi,count
          -- Two common stations determine direction exactly. With only one,
          -- retain the game's outbound/return orientation relative to the
          -- connected service; don't invent a new downstream extension.
          bestFlip=count>1 and first>last or count==1 and ref.flipped
        end
      end
    end
    assert(chosen,'connected merged service must share a station')
    local service=table.remove(pending,chosen)
    local path,positions={},{}
    for i=1,#service.stops do
      path[i]=service.stops[bestFlip and #service.stops-i+1 or i]
      positions[path[i].id]=i
    end
    paths[#paths+1]={id=service.id,color=service.color,stops=path}
    references[#references+1]={positions=positions,flipped=bestFlip,
      endpoints={[path[1].id]=true,[path[#path].id]=true}}
  end
  local nodes,edges,edgeMap,ordered={},{},{},{}
  for _,source in ipairs(graph.nodes)do if selected[source.id]then
    local node={source=source,id=source.id,incoming={},outgoing={},rank=0}
    nodes[node.id]=node;ordered[#ordered+1]=node
  end end
  local function priority(node)return active[node.id] or (1000000+node.id)end
  local function before(a,b)return priority(a)<priority(b)end
  local displays={}
  for pi,service in ipairs(paths)do
    local path=service.stops
    local visible,last,chain={},nil,{}
    for _,stop in ipairs(path)do
      chain[#chain+1]=stop.id
      if selected[stop.id]then
        visible[#visible+1]=nodes[stop.id]
        if last and last.id~=stop.id then
          local forward,backward={},{}
          for j,id in ipairs(chain)do forward[j]=id;backward[#chain-j+1]=id end
          local f,bk=table.concat(forward,','),table.concat(backward,',')
          local key=f<bk and f or bk
          if not edgeMap[key]then
            local edge={a=last,b=nodes[stop.id],key=key,color=service.color,omitted=#chain-2}
            edgeMap[key]=edge;edges[#edges+1]=edge
            last.outgoing[#last.outgoing+1]=edge;edge.b.incoming[#edge.b.incoming+1]=edge
          end
        end
        last=nodes[stop.id];chain={stop.id}
      end
    end
    displays[#displays+1]=visible
  end
  local ready,done={},{}
  for _,node in ipairs(ordered)do node.pending=#node.incoming;if node.pending==0 then ready[#ready+1]=node end end
  local processed=0
  while processed<#ordered do
    if #ready==0 then
      table.sort(ordered,before)
      for _,node in ipairs(ordered)do if not done[node.id]then
        for _,edge in ipairs(node.incoming)do if not done[edge.a.id]then edge.back=true end end
        node.pending=0;ready[1]=node;break
      end end
    end
    table.sort(ready,before)
    local node=table.remove(ready,1)
    if not done[node.id]then
      done[node.id]=true;processed=processed+1
      for _,edge in ipairs(node.outgoing)do if not edge.back then
        edge.b.rank=math.max(edge.b.rank,node.rank+1)
        edge.b.pending=edge.b.pending-1
        if edge.b.pending==0 then ready[#ready+1]=edge.b end
      end end
    end
  end
  for _,node in ipairs(displays[1])do node.lane=0 end
  local laneIntervals,maxLane={},0
  local function reserve(first,last)
    local lane=1
    while true do
      local clear=true
      for _,range in ipairs(laneIntervals[lane] or {})do if first<=range[2]+1 and last>=range[1]-1 then clear=false;break end end
      if clear then break end
      lane=lane+1
    end
    laneIntervals[lane]=laneIntervals[lane] or {};table.insert(laneIntervals[lane],{first,last})
    maxLane=math.max(maxLane,lane);return lane
  end
  for pi=2,#displays do
    local path=displays[pi];local i=1
    while i<=#path do
      if path[i].lane~=nil then i=i+1 else
        local first=i
        while i<=#path and path[i].lane==nil do i=i+1 end
        local lane
        local anchor=first>1 and path[first-1] or path[i]
        if (first==1 or i>#path) and anchor and anchor.lane==0 then
          local lo,hi=path[first].rank,path[i-1].rank
          local clear=true
          for _,node in ipairs(ordered)do
            if node.lane==0 and node.rank>=lo and node.rank<=hi then clear=false;break end
          end
          if clear then lane=0 end
        end
        lane=lane or reserve(path[math.max(1,first-1)].rank,path[math.min(#path,i)].rank)
        for j=first,i-1 do path[j].lane=lane end
      end
    end
  end
  local defaults=P.defaults(snapshot.lines,aliases)
  local columns,transferLeads,maxRank={},{},0
  local maxName,maxTransfers=0,0
  local nameLimit=math.max(44,math.min(100,math.floor((width-36)/(#ordered+1))))
  local rowLimit=math.max(60,math.min(145,nameLimit+30))
  for _,node in ipairs(ordered)do
    local source=node.source
    local transfers,seen={},{}
    for _,transfer in ipairs(source.transfers)do
      local badge=P.alias(transfer,aliases,defaults);local tm=P.mode(transfer,aliases)
      local key=tm..':'..badge
      if not seen[key]then
        seen[key]=true;transfers[#transfers+1]={id=transfer.id,text=badge,mode=tm,fullName=transfer.name,color=transfer.color}
      end
    end
    local groups,rowWidth,rows,transferHeight=P.transferGroups(transfers,rowLimit)
    local chars=math.max(4,math.floor((nameLimit-4)/14)*2)
    local name,nameRows=P.wrap(P.ellipsize(source.name,chars*2,true),chars,true)
    local nameWidth=math.min(nameLimit,textWidth(name,14,true))
    local endpoint=#node.incoming==0 or #node.outgoing==0 or source.degree==1
    local kind=endpoint and 'terminus' or ((#transfers>0 or source.degree>2) and 'interchange' or 'ordinary')
    local index=active[node.id]
    node.stop={id=node.id,index=index,key='network:'..node.id,name=name,fullName=source.name,nameRows=nameRows,
      nameWidth=nameWidth,rowWidth=rowWidth,transfers=transfers,transferGroups=groups,transferRows=rows,transferHeight=transferHeight,
      endpoint=endpoint,markerKind=kind,markerSize=result.track[kind..'Size'],isNext=node.id==target,
      offRoute=not snapshot.static and index==nil,
      lit=index~=nil and (index<=snapshot.passed or (node.id==target and blink)) or false}
    local col=node.rank+1
    columns[col]=math.max(columns[col] or 0,52,nameWidth*math.cos(math.pi/6)+28,rowWidth+18)
    local lane=node.lane or 0
    transferLeads[lane]=transferLeads[lane] or {}
    transferLeads[lane][col]=math.max(transferLeads[lane][col] or 0,rowWidth+12)
    maxRank=math.max(maxRank,col);maxTransfers=math.max(maxTransfers,transferHeight)
    maxName=math.max(maxName,nameWidth*.5+nameRows*18*math.cos(math.pi/6))
  end
  -- Pack levels around the actual labels/transfers, without an empty row
  -- for a mode that has no transfers. Keep a small clear gap between them.
  local markerClear=math.max(12,result.track.terminusSize/2+4)
  local upperDepth=maxTransfers>0 and (math.max(20,result.track.rail/2+12)+maxTransfers)
    or math.max(result.track.rail,result.track.ordinarySize,result.track.terminusSize)/2
  local laneStep=math.ceil(maxName+markerClear+upperDepth+4)
  -- BULB places a short horizontal / diagonal / horizontal fork beside
  -- its junction. Keep the transition in that junction's adjacent column,
  -- away from the intermediate upper stations and their transfer rows.
  for _,edge in ipairs(edges)do
    local a,b=edge.a,edge.b
    if a.rank>b.rank then a,b=b,a end
    if a.lane~=b.lane then
      local lead=a.lane>b.lane and (a.stop.nameWidth*math.cos(math.pi/6)+12) or (a.stop.rowWidth+12)
      -- Leave a visible horizontal stem at BOTH ends. A twelve-unit tail
      -- makes a right-hand merge appear to end at the diagonal/marker,
      -- unlike the longer left-hand fork drawn in the opposite direction.
      edge.lead=math.max(48,lead)
      edge.tail=48
      if b.rank>a.rank then
        local col=a.lane>b.lane and b.rank or a.rank+1
        edge.transitionCol=col
        local upperLane=math.min(a.lane,b.lane)
        edge.lead=math.max(edge.lead,transferLeads[upperLane] and transferLeads[upperLane][col] or 0)
        local required=edge.lead+edge.tail+math.abs(a.lane-b.lane)*laneStep/math.tan(math.pi/6)
        columns[col]=math.max(columns[col] or 52,required)
      end
    end
  end
  local xs,x={},24
  for col=1,maxRank do xs[col]=x;x=x+(columns[col] or 52)end
  local natural=x+12
  -- Condensation handles ordinary long services. Very large junction groups
  -- can still exceed the viewport; compress columns without dropping branches.
  local margin=0
  for _,node in ipairs(ordered)do
    margin=math.max(margin,node.stop.nameWidth*math.cos(math.pi/6),node.stop.rowWidth,node.stop.markerSize/2)
  end
  local factor=math.max(.01,math.min(1,(width-36-margin)/math.max(1,xs[maxRank]-24)))
  local furthest=0
  for _,node in ipairs(ordered)do
    node.x=24+(xs[node.rank+1]-24)*factor;node.y=(node.lane or 0)*laneStep
    node.stop.x,node.stop.y=node.x,node.y
    node.stop.color=active[node.id] and route.color or nil
    if not node.stop.color then
      for _,edge in ipairs(graph.edges)do if edge.a==node.id or edge.b==node.id then
        node.stop.color=edge.owners[1].color;break
      end end
    end
    result.stops[#result.stops+1]=node.stop
    furthest=math.max(furthest,node.x+node.stop.nameWidth*math.cos(math.pi/6),node.x+node.stop.markerSize/2,node.x-9+node.stop.rowWidth)
  end
  local function segment(a,b,ink,key)
    if math.abs(a.x-b.x)+math.abs(a.y-b.y)<.01 then return end
    result.segments[#result.segments+1]={x1=a.x,y1=a.y,x2=b.x,y2=b.y,color=ink,key=key}
  end
  for _,edge in ipairs(edges)do
    local a,b=edge.a,edge.b
    if a.x>b.x then a,b=b,a end
    local points={{x=a.x,y=a.y}}
    if edge.back or (a.y==b.y and b.rank-a.rank>1 and not(active[a.id] and active[b.id]))then
      maxLane=maxLane+1
      local y=maxLane*laneStep
      local lead=math.min(20,(b.x-a.x)/5)
      points[#points+1]={x=a.x+lead,y=a.y}
      points[#points+1]={x=a.x+2*lead,y=y}
      points[#points+1]={x=b.x-2*lead,y=y}
      points[#points+1]={x=b.x-lead,y=b.y}
    elseif a.y~=b.y then
      local col=edge.transitionCol
      local start=24+(xs[col]-24+edge.lead)*factor
      local finish=24+(xs[col+1]-24-edge.tail)*factor
      points[#points+1]={x=start,y=a.y};points[#points+1]={x=finish,y=b.y}
    end
    points[#points+1]={x=b.x,y=b.y}
    for i=2,#points do segment(points[i-1],points[i],edge.color,edge.key..':'..i)end
    for _,rail in ipairs(P.roundedTrack(points,result.track.rail,edge.color,edge.key))do
      result.rails[#result.rails+1]=rail
    end
    if edge.omitted>0 then
      local a1,b1=points[math.ceil(#points/2)],points[math.ceil(#points/2)+1]
      local caption=tr('… %d站',edge.omitted)
      result.gaps[#result.gaps+1]={x=(a1.x+b1.x)/2,y=(a1.y+b1.y)/2,count=edge.omitted,
        text=caption,labelWidth=textWidth(caption,10,false)+8,key=edge.key}
    end
  end
  result.geometry={left=24,right=24+(xs[maxRank]-24)*factor,width=math.min(width,math.ceil(furthest+12)),fontSize=14}
  result.nameRows,result.transferRows,result.transferHeight=2,0,maxTransfers
  result.laneHeight=maxLane*laneStep
  result.first,result.last=1,#route.stops
  return result
end
return P
