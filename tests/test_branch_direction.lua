local base='mod/content/gui/bulb_cockpit/'
local M,G,P=dofile(base..'model.lua'),dofile(base..'merge.lua'),dofile(base..'native_model.lua')
local function service(id,ids)
  local stops={}
  for i,station in ipairs(ids)do stops[i]={id=station,name=({[1]='旅顺北',[2]='日照',[3]='杭州',[4]='喀什东'})[station],transfers={}}end
  return {id=id,name='线 '..id,color='#006db8',mode='TRAIN',stops=assert(M.servicePath(stops))}
end
local function draw(services,follow,reverse)
  local main=services[follow];local stops={}
  for i=1,#main.stops do stops[i]=main.stops[reverse and #main.stops-i+1 or i]end
  local plan=P.plan({route={lineId=main.id,name=main.name,mode=main.mode,color=main.color,stops=stops},
    lines=services,network=assert(G.build(services)),next=2,passed=1},{},true,1200)
  local byId={};for _,stop in ipairs(plan.stops)do byId[stop.id]=stop end
  return byId,plan
end
-- Both game services start on the same side and return to their own origins.
-- A has 旅顺北–日照–杭州; B has 喀什东–杭州. Shortest distance from
-- the followed origin incorrectly turns B into a continuation after 杭州.
for _,reverse in ipairs({false,true})do
  local byId=draw({service(10,{1,2,3,2}),service(20,{4,3})},1,reverse)
  assert((byId[4].x-byId[3].x)*(byId[1].x-byId[3].x)>0,
    '喀什东 and 旅顺北 must remain on the same side of their common 杭州 terminus')
  assert(byId[4].endpoint and byId[1].endpoint and byId[3].endpoint,'both origins and common end are termini')
  assert(byId[4].y~=byId[1].y,'origin branches must occupy separate lanes')
end
-- Shared station ORDER takes precedence over a separately reversed game's
-- stop array and over unequal path lengths. No opposite-direction duplicate.
for _,follow in ipairs({1,2})do for _,reverse in ipairs({false,true})do
  local byId,plan=draw({service(10,{1,2,3,2}),service(20,{3,2,1,4,1,2})},follow,reverse)
  assert((byId[4].x-byId[1].x)*(byId[3].x-byId[1].x)<0,'喀什东 extends beyond 旅顺北, away from 杭州')
  assert(byId[3].endpoint and byId[4].endpoint and not byId[1].endpoint,'internal service end is not the merged diagram end')
  for _,stop in pairs(byId)do assert(stop.y==0,'nested shuttle is one continuous ordered path')end
end end
print('PASS: same-end forks, reversed shared trunks, actual merged termini and both vehicle directions')
