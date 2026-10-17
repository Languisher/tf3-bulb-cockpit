local U={}
function U.create(react,builtin,style,store,I,B,V)
  local labels={TRAIN='Train',RER='RER',METRO='地铁',TRAM='电车',BUS='公交',BOAT='轮渡',AIR='航空',TRUCK='货车',FREIGHT_TRAIN='货运火车'}
  local names={'默认','巴黎','上海','慕尼黑'}
  return react.RegisterRecipe('LinnanBulbPresetSettingsNative',function(param)
    local aliases=react.useMirrorState(param.aliases)
    local pending=react.useState(nil)
    local error=react.useState('')
    local busy=react.useRef(false)
    local tr=I.bind(aliases:old())
    local unicode=I.language(aliases:old())~='en' and I.language(aliases:old())~='zh'
    local width=param.width
    local labelWidth=math.min(160,math.floor(width*.38))
    local function label(value,w,h)
      local shown=B.fit(value,w-4,19,19)
      return builtin.TextView{text=shown,useUnicodeCompatibilityFont=unicode,
        meta={class='font-scale-body',tooltip=value,styleSheet=style{size={w,h or 32}}.styleSheet}}
    end
    local function selection(mode)
      local patch=pending:old()
      return patch and patch[mode] or V.selection(aliases:old(),mode)
    end
    local function save(patch)
      if busy:get() or pending:hasExpired() or (param.session and param.session.closed)then return end
      local changed=false
      for mode,value in pairs(patch)do if selection(mode)~=value then changed=true end end
      if not changed then return end
      busy:set(true);pending:set(patch);error:set('')
      local function complete(success)
        if param.aliases:hasExpired()then return end
        if success then
          param.aliases:transform(function(latest)
            local result,options,selections={},{},{}
            for k,v in pairs(latest)do result[k]=v end
            for k,v in pairs(latest.__options or {})do options[k]=v end
            for k,v in pairs(options.linePresets or {})do selections[k]=v end
            for k,v in pairs(patch)do selections[k]=v end
            options.linePresets=selections;result.__options=options;return result
          end)
        end
        if pending:hasExpired() or (param.session and param.session.closed)then return end
        busy:set(false);pending:set(nil)
        if not success then error:set(tr('预设保存失败，请重试。'))end
      end
      local ok,err=pcall(store.saveOptions,{linePresets=patch},function(_,success)
        react.enqueueJoin(function()complete(success==true)end,'LinnanBulbPresetSettingsNative:confirm')
      end)
      if not ok then log.warning('[Route Display] presets: '..tostring(err));complete(false)end
    end
    local function row(mode,title,all)
      local comboWidth=width-labelWidth-8
      -- Native entries reserve 16 px padding and a 32 px dropdown arrow.
      local function entry(value)return label(value,math.max(16,comboWidth-48),24)end
      local current=all and selection(V.modes[1]) or selection(mode)
      if all then for _,m in ipairs(V.modes)do if selection(m)~=current then current=nil;break end end end
      local items,value={},all and 1 or 0
      if all then items[1]=builtin.ComboBoxItem{value=1,content=entry(tr('分别设置'))}end
      for i,name in ipairs(names)do
        local index=i+(all and 1 or 0)
        items[#items+1]=builtin.ComboBoxItem{value=index,content=entry(tr(name))}
        if V.names[i]==current then value=index end
      end
      return builtin.Component{meta={class='bulb-settings-controls',styleSheet=style{size={width,32}}.styleSheet},
        layout=builtin.BoxLayout{orientation=builtin.type.Orientation.Horizontal,children={label(tr(title),labelWidth),
        builtin.ComboBox{value=value,items=items,compact=true,
          meta={id='linnan.bulb.presets.'..(all and 'all' or mode:lower()),class='bulb-settings-mode',
            enabled=not busy:get(),styleSheet=style{size={comboWidth,32}}.styleSheet},
          onValueChange=function(index)
            local chosen=V.names[index-(all and 1 or 0)]
            if not chosen then return end
            local patch={}
            if all then for _,m in ipairs(V.modes)do patch[m]=chosen end else patch[mode]=chosen end
            save(patch)
          end}}}}
    end
    local rows={row(nil,'全部类型',true)}
    for _,mode in ipairs(V.modes)do rows[#rows+1]=row(mode,labels[mode])end
    if error:old()~=''then rows[#rows+1]=label(error:old(),width)end
    return builtin.BoxLayout{children={builtin.ScrollArea{content=builtin.Component{
      meta={class='bulb-settings-body',styleSheet=style{size={width,-1}}.styleSheet},layout=builtin.BoxLayout{children=rows}},
      horizontalPolicy=builtin.type.ScrollBarPolicy.AlwaysOff,verticalPolicy=builtin.type.ScrollBarPolicy.AsNeeded,
      meta={class='bulb-settings-scroll',styleSheet=style{size={width,math.max(96,math.min(440,param.height))}}.styleSheet}}}}
  end)
end
return U
