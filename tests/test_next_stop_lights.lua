local base='mod/content/gui/bulb_cockpit/'
local P=dofile(base..'native_model.lua')
local M=dofile(base..'model.lua')
local G=dofile(base..'merge.lua')
local function service(id,path,mode)
  local stops={}
  for i,station in ipairs(path)do
    stops[i]={id=station,name='Stop '..station,sourceIndex=i-1,transfers={}}
  end
  return {id=id,lineId=id,name='Line '..id,mode=mode,color='#006db8',stops=stops}
end
local function check(snapshot,width)
  for _,on in ipairs({false,true})do
    local plan=P.plan(snapshot,{},on,width)
    local count=0
    local target=snapshot.route.stops[snapshot.next]
    for _,stop in ipairs(plan.stops)do
      local index=stop.index
      local expected=target~=nil and index~=nil and (index>snapshot.next or index==snapshot.next and on)
      assert(stop.lit==expected,
        'future served stops stay yellow; only next follows the phase; passed and other-branch stops stay off')
      if stop.lit then count=count+1 end
    end
    if not target then assert(count==0,'no lights after completion')end
  end
end
for _,mode in ipairs({'METRO','RER','TRAM','BUS'})do
  local line=service(10,{1,2,3,4,5,6,7,8},mode)
  for _,width in ipairs({320,1280})do
    -- Jump past intermediate stops: their future lights must turn off immediately.
    for _,nextStop in ipairs({1,2,6,8,0})do
      check({route=line,next=nextStop,passed=nextStop>0 and nextStop-1 or 8},width)
    end
  end
  local raw=service(10,{1,2,3,4,3,2},mode)
  for stopIndex=0,5 do for _,atTerminal in ipairs({false,true})do
    local journey=assert(M.journey(raw.stops,stopIndex,atTerminal))
    check({route={lineId=10,name=line.name,mode=mode,stops=journey.stops},
      next=journey.next,passed=journey.passed},1280)
  end end
  local branch=service(20,{9,10,8},mode)
  local graph=assert(G.build({line,branch}))
  for _,member in ipairs({line,branch})do
    for _,reverse in ipairs({false,true})do
      local route=service(member.id,{},mode)
      for i=1,#member.stops do route.stops[i]=member.stops[reverse and #member.stops-i+1 or i]end
      for _,nextStop in ipairs({2,#route.stops,0})do
        check({route=route,network=graph,lines={line,branch},next=nextStop,
          passed=nextStop>0 and nextStop-1 or #route.stops},640)
      end
    end
  end
end
local one=service(10,{1},'RER')
local arrived=M.journey(one.stops,0,true)
check({route=one,next=arrived.next,passed=arrived.passed},1280)
print('PASS: future steady lamps and next-stop blinking; skips, completion, condensation, turnarounds and fork members')

-- User's exact A-B-C-D example in both animation phases.
local abcd=service(10,{1,2,3,4},'RER')
for _,on in ipairs({false,true})do
  local plan=P.plan({route=abcd,next=2,passed=1},{},on,1280)
  assert(not plan.stops[1].lit and plan.stops[2].lit==on and plan.stops[3].lit and plan.stops[4].lit,
    'A off; B blinks; C and terminus D are steady yellow')
end
