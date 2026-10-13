-- Run the actual HUD through a continuous automatic turnaround, rather than
-- checking the outward and return diagrams only as unrelated static trees.
local harnessFile=assert(io.open('tests/test_native.lua'))
local harness=harnessFile:read('*a');harnessFile:close()
local regression=[=[
local M=dofile('mod/content/gui/bulb_cockpit/model.lua')
local raw={}
for i,id in ipairs({100,200,300,400,300,200})do
  raw[i]={id=id,name='站 '..id,sourceIndex=i-1,transfers=id==300 and
    {{id=9001,name='换乘公交',mode='BUS',color='#00a077'}} or {}}
end
aliases={__options={flashNextStop=true}}
contexts.LinnanBulbCockpitHudNative={}
free.FreeCamTool.push({}, {cockpitCameraForEntity=200})
render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}})
local function setJourney(mode,stopIndex,atTerminal)
  local journey=M.journey(raw,stopIndex,atTerminal)
  snapshot={vehicle=200,stopIndex=stopIndex,atTerminal=atTerminal,next=journey.next,passed=journey.passed,
    route={lineId=8000,name='折返测试 '..mode,mode=mode,color='#006db8',stops=journey.stops}}
end
local function shown()
  return render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}})
end
local function lamp(tree,name)
  local found
  walk(tree,function(kind,p)
    if kind=='Component' and p.meta.class=='bulb-station-marker' and p.meta.tooltip==name then
      walk(p,function(k,image)if (k=='ImageView' or k=='Component') and image.meta.class=='bulb-station-light'then found=image end end)
    end
  end)
  return found
end
local exported={}
for _,mode in ipairs({'METRO','RER','TRAM'})do
  setJourney(mode,3,false);tick();shown()
  -- If the arriving leg was in its ON phase, a plain boolean toggle puts
  -- the newly selected return target straight into OFF. It needs its own
  -- fresh flash cycle, not the phase inherited from the previous target.
  contexts.LinnanBulbCockpitHudNative[2]:set(true)
  setJourney(mode,3,true);tick()
  local on=shown()
  assert(snapshot.route.stops[1].id==400 and snapshot.route.stops[2].id==300
    and snapshot.next==2 and snapshot.passed==1,'turn at D: D is passed; C is next')
  assert(lamp(on,'站 300'),'automatic turnaround must start the new next station in its yellow ON phase')
  setJourney(mode,4,false);tick();local off=shown()
  assert(not lamp(off,'站 300') and not lamp(off,'站 400'),'return departure: C flashes OFF; the departed D stays off')
  tick();on=shown()
  assert(lamp(on,'站 300'),'return target must turn yellow again on the next tick')
  local markerKeys,layerKeys={},{}
  walk(on,function(kind,p)
    if kind=='Component' and p.meta.class=='bulb-station-marker'then
      assert(type(p.meta.localKey)=='string' and not markerKeys[p.meta.localKey],
        'each stop occurrence must retain a unique native identity after reversal')
      markerKeys[p.meta.localKey]=true
      for _,child in ipairs(p.layout.param.children)do
        local image=child.param.item.param
        assert(child.param.localKey and image.meta.localKey and not layerKeys[image.meta.localKey],
          'station outline/interior/lamp identities must not be recycled between different stops')
        layerKeys[image.meta.localKey]=true
      end
    end
  end)
  exported[#exported+1]={mode=mode,phase='on',scenario='shuttle',tree=on}
  exported[#exported+1]={mode=mode,phase='off',scenario='shuttle',tree=off}
  setJourney(mode,0,false);tick();shown()
  contexts.LinnanBulbCockpitHudNative[2]:set(true)
  setJourney(mode,0,true);tick()
  assert(snapshot.route.stops[1].id==100 and lamp(shown(),'站 200'),
    'turn at A: A is passed; B starts a new flash cycle too')
  setJourney(mode,1,false);tick();assert(not lamp(shown(),'站 200'))
  tick();assert(lamp(shown(),'站 200'))
end
-- With only two stops, the next stop itself is another framed terminus.
-- Check both ends continuously, including its colored core in OFF and ON.
raw={{id=100,name='站 100',sourceIndex=0,transfers={}},
  {id=400,name='站 400',sourceIndex=1,transfers={}}}
for _,mode in ipairs({'METRO','RER','TRAM'})do
  for _,endIndex in ipairs({1,0})do
    setJourney(mode,endIndex,false);tick();shown()
    contexts.LinnanBulbCockpitHudNative[2]:set(true)
    setJourney(mode,endIndex,true);tick();local on=shown()
    local origin=endIndex==1 and '站 400' or '站 100'
    local target=endIndex==1 and '站 100' or '站 400'
    assert(snapshot.next==2 and snapshot.passed==1 and not lamp(on,origin) and lamp(on,target),
      'two-stop turnaround starts its new terminus target lit')
    setJourney(mode,(endIndex+1)%2,false);tick();local off=shown()
    assert(not lamp(off,origin) and not lamp(off,target),'two-stop departure continues flashing with origin off')
    tick();assert(lamp(shown(),target),'two-stop terminus target lights again')
    if endIndex==1 then
      exported[#exported+1]={mode=mode,phase='on',scenario='two-stop',tree=on}
      exported[#exported+1]={mode=mode,phase='off',scenario='two-stop',tree=off}
    end
  end
end
-- Exact A-B-C-D case: only B blinks, future C/D stay yellow in both phases.
raw={}
for i,id in ipairs({100,200,300,400})do raw[i]={id=id,name='站 '..id,sourceIndex=i-1,transfers={}}end
for _,mode in ipairs({'METRO','RER','TRAM'})do
  setJourney(mode,0,false);tick();shown()
  setJourney(mode,1,false);tick();local on=shown()
  assert(not lamp(on,'站 100') and lamp(on,'站 200') and lamp(on,'站 300') and lamp(on,'站 400'),
    'A is off; B, C and terminal D start yellow')
  tick();local off=shown()
  assert(not lamp(off,'站 100') and not lamp(off,'站 200') and lamp(off,'站 300') and lamp(off,'站 400'),
    'only B turns off; C and terminal D remain steady yellow')
  walk(off,function(kind,p)
    if kind=='Component' and p.meta.class=='bulb-station-marker' and p.meta.tooltip=='站 400'then
      walk(p,function(k,image)
        if k=='ImageView' and image.path:match('/station%-interior.tga$')then
          assert(image.meta.styleSheet.color[2]==.82,'future terminal yellow covers its complete interior too')
        end
      end)
    end
  end)
end
-- Optional offline pixel QA export; never runs in the game.
if arg[1]then
  local function json(value)
    if type(value)=='string'then return '"'..value:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n')..'"'end
    if type(value)=='number' or type(value)=='boolean'then return tostring(value)end
    if type(value)~='table'then return 'null'end
    local parts={}
    if #value>0 then
      for _,v in ipairs(value)do parts[#parts+1]=json(v)end
      return '['..table.concat(parts,',')..']'
    end
    for k,v in pairs(value)do if type(v)~='function'then parts[#parts+1]=json(tostring(k))..':'..json(v)end end
    return '{'..table.concat(parts,',')..'}'
  end
  local file=assert(io.open(arg[1],'w'));file:write(json(exported));file:close()
end
print('PASS: automatic turnarounds at both ends of four- and two-stop routes; new-target flash restart; repeated return blinking; stable native station/layer identities')
]=]
assert(load(harness..regression,'turnaround-regression'))()
