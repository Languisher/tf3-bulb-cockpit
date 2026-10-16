local base='mod/content/gui/bulb_cockpit/'
local P,S,B=dofile(base..'native_model.lua'),dofile(base..'settings.lua'),dofile(base..'mode_marks.lua')
local lines={{id=1,name='Passenger',mode='TRAIN'},{id=2,name='Ore',mode='TRAIN'},{id=3,name='Grain',mode='TRAIN'}}
local aliases={['2']={name='Ore',displayMode='FREIGHT_TRAIN'},['3']={name='Grain',displayMode='FREIGHT_TRAIN'}}
local d=P.defaults(lines,aliases)
assert(d['1'].shortName=='A' and d['2'].shortName=='72001' and d['3'].shortName=='72002','freight has a separate numeric sequence')
aliases.__defaults=d
local added={id=0,name='New cargo',mode='TRAIN'};aliases['0']={name=added.name,displayMode='FREIGHT_TRAIN'}
local nextDefaults=P.defaults({added},aliases)
assert(nextDefaults['0'].shortName=='72003','discovery order cannot renumber saved lines')
aliases['2'].prefix='F-';aliases['2'].identifier='55001';aliases['2'].suffix=''
assert(P.alias(lines[2],aliases,P.defaults(lines,aliases))=='F-55001','manual number and affixes override the default')
local groups=S.directory(lines,aliases,'',P)
assert(groups[#groups].mode=='FREIGHT_TRAIN' and #groups[#groups].items==2)
assert(#S.list(lines,aliases,'72002','number','name',P,{[3]=true})==1)
local g=B.geometry('FREIGHT_TRAIN',true)
assert(g.shape=='none' and g.width>=48 and P.trackStyle('FREIGHT_TRAIN').rail==P.trackStyle('TRAIN').rail)
-- Persistent defaults resolve racing allocations and retain unrelated choices.
local env=setmetatable({},{__index=_G})
assert(loadfile('mod/content/game_mechanics/bulb_aliases/bulb_aliases.script.lua','t',env))()
local script=env.data();local saved={lines={},options={language='fr',routeMapScale=137},defaults={}}
local writes=0;local state={get=function()return saved end,set=function(_,v)saved=v;writes=writes+1 end}
local function event(value)script.handleEvent({},state,'','linnan.bulb.aliases','linnan.bulb.setDefaults',{defaults=value})end
event(d);assert(saved.defaults['2'].shortName=='72001' and saved.defaults['1'].shortName=='A')
event({['4']={name='Race',mode='FREIGHT_TRAIN',index=1}})
assert(saved.defaults['4'].shortName=='72003')
local before=writes;event(saved.defaults);assert(writes==before and saved.options.language=='fr')
script.handleEvent({},state,'','linnan.bulb.aliases','linnan.bulb.setAlias',{
 lineId=2,name='Ore',displayMode='FREIGHT_TRAIN',shortName='52001',prefix='',identifier='52001',suffix=''})
assert(saved.lines['2'].displayMode=='FREIGHT_TRAIN' and saved.lines['2'].identifier=='52001')
api={type={ComponentType={GAME_SCRIPT=1}},engine={system={gameScriptSystem={getEntityForGameScript=function()return 1 end}},
 getComponent=function()return {state=saved}end},cmd={makeScriptingSendEventCmd=function(_,id,name,param)return {id=id,name=name,param=param}end,
 sendCommand=function(cmd,callback)script.handleEvent({},state,'',cmd.id,cmd.name,cmd.param);callback(nil,true)end}}
local A=dofile(base..'aliases.lua')
A.save(lines[2],'F-55001',function(_,ok)assert(ok)end,'FREIGHT_TRAIN',{prefix='F-',identifier='55001',suffix=''})
A.saveOptions({linePresets={FREIGHT_TRAIN='paris'}},function(_,ok)assert(ok)end)
assert(A.read()['2'].displayMode=='FREIGHT_TRAIN' and saved.options.linePresets.FREIGHT_TRAIN=='paris')
assert(saved.options.language=='fr' and saved.options.routeMapScale==137)
local G=dofile(base..'merge.lua')
local mergeAliases={['1']={name=lines[1].name,identifier='72001',displayMode='TRAIN'},
 ['2']={name=lines[2].name,identifier='72001',displayMode='FREIGHT_TRAIN'},
 ['3']={name=lines[3].name,identifier='72001',displayMode='FREIGHT_TRAIN'}}
local candidates=G.candidates(lines[2],mergeAliases,P)
assert(#candidates==2 and candidates[1]==2 and candidates[2]==3,'freight merges remain isolated from passenger Train')
print('PASS: freight number allocation, stable defaults, manual override, directory, rail filter, track and saved state')
-- Bare number badges paint no colored frame and share the existing train icon.
local builtin={type={ImageViewScaling={Stretch=1}}}
for _,name in ipairs({'ImageView','Component','FloatingLayout','FloatingLayoutChild'})do
 builtin[name]=function(param)return {kind=name,param=param}end
end
local mark=B.create(builtin,function(v)return {styleSheet=v}end,
 function(text,font,w,h,ink)return {kind='TextView',param={text=text,font=font,width=w}}end,
 function()error('must use the dedicated train icon')end)
local function visit(node,fn)
 if type(node)~='table'then return end
 if node.kind then fn(node.kind,node.param)end
 for _,v in pairs(node)do if type(v)=='table'then visit(v,fn)end end
end
for _,small in ipairs({false,true})do
 local images,labels=0,0
 visit(mark('FREIGHT_TRAIN','72001',{1,.8,0,1},small),function(kind,p)
  if kind=='ImageView'then images=images+1;assert(p.path:match('/transilien%-mode.tga$'),'freight paints no badge frame')end
  if kind=='TextView'then labels=labels+1;assert(p.text=='72001' and p.font>=(small and 13 or 23))end
 end)
 assert(images==1 and labels==1)
end
-- The actual collector initializes only freight connections, then reads only
-- the current vehicle on idle ticks. Passenger maps remain unaffected.
local f=dofile('tests/performance_fixture.lua')(base,300,8,3)
local C=f.collect
f.components[100001].TRANSPORT_VEHICLE.config.capacities={0,100}
f.components[100001].TRANSPORT_VEHICLE.stopIndex=2
f.components[100002].TRANSPORT_VEHICLE.config.capacities={0,50}
local chosen={['1']={name=f.components[1].NAME.name,displayMode='FREIGHT_TRAIN'}}
local cache={};f.reset();local value=assert(C.read(f.vehicle,false,nil,cache,chosen))
local found={};for _,line in ipairs(value.lines)do found[line.id]=true end
assert(found[2] and not found[3],'cargo maps include nearby cargo services, excluding passenger-only transfers')
assert(not f.calls.roster and not f.calls.townMap)
f.reset()
for i=1,120 do assert(C.read(f.vehicle,false,nil,cache,chosen)==value)end
assert(f.calls.component==120 and not f.calls.fleet and not f.calls.transfers and not f.calls.roster,'no recurring freight scan')
print('PASS: unframed numbers, reused train pictogram, related cargo transfers and unchanged idle API budget')
local file=assert(io.open('tests/test_native.lua'));local harness=file:read('*a');file:close()
assert(load(harness..[=[
do
 local cargo={id=10,name='Ore freight',mode='TRAIN',color='#ffe077'}
 local other={id=20,name='Freight transfer',mode='TRAIN',color='#006db8'}
 aliases={__options={language='en'},['10']={name=cargo.name,displayMode='FREIGHT_TRAIN'},
   ['20']={name=other.name,displayMode='FREIGHT_TRAIN'}}
 contexts.LinnanBulbBrowserNative={}
 local param={aliases=aliasState,lines={cargo,other},viewport={x=1280,y=720},color=settingsParam.color,onClose=function()end}
 local home=render('LinnanBulbBrowserNative',param)
 local buttons=0
 walk(home,function(kind,p)
  if kind=='Button' and (p.meta.id=='linnan.bulb.browser.line.10' or p.meta.id=='linnan.bulb.browser.line.20')then
   local box=p.meta.styleSheet.size;local inner=p.content.param.meta.styleSheet
   assert(inner.size[1]==48 and box[1]>=58,'wide numeric labels remain inside their clickable tiles')
   assert(box[1]/2-inner.size[1]*inner.anchorPoint[1]>=0)
   buttons=buttons+1
  end
 end)
 assert(buttons==2)
 collect.readLine=function(id)return {static=true,next=0,passed=0,lines={cargo,other},
   route={lineId=id,name=cargo.name,mode='TRAIN',color=cargo.color,stops={
     {id=100,name='Freight yard',transfers={other}},{id=101,name='Harbor',transfers={}}}}}end
 local sp={aliases=aliasState,lines={cargo,other},lineId=10,viewport=param.viewport,geometry=S.geometry(param.viewport),
   color=settingsParam.color,navigate=function()end,home=function()end,onClose=function()end,onReady=function()end}
 contexts.LinnanBulbStaticRouteNative={}
 render('LinnanBulbStaticRouteNative',sp);mounts.LinnanBulbStaticRouteNative();join()
 local map=render('LinnanBulbStaticRouteNative',sp)
 local numbers={}
 walk(map,function(kind,p)
  if kind=='TextView' and (p.meta.class=='bulb-line-badge' or p.meta.class=='bulb-transfer-label')then numbers[p.text]=true end
  if kind=='Component' and p.meta.class=='bulb-mode-mark'then
   walk({kind=kind,param=p},function(child,q)
    if child=='ImageView'then assert(q.path:match('/transilien%-mode.tga$'),'identity has no colored badge frame')end
   end)
  end
 end)
 assert(numbers['72001'] and numbers['72002'])
 unmounts.LinnanBulbStaticRouteNative();unmounts.LinnanBulbBrowserNative()
 print('PASS: freight directory hit bounds and static identity/transfer numbers use the borderless train style')
end
]=],'@freight_train_ui'))()
