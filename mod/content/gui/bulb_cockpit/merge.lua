-- Plain display data only. Explicit station associations never enter this
-- graph: endpoint identity is the real station-group ID, not its name.
local G={}
function G.candidates(main,aliases,P)
  aliases=aliases or {}
  local saved=aliases.__defaults or {}
  local badge,hasBadge=P.alias(main,aliases,P.defaults({main},aliases))
  local mode=P.mode(main,aliases)
  local ids,seen={main.id or main.lineId},{}
  seen[ids[1]]=true
  if not hasBadge then return ids end
  local function consider(key,entry)
    local id=tonumber(key)
    if not id or seen[id] or type(entry)~='table' or type(entry.name)~='string' then return end
    local fallback=saved[key]
    local info={id=id,name=entry.name,mode=fallback and fallback.mode}
    local configured=aliases[key]
    local known=info.mode or (configured and configured.displayMode~='' and configured.displayMode)
    if known and P.mode(info,aliases)~=mode then return end
    local other,exists=P.alias(info,aliases,saved)
    if exists and other==badge then seen[id]=true;ids[#ids+1]=id end
  end
  for key,entry in pairs(aliases)do consider(key,entry)end
  for key,entry in pairs(saved)do consider(key,entry)end
  table.sort(ids)
  return ids
end
function G.build(services)
  if #services<2 then return nil end
  local endpointLines,members={},{}
  for i,service in ipairs(services)do
    local path=service.stops
    if not path or #path==0 then return nil,'环线没有可确认的起终点，未合并。' end
    members[service.id]=true
    for _,id in ipairs({path[1].id,path[#path].id})do
      endpointLines[id]=endpointLines[id] or {};endpointLines[id][i]=true
    end
  end
  local queue,visited={1},{[1]=true}
  for _,index in ipairs(queue)do
    local path=services[index].stops
    for _,id in ipairs({path[1].id,path[#path].id})do
      for other in pairs(endpointLines[id])do
        if not visited[other]then visited[other]=true;queue[#queue+1]=other end
      end
    end
  end
  if #queue~=#services then return nil,'同号线路的实际起终点不连通，未合并；请检查整组线路。' end
  local result={services=services,members=members,nodes={},byId={},edges={}}
  local edges,transferSeen={},{}
  for _,service in ipairs(services)do
    for i,stop in ipairs(service.stops)do
      local node=result.byId[stop.id]
      if not node then
        node={id=stop.id,name=stop.name,transfers={},degree=0}
        result.byId[stop.id]=node;result.nodes[#result.nodes+1]=node;transferSeen[stop.id]={}
      end
      if i==1 or i==#service.stops then node.terminal=true end
      for _,transfer in ipairs(stop.transfers or {})do
        if not members[transfer.id] and not transferSeen[stop.id][transfer.id] then
          transferSeen[stop.id][transfer.id]=true;node.transfers[#node.transfers+1]=transfer
        end
      end
      local previous=service.stops[i-1]
      if previous and previous.id~=stop.id then
        local a,b=math.min(previous.id,stop.id),math.max(previous.id,stop.id)
        local key=a..':'..b
        local edge=edges[key]
        if not edge then
          edge={a=a,b=b,key=key,owners={}};edges[key]=edge;result.edges[#result.edges+1]=edge
          result.byId[a].degree=result.byId[a].degree+1;result.byId[b].degree=result.byId[b].degree+1
        end
        edge.owners[#edge.owners+1]={id=service.id,color=service.color}
      end
    end
  end
  table.sort(result.nodes,function(a,b)return a.id<b.id end)
  table.sort(result.edges,function(a,b)return a.key<b.key end)
  return result
end
return G
