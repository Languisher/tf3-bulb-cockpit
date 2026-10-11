-- Optional bus naming uses the same native Window/ScrollArea contract.
local C={}
function C.create(react,builtin,style,aliasStore,windows,P,I)
  local function label(text,width,height,tooltip)
    if width then
      local full=text
      text=P.ellipsize(text,math.max(2,math.floor(width/19)*2),false)
      if text~=full then tooltip=tooltip or full end
    end
    return builtin.TextView{text=text,useUnicodeCompatibilityFont=true,
      meta={class='font-scale-body',tooltip=tooltip,styleSheet=style{size={width or -1,height or 32},
        padding={0,0,0,0},margin={0,0,0,0}}.styleSheet}}
  end
  local function box(children,width,horizontal)
    return builtin.Component{meta={class=horizontal and 'bulb-settings-controls' or 'bulb-settings-body',
      styleSheet=style{size={width,-1}}.styleSheet},layout=builtin.BoxLayout{
      orientation=horizontal and builtin.type.Orientation.Horizontal or builtin.type.Orientation.Vertical,children=children}}
  end
  local Content=react.RegisterRecipe('LinnanBulbCityContentNative',function(param)
    local tr=I.bind(param.aliases:old())
    local config=param.aliases:old().__busNaming or {enabled=false,districts={}}
    local initial=P.busCodeTable(param.towns,config)
    local enabled=react.useState(config.enabled==true)
    local districts=react.useStateLazy(function()return initial.districts end)
    local expressCode=react.useState(initial.expressCode)
    local message=react.useState(tr('前缀＋两位流水号：10 → 1001；51 → 5101。'))
    local width=param.width
    local localCount,expressCount,unknown=0,0,0
    for _,line in ipairs(param.lines)do
      if line.mode=='BUS'then
        if line.busScope=='local'then localCount=localCount+1
        elseif line.busScope=='express'then expressCount=expressCount+1
        else unknown=unknown+1 end
      end
    end
    local rows={}
    local function row(id,name,code,update)
      local trimmed=code:match('^%s*(.-)%s*$')
      local preview=trimmed:match('^%d+$') and trimmed..'01' or '—'
      return box({label(name,width-180,32,name),
        builtin.TextInputField{value=code,placeholderText=tr('跳过'),
          meta={id='linnan.bulb.city.'..id,class='font-scale-body',
            tooltip=tr('数字前缀，例如 10 → 1001、1002…；留空跳过这一类线路'),
            styleSheet=style{size={64,32}}.styleSheet},onTyping=update,onValueChange=update},
        label(preview,80,32,preview)},width-20,true)
    end
    rows[#rows+1]=row('express','Express',expressCode:old(),function(value)expressCode:set(value:gsub('[\r\n]',''))end)
    for _,town in ipairs(param.towns)do
      local function update(value)
        local nextValues={};for k,v in pairs(districts:old())do nextValues[k]=v end
        nextValues[tostring(town.id)]={name=town.name,code=value:gsub('[\r\n]','')}
        districts:set(nextValues)
      end
      rows[#rows+1]=row(town.id,town.name,districts:old()[tostring(town.id)].code,update)
    end
    return builtin.BoxLayout{children={box({
      box({builtin.ToggleButton{value=enabled:old() and 1 or 0,
        meta={id='linnan.bulb.city.enabled',class='bulb-settings-flash',
          tooltip=tr('默认关闭；选择后点击“应用到全部公交”保存。'),
          styleSheet=style{size={72,24}}.styleSheet},
        content=label(enabled:old() and tr('已开启') or tr('已关闭'),nil,24),
        onValueChange=function(value)if value==0 or value==1 then enabled:set(value==1)end end},
        label(tr('公交批量编号'),width-96,32)},width,true),
      label(tr('市内 %d · 跨城 %d · 城市不明跳过 %d',localCount,expressCount,unknown),width,24),
      box({label(tr('城市／类别'),width-180,24),label(tr('前缀'),64,24),label(tr('预览'),80,24)},width-20,true),
      builtin.ScrollArea{content=box(rows,width-20),
        horizontalPolicy=builtin.type.ScrollBarPolicy.AlwaysOff,verticalPolicy=builtin.type.ScrollBarPolicy.AsNeeded,
        meta={class='bulb-settings-scroll',styleSheet=style{size={width,param.listHeight}}.styleSheet}},
      builtin.Button{meta={id='linnan.bulb.city.apply',class='primary, bulb-settings-save',
          tooltip=tr('启用时对全部可识别公交使用此规则；之后逐线应用可覆盖，关闭则恢复未被手动修改的旧标号。'),
          styleSheet=style{size={width,32}}.styleSheet},content=label(tr('应用到全部公交')),onClick=function()
        local wanted={enabled=enabled:old(),format='code_table',expressCode=expressCode:old():match('^%s*(.-)%s*$'),districts={}}
        for _,town in ipairs(param.towns)do
          wanted.districts[tostring(town.id)]={name=town.name,code=districts:old()[tostring(town.id)].code:match('^%s*(.-)%s*$')}
        end
        local valid,reason=P.validateBusCodes(wanted,tr)
        if not valid then message:set(reason);return end
        message:set(tr('正在应用…'))
        local candidate={};for k,v in pairs(param.aliases:old())do candidate[k]=v end
        candidate.__busNaming=wanted
        local defaults=P.defaults(param.lines,candidate)
        local ok,err=pcall(aliasStore.saveBusNaming,wanted,param.lines,function(_,success)
          react.enqueueJoin(function()
            if param.aliases:hasExpired()then return end
            local loaded,aliases=pcall(aliasStore.read)
            local stored=loaded and aliases and aliases.__busNaming
            local matches=stored and stored.enabled==wanted.enabled and stored.format==wanted.format
              and stored.expressCode==wanted.expressCode
            for key,value in pairs(wanted.districts)do
              local actual=stored and stored.districts and stored.districts[key]
              matches=matches and actual and actual.name==value.name and actual.code==value.code
            end
            if success and matches then param.aliases:set(aliases)end
            if not message:hasExpired()then message:set(success and matches and tr('已应用，请保存游戏。') or tr('未能写入，请重试。'))end
          end,'LinnanBulbCityContentNative:confirmSave')
        end,defaults)
        if not ok then log.warning('[BULB native r43] bus naming: '..tostring(err));message:set(tr('应用失败，请稍后重试。'))end
      end},
      label(message:old(),width,24),
    },width)}}
  end)
  local Window=react.RegisterWrapperRecipe('LinnanBulbCityWindowNative',builtin.Window,function(param)
    local tr=I.bind(param.aliases:old())
    react.useInputAction('IA_MENU_BACK',react.iaHandler(param.onClose))
    react.useInputAction('IA_BACK',react.iaHandler(param.onClose))
    return builtin.Window{title=tr('公交线路编号一键配置'),id='linnan.bulb.city.window',
      meta={class='bulb-settings-window'},closable=true,movable=true,pinnable=false,
      autoFocusOnBecomingVisible=true,autoVisibilityOnFocusChange=false,
      initialX=param.x,initialY=param.y,onClose=param.onClose,content=Content(param)}
  end)
  return {open=function(param)
    local wc=windows.getDefaultWindowApi();if not wc then return end
    local viewport=param.viewport or {x=800,y=600}
    param.width=math.min(560,math.max(248,viewport.x-72))
    param.listHeight=math.max(32,math.min(240,viewport.y-304))
    param.x=24/viewport.x;param.y=math.max(8,math.min(64,viewport.y-param.listHeight-272))/viewport.y
    param.onClose=function()wc.removeAllWindows(Window)end
    wc.addSingletonWindow(Window,param)
  end,close=function()
    local wc=windows.getDefaultWindowApi();if wc then wc.removeAllWindows(Window)end
  end}
end
return C
