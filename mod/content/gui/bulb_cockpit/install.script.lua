local react = ug_require '::/gui/main/react.lua'
local builtin = ug_require '::/gui/main/builtin.lua'
local free = ug_require '::/gui/main/free_cam_options.tl'
local styleutil = ug_require '::/gui/main/styleutil.tl'
local collect = ug_require 'linnan_bulb_cockpit::/gui/bulb_cockpit/collect.lua'
local P = ug_require 'linnan_bulb_cockpit::/gui/bulb_cockpit/native_model.lua'
local I = ug_require 'linnan_bulb_cockpit::/gui/bulb_cockpit/localization.lua'
local modeMarks = ug_require 'linnan_bulb_cockpit::/gui/bulb_cockpit/mode_marks.lua'
local diagnostic = ug_require 'linnan_bulb_cockpit::/gui/bulb_cockpit/diagnostics.lua'
local cameraState = ug_require 'linnan_bulb_cockpit::/gui/bulb_cockpit/camera_state.lua'
local aliasStore = ug_require 'linnan_bulb_cockpit::/gui/bulb_cockpit/aliases.lua'
local settingsUI = ug_require 'linnan_bulb_cockpit::/gui/bulb_cockpit/settings.lua'
local cityUI = ug_require 'linnan_bulb_cockpit::/gui/bulb_cockpit/city_settings.lua'
local stationUI = ug_require 'linnan_bulb_cockpit::/gui/bulb_cockpit/station_settings.lua'
local windows = ug_require '::/gui/main/game_react_globals.tl'
local BLUE = {0.137,0.247,0.569,1}
local HUD_INK = {0.94,0.97,1,1}
local SMOKE = {0.035,0.055,0.08,0.88}
local CONNECTOR = {0.66,0.76,0.87,0.9}
local hudVisibility
local function setHudVisible(visible)
  if hudVisibility==visible then return end
  -- The native component may already be unmounted during game teardown.
  local ok=pcall(function()api.gui.byId.setVisible('linnan.bulb.hud',visible)end)
  if ok then hudVisibility=visible end
end
-- BULB declares Parisine Ptf 700 for station names and 600 for indices
-- (resolved to its 700 face). TF3 exposes predefined font weights rather
-- than a per-label fontFamily. Use its normal locale font and match the
-- weight explicitly; this is not the proprietary Parisine typeface.
local boldLabels={['bulb-station-name']=true,['bulb-station-terminus-name']=true,['bulb-line-badge']=true,['bulb-transfer-label']=true,['bulb-mode-letter']=true,['bulb-route-title']=true}
local function style(value) return {styleSheet=styleutil.makeStyle(value)} end
local function color(hex)
  if type(hex)~='string' or not hex:match('^#%x%x%x%x%x%x$') then return BLUE end
  return {tonumber(hex:sub(2,3),16)/255,tonumber(hex:sub(4,5),16)/255,tonumber(hex:sub(6,7),16)/255,1}
end
local function text(value,size,width,height,ink,fill,class,anchor,tooltip)
  local rounded=class=='bulb-station-name' or class=='bulb-omission-label'
  local meta=style{fontSize=size,fontWeight=boldLabels[class] and 'Bold' or 'Regular',
    size={width,height},color=ink or BLUE,
    backgroundColor=not rounded and fill or nil,backgroundColor1=rounded and fill or nil,
    anchorPoint=anchor or {0,0},padding={0,0,0,0},margin={0,0,0,0}}
  meta.class=class
  meta.tooltip=tooltip
  -- Match native UI font selection, including the locale's CJK Bold face.
  -- The language selector's Unicode compatibility font bypasses this path.
  return builtin.TextView{text=value,useUnicodeCompatibilityFont=false,
    meta=meta}
end
local function positioned(children,item,x,y,w,h,key)
  children[#children+1]=builtin.FloatingLayoutChild{h=x/w,v=y/h,item=item,localKey=key}
end
local function rectangle(w,h,fill,class)
  local masked=class=='bulb-track' or class=='bulb-track-stripe'
  local meta=style{size={w,h},backgroundColor=not masked and fill or nil,
    backgroundColor1=masked and fill or nil,anchorPoint={0,0}}
  meta.class=class
  return builtin.Component{meta=meta}
end
local modeNames={METRO='地铁',RER='RER',TRAIN='RER',TRAM='电车',BUS='公交',BOAT='轮渡',AIR='航空',TRUCK='货运'}
local modeIcons={TRAIN='::/gui/statistics/icons/vehicle_train_18.tga',
  TRAM='::/gui/statistics/icons/vehicle_tram_18.tga',BUS='::/gui/statistics/icons/vehicle_bus_18.tga',
  BOAT='::/gui/statistics/icons/vehicle_ship_18.tga',AIR='::/gui/statistics/icons/vehicle_airplane_18.tga',
  TRUCK='::/gui/construction/menu/filter_categories/truck.tga'}
local function modeIcon(mode,size)
  return builtin.ImageView{path=modeIcons[mode] or modeIcons.TRAIN,
    scaling=builtin.type.ImageViewScaling.Stretch,meta=style{size={size,size},color=HUD_INK,anchorPoint={0,0}}}
end
local modeMark,transferGroup,lineBadge=modeMarks.create(builtin,style,text,modeIcon,
  {symbolInk=HUD_INK,openBadgeInk=HUD_INK})
-- Custom recipes own native components just like builtin.Component. Give
-- the transform banks exclusive element types so the engine need not match
-- 280 BULB rules against every generic component in the game's interface.
local TrackStroke=react.RegisterRecipe('LinnanBulbTrackStrokeNative',function()
  return builtin.FloatingLayout{children={}}
end)
local ScaledCanvas=react.RegisterRecipe('LinnanBulbScaledCanvasNative',function(param)
  return builtin.FloatingLayout{meta={class='bulb-fixed-layout'},children=param.children}
end)
local function floatingPanel(width,height,children,id,anchor,class,mouseTransparent,recipe)
  local meta=style{size={width,height},backgroundColor={0,0,0,0},anchorPoint=anchor or {0,0},
    padding={0,0,0,0},margin={0,0,0,0}}
  meta.id=id
  meta.class=class
  -- The parent may offer more space (notably ScrollArea). A transparent
  -- measured child reserves the full coordinate extent, including offsets;
  -- a class-only layout remains a native Layout without Component metadata.
  local extent=style{size={width,height},anchorPoint={0,0},backgroundColor={0,0,0,0}}
  extent.class='bulb-layout-extent'
  table.insert(children,1,builtin.FloatingLayoutChild{h=0,v=0,
    item=builtin.Component{meta=extent,mouseTransparent=true}})
  if recipe then return recipe{meta=meta,children=children}end
  return builtin.Component{meta=meta,mouseTransparent=mouseTransparent,
    layout=builtin.FloatingLayout{meta={class='bulb-fixed-layout'},children=children}}
end
local function stationMarker(stop,track,lineColor)
  local diameter=stop.markerSize
  local children={}
  local function disc(size,ink,class,role,mask)
    local meta=style{size={size,size},color=ink,anchorPoint={.5,.5},padding={0,0,0,0},margin={0,0,0,0}}
    meta.class=class
    meta.localKey=stop.key..':'..role..':image'
    local image=builtin.ImageView{path='linnan_bulb_cockpit::/gui/bulb_cockpit/symbols/'..(mask or 'circle')..'.tga',
      scaling=builtin.type.ImageViewScaling.Stretch,meta=meta}
    positioned(children,image,diameter/2,diameter/2,diameter,diameter,stop.key..':'..role..':position')
  end
  local white,yellow={1,1,1,1},{1,.82,0,1}
  -- Alternative branches remain visible but are not stops on this vehicle's
  -- service. Their interior stays white, including colored terminus cores.
  local lit=stop.lit and not stop.offRoute
  local flashingTerminus=stop.markerKind=='terminus' and stop.flashing==true and not stop.offRoute
  local stateClass=lit and 'bulb-station-light' or 'bulb-station-fill'
  if stop.markerKind=='ordinary'then
    disc(diameter,lit and yellow or ((stop.offRoute or track.ordinaryFill=='white') and white or lineColor),stateClass,'core')
  else
    local border=diameter*.10
    -- Transparent centers keep the rim and terminus ring from covering the
    -- lamp, independently of the order in which these layers are painted.
    disc(diameter,{0,0,0,1},'bulb-station-outline','outline','station-outline')
    disc(diameter-2*border,(stop.markerKind=='interchange' or flashingTerminus) and lit and yellow or white,
      stop.markerKind=='interchange' and stateClass or 'bulb-station-interior','interior',
      stop.markerKind=='terminus' and 'station-interior' or 'circle')
    if stop.markerKind=='terminus'then
      disc(diameter*.42,lit and yellow or (stop.offRoute and white or
        (flashingTerminus and {0.035,0.055,0.08,1} or lineColor)),stateClass,'core')
    end
  end
  local meta=style{size={diameter,diameter},anchorPoint={.5,.5},backgroundColor={0,0,0,0},
    padding={0,0,0,0},margin={0,0,0,0}}
  meta.class='bulb-station-marker';meta.tooltip=stop.fullName
  meta.localKey=stop.key..':marker'
  return builtin.Component{meta=meta,layout=builtin.FloatingLayout{children=children}}
end
-- Only the next station owns an animation state. Its timer redraws this small
-- marker, without invalidating station names, transfers or the route layout.
-- A direction/target-specific localKey remounts it in the ON phase.
local FlashingStation=react.RegisterRecipe('LinnanBulbFlashingStationNative',function(param)
  local on=react.useState(true)
  react.onStepTimer(function()
    if not on:hasExpired() and cameraState.getEntity()==param.vehicle then on:set(not on:old())end
  end,0.5,false)
  local stop={};for k,v in pairs(param.stop)do stop[k]=v end
  stop.lit=on:old();stop.flashing=true
  return builtin.FloatingLayout{children={builtin.FloatingLayoutChild{h=.5,v=.5,
    item=stationMarker(stop,param.track,param.lineColor)}}}
end)
local function panel(width,height,layout,id,transparent)
  local meta=style{size={width,height},backgroundColor={1,1,1,transparent and 0 or 1}}
  meta.id=id
  -- A recipe returns a layout; a ScrollArea receives a component. Styles
  -- belong to that component, not the layout that arranges its children.
  return builtin.BoxLayout{children={builtin.Component{meta=meta,layout=layout}}}
end

-- HUD and static browser share the exact station/track/transfer renderer.
-- The static caller owns its component tree; no canvas or generated image is
-- cached by this function. Interactive badges carry IDs, never old snapshots.
local function diagramChildren(snapshot,plan,onTransfer,renderMarker,tr)
  local g=plan.geometry
  local width=g.width
  local lineColor=color(snapshot.route.color)
  -- A -30 degree label reaches upward by half its width plus the rotated
  -- text height. Reserve that space before positioning the station rail.
  local nameArea=0
  for _,stop in ipairs(plan.stops) do
    nameArea=math.max(nameArea,stop.nameWidth*0.5+stop.nameRows*(g.fontSize+4)*math.cos(math.pi/6))
  end
  nameArea=math.ceil(nameArea)+8
  local railY=math.max(58,nameArea+6)
  local transferY=railY+math.max(20,plan.track.rail/2+12)
  local height=transferY+plan.transferHeight+(plan.laneHeight or 0)+(snapshot.mergeWarning and 24 or 0)+8
  local children={}
  local count=#plan.stops
  local left,right=g.left,g.right
  if plan.segments then
    -- Rotation is a supported stylesheet property, but is not exposed by the
    -- per-component StyleSheet API. Use fixed CSS angle classes (one degree)
    -- and existing geometry masks, never generated textures or new timers.
    local caps={}
    local function stroke(segment,thickness,ink,suffix)
      local a,b={x=segment.x1,y=segment.y1},{x=segment.x2,y=segment.y2}
      if a.x>b.x then a,b=b,a end
      local dx,dy=b.x-a.x,b.y-a.y
      -- LuaJIT's atan ignores a second argument. TF3's own vector helpers
      -- use atan2; retain a single-argument fallback for development Lua.
      local radians=math.atan2 and math.atan2(dy,dx)
        or (dx==0 and (dy>=0 and math.pi/2 or -math.pi/2) or math.atan(dy/dx))
      local angle=math.floor(math.deg(radians)+.5)
      local length=math.sqrt(dx*dx+dy*dy)
      local meta=style{size={length,thickness},backgroundColor1=ink,anchorPoint={0,.5}}
      meta.class='bulb-branch-stroke, bulb-track-angle'..(angle+90)
      positioned(children,TrackStroke{meta=meta},a.x,railY+a.y,width,height,segment.key..suffix)
      for i,point in ipairs({a,b})do
        local capKey=string.format('%s:%s:%.5f:%.5f',suffix,segment.color,point.x,point.y)
        if not caps[capKey]then
          caps[capKey]=true
          local meta=style{size={thickness,thickness},color=ink,anchorPoint={.5,.5}}
          meta.class='bulb-track-cap'
          local cap=builtin.ImageView{path='linnan_bulb_cockpit::/gui/bulb_cockpit/symbols/circle.tga',
            scaling=builtin.type.ImageViewScaling.Stretch,meta=meta}
          positioned(children,cap,point.x,railY+point.y,width,height,segment.key..suffix..':cap'..i)
        end
      end
    end
    for _,segment in ipairs(plan.rails)do stroke(segment,plan.track.rail,color(segment.color),':rail')end
    if plan.track.stripe>0 then
      for _,segment in ipairs(plan.rails)do
        local c=color(segment.color)
        stroke(segment,plan.track.stripe,{c[1]*.45+.55,c[2]*.45+.55,c[3]*.45+.55,1},':stripe')
      end
    end
    -- Keep dynamically attached/replaced strokes and caps inside one stable
    -- background sibling. Reconciliation must never attach a new rail above
    -- an existing station marker in the outer floating layout.
    local tracks=children
    children={}
    positioned(children,floatingPanel(width,height,tracks,nil,{0,0},'bulb-track-layer',true),
      0,0,width,height,'linnan.bulb.track-layer')
  elseif count>1 then
    positioned(children,rectangle(right-left,plan.track.rail,lineColor,'bulb-track'),left,railY-plan.track.rail/2,width,height)
    local caps={}
    local function endCaps(thickness,ink,suffix)
      for i,x in ipairs({left,right})do
        local meta=style{size={thickness,thickness},color=ink,anchorPoint={.5,.5}}
        meta.class='bulb-track-cap'
        positioned(caps,builtin.ImageView{path='linnan_bulb_cockpit::/gui/bulb_cockpit/symbols/circle.tga',
          scaling=builtin.type.ImageViewScaling.Stretch,meta=meta},x,railY,width,height,'track'..suffix..':cap'..i)
      end
    end
    endCaps(plan.track.rail,lineColor,':rail')
    if plan.track.stripe>0 then
      local stripe={lineColor[1]*.45+.55,lineColor[2]*.45+.55,lineColor[3]*.45+.55,1}
      positioned(children,rectangle(right-left,plan.track.stripe,stripe,'bulb-track-stripe'),
        left,railY-plan.track.stripe/2,width,height)
      endCaps(plan.track.stripe,stripe,':stripe')
    end
    -- Share the stable background parent with merged diagrams so a newly
    -- attached cap cannot paint above an already-mounted station marker.
    positioned(children,floatingPanel(width,height,caps,nil,{0,0},'bulb-track-layer',true),
      0,0,width,height,'linnan.bulb.track-layer')
  end
  for _,gap in ipairs(plan.gaps)do
    local tooltip=gap.first and tr('省略 %d 站（第 %d–%d 站）',gap.count,gap.first,gap.last)
      or tr('该支线省略 %d 站',gap.count)
    local mark=text(gap.text,10,gap.labelWidth,18,HUD_INK,nil,'bulb-omission-label',{.5,.5},tooltip)
    positioned(children,mark,gap.x,railY+(gap.y or 0),width,height,
      'linnan.bulb.omission.'..(gap.key or gap.first..':'..gap.last))
  end
  for _,stop in ipairs(plan.stops) do
    local x=stop.x
    local stopRailY=railY+(stop.y or 0)
    local stopTransferY=transferY+(stop.y or 0)
    local stopColor=color(stop.color or snapshot.route.color)
    positioned(children,text(stop.name,g.fontSize,stop.nameWidth,stop.nameRows*(g.fontSize+4),
      HUD_INK,stop.endpoint and BLUE or SMOKE,
      stop.endpoint and 'bulb-station-terminus-name' or 'bulb-station-name',{0,1},stop.fullName),x,stopRailY-math.max(12,stop.markerSize/2+4),width,height)
    local marker
    if renderMarker then marker=renderMarker(stop,stopColor)end
    marker=marker or stationMarker(stop,plan.track,stopColor)
    positioned(children,marker,x,stopRailY,width,height,stop.key..':marker-position')
    if #stop.transferGroups>0 then
      local start=stopRailY+math.max(plan.track.rail,stop.markerSize)/2+2
      positioned(children,rectangle(1,stopTransferY-start,CONNECTOR),x-0.5,start,width,height)
    end
    local y=stopTransferY
    local previousIconBottom
    for _,group in ipairs(stop.transferGroups) do
      local badgeRows={}
      for _,row in ipairs(group.rows)do
        local badges={}
        for _,transfer in ipairs(row.lines)do
          local id=transfer.id
          badges[#badges+1]={text=transfer.text,fullName=transfer.fullName,fill=color(transfer.color),
            onClick=onTransfer and id and function()onTransfer(id)end or nil}
        end
        badgeRows[#badgeRows+1]={lines=badges,y=row.y}
      end
      local transferMark=transferGroup(group.mode,badgeRows)
      local iconSize=modeMarks.geometry(group.mode,true).icon
      local iconTop=y+(24-iconSize)/2
      if previousIconBottom then
        local start=previousIconBottom+2
        positioned(children,rectangle(1,iconTop-2-start,CONNECTOR),x-0.5,start,width,height)
      end
      -- Only the shared mode icon is centered on the station's connector.
      positioned(children,transferMark,x-iconSize/2,y,width,height)
      previousIconBottom=iconTop+iconSize
      y=y+group.height+4
    end
  end
  if snapshot.mergeWarning then
    positioned(children,text(tr('同号线路未合并 · 端点不连通或为环线'),12,width-24,20,HUD_INK,nil,
      'bulb-omission-label',nil,tr(snapshot.mergeWarning)),12,height-22,width,height,'linnan.bulb.merge-warning')
  end
  return children,width,height
end
local function staticDiagram(snapshot,aliases,onTransfer)
  local tr=I.bind(aliases)
  local count=snapshot.network and #snapshot.network.nodes or #snapshot.route.stops
  local plan=P.plan(snapshot,aliases,false,math.max(800,count*220+256),tr)
  local children,width,height=diagramChildren(snapshot,plan,onTransfer,nil,tr)
  return floatingPanel(width,height,children,'linnan.bulb.static-canvas'),width,height
end

-- Native GUI elements only: no exported request, pixels, helper or browser.
local Hud = react.RegisterRecipe('LinnanBulbCockpitHudNative',function(param)
  local tr=I.bind(param.aliases:old())
  react.setMouseTransparent(true)
  react.setDisableFocusable(true)
  local state = react.useState(nil)
  local failure = react.useState('')
  local errorRef = react.useRef('')
  local routeRef = react.useRef('')
  local geometryRef = react.useRef('')
  local scan=react.useRef({})
  local numberedLines=react.useRef(nil)
  local numberedConfig=react.useRef(nil)
  local configuredEntity=react.useRef(nil)
  local self = react.useSelfRef()
  local enterSubscription=react.useRef(nil)
  local exitSubscription=react.useRef(nil)
  local cameraEntry=react.useRef(0)
  -- This mutable controller is not a React dependency. Idle checks must not
  -- invalidate the recipe, and delayed joins must never outlive the session.
  local work=react.useRef({alive=true,pending=false})
  local control=work:get()
  diagnostic.note('hud.render',state:old() and 'route available' or 'no route')
  diagnostic.watch('hud',self,state)
  local function refresh()
    diagnostic.note('hud.refresh')
    if state:hasExpired() then diagnostic.note('hud.expired');return end
    local entity=cameraState.getEntity()
    if not entity then
      setHudVisible(false)
      if state:old() then state:set(nil)end
      if failure:old()~='' then failure:set('')end
      scan:set({});numberedLines:set(nil);numberedConfig:set(nil)
      return
    end
    -- Share the vehicle's existing join instead of keeping a second bounds
    -- timer alive on the full-screen host.
    if param.measureHost then param.measureHost()end
    -- Read after the preceding state has been rendered, so these are the
    -- actual component bounds, not the requested layout dimensions.
    local old=state:old()
    local drawn=old and tostring(old.route.lineId) or (failure:old()~='' and 'error' or nil)
    if drawn and geometryRef:get()~=drawn then
      geometryRef:set(drawn)
      local ok,report=pcall(function()
        local node=self:get()
        if not node then return 'component not mounted' end
        local size=api.gui.byId.getSize('linnan.bulb.hud')
        local first,last=node:getPosition(0,0),node:getPosition(1,1)
        return string.format('rawSize=%.6fx%.6f; visible=%s; topLeft=%.3f,%.3f; bottomRight=%.3f,%.3f',
          size.x,size.y,tostring(api.gui.byId.isVisibleRecursive('linnan.bulb.hud')),first.x,first.y,last.x,last.y)
      end)
      if ok then log.verbose('[BULB native 0.1.65dev] HUD bounds: '..report)
      else log.warning('[BULB native 0.1.65dev] HUD bounds failed: '..tostring(report)) end
    end
    local aliases=param.aliases:old()
    if configuredEntity:get()~=entity then
      configuredEntity:set(entity)
      if param.refreshAliases then aliases=param.refreshAliases() or aliases end
    end
    local naming=aliases.__busNaming
    local ok, snapshot = pcall(collect.read,entity,naming and naming.enabled or false,aliases.__stationLinks,scan:get(),aliases)
    if cameraState.getEntity()~=entity then return end
    if ok then
      if snapshot and aliasStore.saveDefaults and
        (numberedLines:get()~=snapshot.lines or numberedConfig:get()~=aliases)then
        numberedLines:set(snapshot.lines);numberedConfig:set(aliases)
        local saved,err=pcall(aliasStore.saveDefaults,P.pendingDefaults(snapshot.lines,aliases),function(_,success)
          if success and param.refreshAliases and not state:hasExpired()then
            react.enqueueJoin(param.refreshAliases,'LinnanBulbCockpitHudNative:labelsSaved')
          end
        end)
        if not saved then log.warning('[BULB native 0.1.65dev] default labels: '..tostring(err))end
      end
      if state:old()==snapshot and failure:old()=='' and errorRef:get()=='' then return end
      if state:old()~=snapshot then state:set(snapshot)end
      if failure:old()~='' then failure:set('')end
      if errorRef:get()~='' then errorRef:set('')end
      -- An exit hides synchronously. Reveal only after a fresh route read,
      -- so rapid re-entry cannot display the previous vehicle's route.
      setHudVisible(snapshot~=nil)
      local key=snapshot and tostring(snapshot.route.lineId)..':'..snapshot.route.name or ''
      if key~=routeRef:get() then
        routeRef:set(key)
        if snapshot then
          log.verbose(string.format('[BULB native 0.1.65dev] route ready: line=%s; stops=%d',
            snapshot.route.name,#snapshot.route.stops))
        end
      end
    else
      scan:set({});numberedLines:set(nil);numberedConfig:set(nil)
      if state:old() then state:set(nil)end
      if failure:old()=='' then failure:set('线路图暂时无法读取车辆数据，请查看游戏日志。')end
      setHudVisible(true)
      if errorRef:get()~=tostring(snapshot) then
        log.warning('[BULB native 0.1.65dev] '..tostring(snapshot));errorRef:set(tostring(snapshot))
      end
    end
  end
  local function requestRefresh()
    local job=control
    if not job.alive or state:hasExpired() or not cameraState.getEntity()then return end
    job.generation=cameraState.getGeneration()
    if job.pending then return end
    job.pending=true
    react.enqueueJoin(function()
      job.pending=false
      if job.alive and job.generation==cameraState.getGeneration()then refresh()end
    end,'LinnanBulbCockpitHudNative:readCamera')
  end
  react.onMount(function()
    hudVisibility=nil
    control.alive=true
    -- Hidden components may stop stepping. An entry event must wake the
    -- HUD with a fresh main-thread read instead of waiting on its timer.
    enterSubscription:set(cameraState.onEnter(function()
      if not control.alive or state:hasExpired()then return end
      scan:set({});configuredEntity:set(nil)
      cameraEntry:set(cameraEntry:get()+1)
      requestRefresh()
    end))
    exitSubscription:set(cameraState.onExit(function()
      if state:hasExpired()then return end
      -- Hide happens first in FreeCamTool.pop; release plain route/cache
      -- references now, even if hidden component timers never run again.
      scan:set({});numberedLines:set(nil);numberedConfig:set(nil)
      if state:old()then state:set(nil)end
      if failure:old()~=''then failure:set('')end
    end))
    if cameraState.getEntity()then requestRefresh()else setHudVisible(false)end
  end)
  react.onUnmount(function()
    control.alive=false
    local unsubscribe=enterSubscription:get()
    if unsubscribe then unsubscribe();enterSubscription:set(nil)end
    local unsubscribeExit=exitSubscription:get()
    if unsubscribeExit then unsubscribeExit();exitSubscription:set(nil)end
    scan:set({});numberedLines:set(nil);numberedConfig:set(nil);hudVisibility=nil
    log.verbose('[BULB native 0.1.65dev] HUD disposed; session callbacks and route cache released')
  end)
  -- onStepTimer runs with a restricted API. Camera access belongs in the
  -- main-thread join, as documented by React.enqueueJoin in this game build.
  react.onStepTimer(function()
    if not cameraState.getEntity() then return end
    diagnostic.note('hud.timer')
    requestRefresh()
  end,0.5,false)
  if not cameraState.getEntity()then return nil end
  local snapshot=state:old()
  if failure:old()~='' then
    local message=P.wrap(tr(failure:old()),66,true)
    return panel(480,40,builtin.BoxLayout{children={text(message,14,470,36)}},nil,true)
  end
  if not snapshot then return nil end
  local viewport=param.viewport
  local maxWidth=math.max(240,math.min(viewport.x-48,1600))
  local aliases=param.aliases:old()
  local flashing=aliases.__options and aliases.__options.flashNextStop==true
  local plan=P.plan(snapshot,aliases,not flashing,maxWidth,tr)
  local children,width,height=diagramChildren(snapshot,plan,nil,function(stop,stopColor)
    if flashing and (stop.isNext or (not snapshot.network and stop.index==snapshot.next)) then
      return FlashingStation{stop=stop,track=plan.track,lineColor=stopColor,vehicle=snapshot.vehicle or cameraState.getEntity(),
        meta={localKey='flash:'..cameraEntry:get()..':'..P.nextKey(snapshot),class='bulb-flashing-station',
          styleSheet=style{size={stop.markerSize,stop.markerSize},anchorPoint={.5,.5},
            padding={0,0,0,0},margin={0,0,0,0}}.styleSheet}}
    end
  end,tr)
  local lineColor=color(snapshot.route.color)
  local badge=plan.hasBadge and plan.badge or tr(modeNames[plan.mode] or plan.mode)
  local mark,markWidth,markHeight=modeMark(plan.mode,badge,lineColor,false,plan.name)
  local inset=12
  local titleLimit=math.min(420,viewport.x-48)-markWidth-12-inset*2
  local columns=math.max(4,math.floor(titleLimit/14)*2)
  local title,rows=P.wrap(P.ellipsize(plan.name,columns*2,true),columns,true)
  local titleWidth=math.min(titleLimit,math.ceil(modeMarks.textWidth(title,14))+4)
  local identityWidth=markWidth+12+titleWidth+inset*2
  local identityHeight=math.max(markHeight,rows*18)+inset*2+6
  local identityChildren={}
  positioned(identityChildren,rectangle(markWidth,2,lineColor),inset,inset-2,identityWidth,identityHeight)
  positioned(identityChildren,mark,inset,inset+6,identityWidth,identityHeight)
  positioned(identityChildren,text(title,14,titleWidth,rows*18,HUD_INK,nil,'bulb-route-title',nil,plan.name),
    inset+markWidth+12,inset+6+(markHeight-rows*18)/2,identityWidth,identityHeight)
  local identity=floatingPanel(identityWidth,identityHeight,identityChildren,'linnan.bulb.identity')
  local diagram
  if plan.segments and height>math.max(120,viewport.y-200)then
    -- A high branch count must not place labels above the viewport. Scale a
    -- content component inside a correctly sized outer frame; KeepInside
    -- then uses the displayed dimensions, not the unscaled diagram bounds.
    local percent=math.max(1,math.floor(math.max(120,viewport.y-200)/height*100))
    local inner=floatingPanel(width,height,children,'linnan.bulb.canvas-content',nil,'bulb-canvas-scale'..percent,nil,ScaledCanvas)
    local scaledWidth,scaledHeight=width*percent/100,height*percent/100
    local items={}
    positioned(items,inner,0,0,scaledWidth,scaledHeight,'linnan.bulb.scaled-content')
    diagram=floatingPanel(scaledWidth,scaledHeight,items,'linnan.bulb.canvas',{.5,1})
  else diagram=floatingPanel(width,height,children,'linnan.bulb.canvas',{.5,1})end
  return builtin.FloatingLayout{children={
    builtin.FloatingLayoutChild{h=24/viewport.x,v=72/viewport.y,
      overflowMode=builtin.type.FloatingLayoutOverflowMode.KeepInside,item=identity},
    builtin.FloatingLayoutChild{h=.5,v=1-32/viewport.y,
      overflowMode=builtin.type.FloatingLayoutOverflowMode.KeepInside,item=diagram},
  }}
end)

local Settings=settingsUI.create(react,builtin,style,P,modeMarks,collect,aliasStore,diagnostic,windows,
  cityUI.create(react,builtin,style,aliasStore,windows,P,I),
  stationUI.create(react,builtin,style,aliasStore,windows,P,collect,I),
  {badge=lineBadge,draw=staticDiagram,mark=modeMark},I)

-- Layout may not be ready on the first join. This child retries only until
-- calibration succeeds; removing the child also removes its native timer.
local Calibration=react.RegisterRecipe('LinnanBulbCalibrationNative',function(param)
  react.onStepTimer(param.requestMeasure,0.5,false)
  return builtin.FloatingLayout{children={}}
end)

local Replacement=react.RegisterRecipe('LinnanBulbFreeCamNative',function(param)
  react.setMouseTransparent(true)
  react.setDisableFocusable(true)
  local aliases=react.useState({})
  local aliasRevision=react.useRef(-1)
  -- byId.getSize returned 1x1 for the full-screen host in r8. Calibrate
  -- against a 100x100 GUI component instead of treating that as pixels.
  local viewport=react.useState({x=800,y=600})
  local self=react.useSelfRef()
  local lastGeometry=react.useRef('')
  local session=react.useState(nil)
  local enterSubscription=react.useRef(nil)
  local exitSubscription=react.useRef(nil)
  local work=react.useRef({alive=true,pending=false,calibrated=false})
  local control=work:get()
  diagnostic.note('root.render')
  diagnostic.watch('root',self,viewport)
  -- Saved configuration is loaded on mount/entry and after a confirmed save,
  -- never by a ride timer. Settings already update this shared state directly.
  local function refreshAliases()
    if aliases:hasExpired() then return end
    local loaded,stored,revision=pcall(aliasStore.read,aliasRevision:get())
    if loaded and stored and revision~=aliasRevision:get() then
      aliases:set(stored);aliasRevision:set(revision)
      log.verbose('[BULB native 0.1.65dev] aliases state loaded; revision='..tostring(revision))
    end
    return loaded and stored or aliases:old()
  end
  local function measureHost()
    diagnostic.note('root.measure')
    if viewport:hasExpired() then diagnostic.note('root.expired');return end
    local ok,report=pcall(function()
      local raw=api.gui.byId.getSize('linnan.bulb.host')
      local gauge=api.gui.byId.getSize('linnan.bulb.gauge')
      local size=P.viewport(raw,gauge)
      if size then control.calibrated=true end
      local previous=viewport:old()
      if size and (not previous.calibrated or previous.x~=size.x or previous.y~=size.y) then
        viewport:set({x=size.x,y=size.y,calibrated=true})
      end
      size=size or previous
      return string.format('gui=%.0fx%.0f; hostRaw=%.6fx%.6f; gaugeRaw=%.6fx%.6f',
        size.x,size.y,raw.x,raw.y,gauge.x,gauge.y)
    end)
    report=(ok and 'GUI bounds: ' or 'GUI bounds failed: ')..tostring(report)
    if report~=lastGeometry:get() then
      lastGeometry:set(report)
      log.verbose('[BULB native 0.1.65dev] '..report)
    end
  end
  local function requestMeasure(force)
    local job=control
    if not job.alive or viewport:hasExpired() or job.pending then return end
    if job.calibrated and force~=true then return end
    job.pending=true
    react.enqueueJoin(function()
      job.pending=false
      if job.alive and (not job.calibrated or force==true)then measureHost()end
    end,'LinnanBulbFreeCamNative:bounds')
  end
  react.onMount(function()
    diagnostic.note('root.mount')
    control.alive=true
    local function enter()
      if session:hasExpired()then return end
      session:set({vehicle=cameraState.getEntity(),generation=cameraState.getGeneration()})
      requestMeasure(true)
    end
    enterSubscription:set(cameraState.onEnter(enter))
    exitSubscription:set(cameraState.onExit(function()
      if not session:hasExpired() and session:old()then session:set(nil)end
    end))
    if cameraState.getEntity()then enter()end
    react.enqueueJoin(refreshAliases,'LinnanBulbFreeCamNative:mount')
    requestMeasure()
  end)
  react.onUnmount(function()
    control.alive=false
    local enter,exit=enterSubscription:get(),exitSubscription:get()
    if enter then enter();enterSubscription:set(nil)end
    if exit then exit();exitSubscription:set(nil)end
  end)
  local children={
    builtin.FloatingLayoutChild{h=1,v=0,item=param.nativeControls},
  }
  local active=session:old()
  -- Remove the recipe itself from this always-visible parent's tree. Merely
  -- hiding the HUD and clearing its state leaves disposal to a paused child.
  if active and active.vehicle==cameraState.getEntity()then
    children[#children+1]=builtin.FloatingLayoutChild{h=0,v=0,localKey='cockpit-session',
      overflowMode=builtin.type.FloatingLayoutOverflowMode.KeepInside,
      item=Hud{meta={id='linnan.bulb.hud',localKey='cockpit:'..active.generation,
      styleSheet=styleutil.makeStyle{anchorPoint={0,0},size={viewport:old().x,viewport:old().y}}},
      aliases=aliases,viewport=viewport:old(),refreshAliases=refreshAliases,measureHost=measureHost}}
  end
  children[#children+1]=builtin.FloatingLayoutChild{h=112/viewport:old().x,v=12/viewport:old().y,
    localKey='settings',overflowMode=builtin.type.FloatingLayoutOverflowMode.KeepInside,
    item=Settings{meta={id='linnan.bulb.settings',
        class=cameraState.getEntity() and 'bulb-settings-cockpit-hidden' or nil,
        styleSheet=styleutil.makeStyle{anchorPoint={0,0}}},
      aliases=aliases,viewport=viewport:old(),color=color,
      prepareOpen=function(open)
        react.enqueueJoin(function()
          if not control.alive or viewport:hasExpired()then return end
          measureHost();open(viewport:old())
        end,'LinnanBulbFreeCamNative:openSettings')
      end}}
  children[#children+1]=builtin.FloatingLayoutChild{h=0,v=0,localKey='gauge',item=builtin.Component{
      mouseTransparent=true,
      meta={id='linnan.bulb.gauge',styleSheet=styleutil.makeStyle{size={100,100}}}}}
  if not viewport:old().calibrated then
    children[#children+1]=builtin.FloatingLayoutChild{h=0,v=0,localKey='calibration',
      item=Calibration{requestMeasure=requestMeasure}}
  end
  return builtin.FloatingLayout{children=children}
end)

-- The C++ game controls react.game-free-cam's visibility. That ID and its
-- caller reference must stay on the original controls, not our host. A
-- constructor adapter preserves all original arguments before adding the
-- independent host; the diagram/settings are siblings of native controls.
local function mount(...)
  local nativeControls=react.CallOriginalRecipe(free.FreeCamOptions,...)
  return Replacement{meta={id='linnan.bulb.host'},nativeControls=nativeControls}
end

function data()
  return {replace=function(replacementApi)
    cameraState.install(free.FreeCamTool,function()setHudVisible(false)end)
    diagnostic.setCameraReader(cameraState.getEntity)
    replacementApi.ReplaceRecipe(free.FreeCamOptions,mount)
    log.verbose('[BULB native 0.1.65dev] installed; compact station-count layout; explicit anchors; transparent transfers; savegame aliases')
  end}
end
