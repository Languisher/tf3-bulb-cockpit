-- Display-only walkable interchanges, selected directly on the game map.
local S={}
function S.create(react,builtin,style,aliasStore,windows,P,collect,I)
  local activePick,PickTool
  local pickKey='linnan.bulb.station.pick'
  local function stopPick(owner,keep)
    local session=activePick
    if not session or (owner and session.owner~=owner)then return end
    session.keep=keep==true
    local stack=windows.getDefaultToolStackApi()
    if stack then stack.pop(PickTool,pickKey)
    else activePick=nil;session.onStop(session.keep)end
  end
  local StationIcon=react.RegisterRecipe('LinnanBulbStationPickIconNative',function(param)
    react.setMouseTransparent(true)
    return builtin.BoxLayout{children={builtin.UseDefaultHudIcon(param)}}
  end)
  local function bindPick(ctx,session)
    session.refresh=function()bindPick(ctx,session)end
    ctx.setActionFn(function()
      local palette=api.gui.genericRep.get(api.gui.genericRep.find('::/gui/main/selection_colors.gres')).data.default
      local function ink(value)return api.type.Vec4f.new(value[1],value[2],value[3],value[4] or 1)end
      local thresholds=(ug_require '::/gui/hud/hud_react_util.tl').makeDefaultVisibilityThresholds()
      thresholds.cameraHeightLowerCutoff=0
      local function enabled()return activePick==session and not session.suspended and not session.owner:hasExpired()end
      return builtin.ActionDescriptor{tool='management',terrainCirclePolicy='Never',
        highlightedEntities=session.entities(),onBack=function()
          if activePick==session then stopPick(session.owner,false)end
        end,children={
          builtin.HudIconManagerConfig{masterRecipe=StationIcon,userParam={},
            preFilter={api.type.ComponentType.STATION_GROUP},visibilityThresholds=thresholds,
            showCosts=false,showIncome=false},
          builtin.Selector{stopOnMenuBack=false,lineViewerSupport=true,
            filter=function(entity)
              local ok,station,message=pcall(collect.resolveStation,entity)
              return ok and (station~=nil or message~=nil)
            end,
            onSelect=function(entity,_,details)
              if not enabled()then return false end
              local ok,station,message=pcall(collect.resolveStation,entity,details)
              if not ok then log.warning('[BULB native r43] station pick: '..tostring(station))end
              if not ok or not station then session.message(session.tr(message or '请点击车站或车站图标。'));return false end
              session.onPick(station)
              return true
            end,
            onSelectSecondary=function()if enabled()then stopPick(session.owner,false)end;return true end,
            selectionColor=ink(palette.selectionColor),selectionOutlineColor=ink(palette.selectionOutlineColor),
            selectionOutlineColor1=ink(palette.selectionOutlineColor),circleBorderColor=ink(palette.selectionCircleColor),
            crosshairColor=ink(palette.crosshairColor)},
        }}
    end,pickKey)
  end
  PickTool=react.RegisterTool{name='LinnanBulbStationPick',
    push=function(ctx,session)activePick=session;session.onActive(true);bindPick(ctx,session)end,
    pop=function(_,session)
      if activePick==session then activePick=nil end
      session.onStop(session.keep==true)
    end,
    shelve=function(ctx,session,shelved)
      session.suspended=shelved;session.onActive(not shelved)
      if shelved then ctx.setActionFn(nil)
      elseif activePick~=session or session.owner:hasExpired()then ctx.popSelf()
      else bindPick(ctx,session)end
    end}
  local function label(text,width,height,tooltip,id)
    local full=text
    if width then text=P.ellipsize(text,math.max(2,math.floor(width/19)*2),false)end
    return builtin.TextView{text=text,useUnicodeCompatibilityFont=true,meta={class='font-scale-body',id=id,
      tooltip=tooltip or (text~=full and full or nil),styleSheet=style{size={width or -1,height or 24},
        padding={0,0,0,0},margin={0,0,0,0}}.styleSheet}}
  end
  local function box(children,width,horizontal)
    return builtin.Component{meta={class=horizontal and 'bulb-settings-controls' or 'bulb-settings-body',
      styleSheet=style{size={width,-1}}.styleSheet},layout=builtin.BoxLayout{
      orientation=horizontal and builtin.type.Orientation.Horizontal or builtin.type.Orientation.Vertical,children=children}}
  end
  local Content=react.RegisterRecipe('LinnanBulbStationContentNative',function(param)
    local tr=I.bind(param.aliases:old())
    local owner,selection,sessionRef=react.useRef({}),react.useRef({}),react.useRef(nil)
    local pair,picking,pending=react.useState({}),react.useState(false),react.useState(false)
    local busy=react.useRef(false)
    local message=react.useState(tr('点击开始关联，再依次点击地图上的两个车站。'))
    react.onUnmount(function()stopPick(owner,false)end)
    local width=param.width
    local byId={};for _,station in ipairs(param.stations)do byId[station.id]=station end
    local links=param.aliases:old().__stationLinks or {}
    local function title(station)
      local live=byId[station.id]
      return '#'..station.id..' '..(live and live.name or tr('已删除：')..station.name)
    end
    local function startPick()
      if busy:get()then return end
      local stack=windows.getDefaultToolStackApi()
      if not stack then message:set(tr('地图选择器暂时不可用，请稍后重试。'));return end
      stopPick(owner,false);selection:set({});pair:set({})
      local session={owner=owner,tr=tr}
      sessionRef:set(session)
      local function alive()return not owner:hasExpired() and sessionRef:get()==session end
      session.message=function(text)if alive()then message:set(text)end end
      session.entities=function()local a=selection:get().a;return a and {a.id} or {}end
      session.onActive=function(value)if alive()then picking:set(value)end end
      session.onStop=function(keep)
        if not alive()then return end
        sessionRef:set(nil);picking:set(false)
        if not keep then selection:set({});pair:set({});message:set(tr('已取消点选。'))end
      end
      session.onPick=function(station)
        if not alive()then return end
        local selected=selection:get()
        if selected.a and selected.a.id==station.id then message:set(tr('请选择另一个车站，不能关联同一站组。'));return end
        if not byId[station.id]then param.stations[#param.stations+1]=station end
        local nextPair=selected.a and {a=selected.a,b=station} or {a=station}
        selection:set(nextPair);pair:set(nextPair)
        if nextPair.b then
          stopPick(owner,true);message:set(tr('已选齐两个车站，请确认关联。'))
        else session.refresh();message:set(tr('已选第一个站，请点击第二个站。'))end
      end
      -- The native FreeCam tool must leave cockpit mode before map selection.
      local current=stack.getActiveTool()
      if current and current.name=='FreeCam'then stack.pop(current,nil)end
      stack.push(PickTool,pickKey,session,true)
      message:set(tr('请点击地图上的第一个车站；右键可取消。'))
    end
    local function apply(a,b,remove)
      if busy:get()then return end
      if not remove then
        a=a and collect.resolveStation(a.id);b=b and collect.resolveStation(b.id)
        if not a or not b then message:set(tr('请点选两个仍然存在的车站。'));return end
      end
      local key=aliasStore.stationKey(a.id,b.id)
      if not key then message:set(tr('请选择两个不同的车站。'));return end
      if not remove and links[key]then message:set(tr('这两个车站已关联。'));return end
      busy:set(true);pending:set(true);message:set(remove and tr('正在解除关联…') or tr('正在关联…'))
      local ok,err=pcall(aliasStore.saveStationLink,a,b,remove,function(_,success)
        react.enqueueJoin(function()
          if param.aliases:hasExpired() or message:hasExpired()then return end
          local loaded,aliases=pcall(aliasStore.read)
          local actual=loaded and aliases and aliases.__stationLinks and aliases.__stationLinks[key]
          local matches=loaded and aliases and (remove and actual==nil or not remove and actual~=nil)
          if success and matches then param.aliases:set(aliases)end
          busy:set(false);pending:set(false)
          message:set(success and matches and tr('已应用到线路图，请保存游戏。') or tr('未能写入，请稍后重试。'))
        end,'LinnanBulbStationContentNative:confirmSave')
      end)
      if not ok then
        log.warning('[BULB native r43] station link: '..tostring(err))
        busy:set(false);pending:set(false);message:set(tr('应用失败，请稍后重试。'))
      end
    end
    local entries={}
    for key,link in pairs(links)do entries[#entries+1]={key=key,link=link}end
    table.sort(entries,function(a,b)
      local left,right=title(a.link.a)..' '..title(a.link.b),title(b.link.a)..' '..title(b.link.b)
      return left==right and a.key<b.key or left<right
    end)
    local rows={label(tr('已有关联 · %d 对',#entries),width-20,24,tr('关联可传递：A↔B、B↔C 会共享三个站的换乘。'))}
    for _,entry in ipairs(entries)do
      local link=entry.link
      rows[#rows+1]=box({box({label(title(link.a),width-92,20),label('↔ '..title(link.b),width-92,20)},width-92),
        builtin.Button{meta={id='linnan.bulb.station.remove.'..entry.key,class='bulb-settings-save',
          styleSheet=style{size={56,32}}.styleSheet,tooltip=tr('删除这一条关联；其他关联仍然保留')},
          content=label(tr('解除')),onClick=function()apply(link.a,link.b,true)end}},width-20,true)
    end
    if #entries==0 then rows[#rows+1]=label(tr('尚未设置手动关联。'),width-20,24)end
    local chosen=pair:old()
    local function selectedLabel(key,station)
      local full=(key=='a' and '① ' or '② ')..(station and '#'..station.id..' '..station.name or tr('尚未点选'))
      return label(full,width,20,full,'linnan.bulb.station.chosen.'..key)
    end
    return builtin.BoxLayout{children={box({
      box({builtin.Button{meta={id='linnan.bulb.station.pick',class='bulb-settings-save',enabled=not pending:old(),
          styleSheet=style{size={width-88,32}}.styleSheet},
          content=label(picking:old() and tr('重新开始点选') or (chosen.a and tr('重新点选') or tr('开始关联'))),
          onClick=startPick},
        builtin.Button{meta={id='linnan.bulb.station.cancel',class='bulb-settings-save',
          styleSheet=style{size={80,32}}.styleSheet},content=label(tr('取消点选')),
          onClick=function()stopPick(owner,false);selection:set({});pair:set({});message:set(tr('已取消点选。'))end}},width,true),
      box({selectedLabel('a',chosen.a),selectedLabel('b',chosen.b)},width),
      builtin.Button{meta={id='linnan.bulb.station.add',class='primary, bulb-settings-save',
        enabled=chosen.a~=nil and chosen.b~=nil and not pending:old(),styleSheet=style{size={width,32}}.styleSheet},
        content=label(pending:old() and tr('正在应用…') or tr('确认关联')),
        onClick=function()local selected=selection:get();apply(selected.a,selected.b,false)end},
      builtin.ScrollArea{content=box(rows,width-20),horizontalPolicy=builtin.type.ScrollBarPolicy.AlwaysOff,
        verticalPolicy=builtin.type.ScrollBarPolicy.AsNeeded,
        meta={class='bulb-settings-scroll',styleSheet=style{size={width,param.listHeight}}.styleSheet}},
      label(message:old(),width,32,message:old()),
    },width)}}
  end)
  local Window=react.RegisterWrapperRecipe('LinnanBulbStationWindowNative',builtin.Window,function(param)
    local tr=I.bind(param.aliases:old())
    react.useInputAction('IA_MENU_BACK',react.iaHandler(param.onClose))
    react.useInputAction('IA_BACK',react.iaHandler(param.onClose))
    return builtin.Window{title=tr('关联换乘车站'),id='linnan.bulb.station.window',meta={class='bulb-settings-window'},
      closable=true,movable=true,pinnable=false,autoFocusOnBecomingVisible=true,autoVisibilityOnFocusChange=false,
      initialX=param.x,initialY=param.y,onClose=param.onClose,content=Content(param)}
  end)
  local function close()
    stopPick(nil,false)
    local wc=windows.getDefaultWindowApi();if wc then wc.removeAllWindows(Window)end
  end
  return {open=function(param)
    local wc=windows.getDefaultWindowApi();if not wc then return end
    stopPick(nil,false)
    param.stations=collect.listStationGroups(param.aliases:old().__stationLinks or {})
    local viewport=param.viewport or {x=800,y=600}
    param.width=math.min(520,math.max(248,viewport.x-72))
    param.listHeight=math.max(32,math.min(216,viewport.y-268))
    param.x=24/viewport.x;param.y=math.max(8,math.min(64,viewport.y-param.listHeight-260))/viewport.y
    param.onClose=close
    wc.addSingletonWindow(Window,param)
  end,close=close}
end
return S
