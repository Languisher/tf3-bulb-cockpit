local base='mod/content/gui/bulb_cockpit/'
local M=dofile(base..'model.lua')
local G=dofile(base..'merge.lua')
local P=dofile(base..'native_model.lua')
local function service(id,path,color)
  local stops={};for i,station in ipairs(path)do stops[i]={id=station,name='车站 '..station,sourceIndex=i-1,transfers={}}end
  return {id=id,name='线路 '..id,mode='TRAIN',color=color or '#006db8',stops=M.servicePath(stops)}
end
local function plan(services,active,nextIndex,width)
  local graph=assert(G.build(services))
  local route=services[active]
  local snapshot={route={lineId=route.id,name=route.name,mode=route.mode,color=route.color,stops=route.stops},
    network=graph,lines=services,next=nextIndex,passed=nextIndex-1}
  return P.plan(snapshot,{},true,width or 1200),snapshot
end
local fork,snap=plan({service(1,{1,2,3,2}),service(2,{1,2,4,2},'#cc0000')},1,2)
assert(fork.segments and #fork.segments>3, 'fork must have horizontal leads and diagonal exits')
assert(#fork.stops==4, 'shared station is drawn once')
local seen,ys={},{}
for _,stop in ipairs(fork.stops)do
  assert(not seen[stop.id]);seen[stop.id]=true;ys[stop.id]=stop.y
  assert(stop.lit==(stop.id==snap.route.stops[1].id or stop.id==snap.route.stops[2].id))
end
assert(ys[3]~=ys[4], 'fork termini occupy different levels')
local colors={};for _,segment in ipairs(fork.segments)do colors[segment.color]=true end
assert(colors['#006db8'] and colors['#cc0000'], 'branch colors come from their actual game lines')
local parallel=plan({service(1,{1,2,3,2}),service(2,{1,4,3,4})},1,2)
local byId={};for _,stop in ipairs(parallel.stops)do byId[stop.id]=stop end
assert(byId[2].y~=byId[4].y, 'parallel branches must diverge and reconverge')
assert(byId[1] and byId[3] and #parallel.stops==4)
assert(byId[1].endpoint and byId[3].endpoint, 'parallel alternatives preserve their two common termini')
for _,p in ipairs({fork,parallel})do
  local maxName,maxTransfers=0,0
  for _,stop in ipairs(p.stops)do
    maxName=math.max(maxName,stop.nameWidth*.5+stop.nameRows*18*math.cos(math.pi/6))
    maxTransfers=math.max(maxTransfers,stop.transferHeight)
  end
  assert(p.laneHeight<=math.ceil(maxName+maxTransfers+50)-12,
    'two-lane diagrams must remove the old excess vertical padding')
  for _,segment in ipairs(p.segments)do if segment.y1~=segment.y2 then
    assert(math.abs(segment.y2-segment.y1)<=math.abs(segment.x2-segment.x1)*.60,
      'uncompressed BULB fork should have a shallow diagonal, not an almost vertical join')
  end end
end
-- A short branch sharing the far endpoint must join beside that endpoint,
-- rather than sweep diagonally through the long branch's transfer rows.
local a,b=service(1,{1,2,3,4,3,2}),service(2,{5,4})
for _,stop in ipairs(a.stops)do if stop.id==3 then
  stop.transfers={{id=100,name='T1',mode='TRAM',color='#aa0099'},
    {id=101,name='1001',mode='BUS',color='#0099aa'}}
end end
for _,reverse in ipairs({false,true})do
  if reverse then
    for _,line in ipairs({a,b})do
      local reversed={};for i=1,#line.stops do reversed[i]=line.stops[#line.stops-i+1]end
      line.stops=reversed
    end
  end
  local p=plan({a,b},1,2)
  local obstacle;for _,stop in ipairs(p.stops)do if stop.id==3 then obstacle=stop end end
  for _,segment in ipairs(p.segments)do if segment.y1~=segment.y2 then
    if segment.y1>segment.y2 then
      assert(segment.x1>=obstacle.x-9+obstacle.rowWidth+8,
        'joining diagonal must clear the last upper station transfer row')
    else
      assert(segment.x2<=obstacle.x-12,
        'forking diagonal must finish before the first upper station transfer row')
    end
  end end
end
local longerParallel=plan({service(1,{1,2,3,9,3,2}),service(2,{1,5,6,9,6,5})},1,3)
local ends=0
for _,stop in ipairs(longerParallel.stops)do if stop.endpoint then ends=ends+1 end end
assert(ends==2, 'an alternative path is not an upstream serial extension')
for _,segment in ipairs(longerParallel.segments)do
  if segment.y1>segment.y2 then
    for _,stop in ipairs(longerParallel.stops)do
      if stop.y==segment.y1 and stop.x<=segment.x1 and segment.x1-stop.x<150 then
        assert(segment.x1-stop.x>=stop.nameWidth*math.cos(math.pi/6)+8, 'upward join must clear the preceding rotated station name')
      end
    end
  end
end
local transitive=plan({service(1,{1,2}),service(2,{2,3}),service(3,{3,4})},1,2)
assert(#transitive.stops==4 and transitive.geometry.width<=1200)
for _,stop in ipairs(transitive.stops)do assert(stop.y==0, 'serially connected services are a straight line')end
local middle=plan({service(1,{1,2}),service(2,{2,3}),service(3,{3,4})},2,2)
for _,stop in ipairs(middle.stops)do assert(stop.y==0, 'a followed middle service keeps upstream and downstream extensions on one level')end
local cycle=plan({service(1,{1,2}),service(2,{2,3}),service(3,{3,1})},1,2)
assert(#cycle.stops==3 and #cycle.segments>=3)
local longA,longB={},{}
for i=1,61 do longA[#longA+1]=i;longB[#longB+1]=i==1 and 1 or i==61 and 61 or i+100 end
for i=60,2,-1 do longA[#longA+1]=i;longB[#longB+1]=i+100 end
local long,snapshot=plan({service(1,longA),service(2,longB)},1,30,800)
assert(long.geometry.width<=800 and #long.gaps>0, 'long branches condense with omission labels')
assert(#long.stops<30, 'bounded visible labels for long services')
local target=snapshot.route.stops[30].id
local nextCount=0
for _,stop in ipairs(long.stops)do if stop.isNext then assert(stop.id==target);nextCount=nextCount+1 end end
assert(nextCount==1, 'one actual current-vehicle lamp; other branches never pretend to be next')
for _,width in ipairs({272,640,800,1200,1600})do
  local p=plan({service(1,longA),service(2,longB)},1,30,width)
  for _,stop in ipairs(p.stops)do
    assert(stop.x+stop.nameWidth*math.cos(math.pi/6)+1<=p.geometry.width, 'station label must remain inside canvas')
    assert(stop.x-9+stop.rowWidth<=p.geometry.width, 'transfer row must remain inside canvas')
  end
  for _,segment in ipairs(p.segments)do
    assert(segment.x1>=0 and segment.x2>=0 and segment.x1<=width and segment.x2<=width)
  end
end
print('PASS: fork and parallel geometry, shared-station deduplication, game colors, current-branch lamps and long-line condensation')
