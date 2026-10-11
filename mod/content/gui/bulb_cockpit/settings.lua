-- Use the game's own window manager and themed controls. Diagram typography
-- and colors must not leak into the settings UI.
local S={}
local modeNames={'RER','地铁','电车','公交','轮渡','航空','货运'}
local modeChoices={'RER','METRO','TRAM','BUS','BOAT','AIR','TRUCK'}
local function numberKey(value)
  value=tostring(value):lower()
  if value:match('^%d+$')then
    local digits=value:gsub('^0+','');if digits==''then digits='0'end
    return '0'..string.format('%04d',#digits)..digits
  elseif value:match('^%a+$')then
    return '1'..string.format('%04d',#value)..value
  end
  return '2'..value:gsub('%d+',function(digits)
    digits=digits:gsub('^0+','');if digits==''then digits='0'end
    return string.format('%04d',#digits)..digits
  end)
end
function S.list(lines,aliases,query,scope,order,P)
  local defaults=P.defaults(lines,aliases)
  local result,keys={},{}
  query=tostring(query or ''):lower()
  for _,line in ipairs(lines)do
    local identifier=P.identifier(line,aliases,defaults)
    local badge=P.alias(line,aliases,defaults):lower()
    local name=tostring(line.name):lower()
    local haystack=scope=='number' and badge or (scope=='name' and name or name..'\n'..badge)
    if haystack:find(query,1,true)then
      result[#result+1]=line;keys[line.id]=numberKey(identifier)
    end
  end
  table.sort(result,function(a,b)
    local ka,kb=keys[a.id],keys[b.id]
    if order~='name' and ka~=kb then return order=='number_desc' and ka>kb or order~='number_desc' and ka<kb end
    if a.name~=b.name then return a.name<b.name end
    return a.id<b.id
  end)
  return result,defaults
end
-- Metadata only: resolving endpoint connectivity here would load every route
-- just to show its badge. The selected route is validated on navigation.
function S.directory(lines,aliases,busQuery,P)
  local groups,byMode={},{}
  for _,entry in ipairs({{'RER','RER'},{'METRO','Metro'},{'TRAM','Tramway'},{'BUS','公交'}})do
    local group={mode=entry[1],title=entry[2],items={},byBadge={}}
    groups[#groups+1]=group;byMode[group.mode]=group
  end
  local defaults=P.defaults(lines,aliases)
  local query=tostring(busQuery or ''):match('^%s*(.-)%s*$'):lower()
  local sorted=S.list(lines,aliases,'','all','number_asc',P)
  for _,line in ipairs(sorted)do
    local mode=P.mode(line,aliases);local group=byMode[mode]
    local badge,hasBadge=P.alias(line,aliases,defaults)
    local matches=mode~='BUS' or (query~='' and (badge..'\n'..line.name):lower():find(query,1,true))
    if group and matches then
      local key=hasBadge and badge or ('line:'..line.id)
      local item=group.byBadge[key]
      if not item then
        item={id=line.id,badge=hasBadge and badge or line.name,mode=mode,color=line.color,members={}}
        group.byBadge[key]=item;group.items[#group.items+1]=item
      end
      item.members[#item.members+1]=line
    end
  end
  return groups
end
function S.geometry(viewport)
  viewport=viewport or {x=800,y=600}
  local width=math.min(880,math.max(272,viewport.x-48))
  local content=width-24
  local compact=content<736
  -- All column widths are outer bounds. Reserve the scrollbar, then the
  -- same four-unit inset for both the heading and every data row.
  local rowWidth=content-12
  local inner=rowWidth-8
  local badge=40
  local field=compact and math.floor((inner-badge-24)/3) or 72
  local number=compact and field or 64
  local mode,save=136,56
  local fixed=badge+field+number+field+mode+save+6*8
  local extraToolbar=content<304 and 40 or 0
  local listHeight=math.max(64,math.min(304,viewport.y-280-extraToolbar))
  return {width=width,content=content,compact=compact,rowWidth=rowWidth,inner=inner,badge=badge,
    line=compact and inner or inner-fixed,
    prefix=field,number=number,suffix=field,alias=number,
    mode=mode,save=save,rowHeight=compact and 120 or 40,
    listHeight=listHeight,
    x=24/viewport.x,y=math.min(64,math.max(8,viewport.y-listHeight-264-extraToolbar))/viewport.y}
end
local function prepareChanges(lines,aliases,drafts,P)
  local changes,candidate={},{}
  for key,value in pairs(aliases)do candidate[key]=value end
  local originalDefaults=P.defaults(lines,aliases)
  for _,line in ipairs(lines)do
    local key=tostring(line.id);local draft=drafts[key]
    if draft and draft.name==line.name then
      local parts={prefix=draft.prefix:gsub('[\r\n]',''),identifier=draft.identifier:match('^%s*(.-)%s*$'),
        suffix=draft.suffix:gsub('[\r\n]','')}
      if not parts.identifier:match('^[A-Za-z0-9]*$')then
        return nil,'「'..line.name..'」的编号仅支持数字或英文字母。'
      end
      local initial=P.parts(line,aliases,originalDefaults)
      local current=aliases[key];local mode=current and current.name==line.name and current.displayMode or ''
      if mode=='TRAIN'then mode='RER'end
      if parts.prefix~=initial.prefix or parts.identifier~=initial.identifier or parts.suffix~=initial.suffix
        or draft.displayMode~=mode then
        candidate[key]={name=line.name,prefix=parts.prefix,identifier=parts.identifier,suffix=parts.suffix,
          displayMode=draft.displayMode,autoBus=false}
        changes[#changes+1]={line=line,parts=parts,displayMode=draft.displayMode,draft=draft}
      end
    end
  end
  local defaults=P.defaults(lines,candidate)
  for _,change in ipairs(changes)do
    change.shortName=P.alias(change.line,candidate,defaults):match('^%s*(.-)%s*$')
    candidate[tostring(change.line.id)].shortName=change.shortName
  end
  return changes,candidate,defaults
end
function S.create(react,builtin,style,P,B,collect,aliasStore,diagnostic,windows,citySettings,stationSettings,visuals)
  -- Native size describes content, excluding the control's CSS padding.
  -- Keep official skins/insets while budgeting their complete outer bounds.
  local function inputSize(width)return {width-8,28}end
  local function buttonSize(width)return {width-16,24}end
  local function label(value,width,height,class,tooltip,id)
    local meta=style{size={width or -1,height or -1},padding={0,0,0,0},margin={0,0,0,0},gravity={0,0.5}}
    meta.class=class or 'font-scale-body';meta.tooltip=tooltip;meta.id=id
    return builtin.TextView{text=value,useUnicodeCompatibilityFont=false,meta=meta}
  end
  local function wrap(layout,class,width,height)
    local meta=style{size={width or -1,height or -1}}
    meta.class=class
    return builtin.Component{meta=meta,layout=layout}
  end
  local function horizontal(children,class,width,height)
    return wrap(builtin.BoxLayout{orientation=builtin.type.Orientation.Horizontal,children=children},class,width,height)
  end
  local function vertical(children,class,width,height)
    return wrap(builtin.BoxLayout{orientation=builtin.type.Orientation.Vertical,children=children},class,width,height)
  end
  local AliasRow=react.RegisterRecipe('LinnanBulbAliasRowNative',function(param)
    local line,g=param.line,param.geometry
    local key=tostring(line.id)
    local current=param.aliases:old()[tostring(line.id)]
    local draft=param.drafts and param.drafts:get()[key]
    if draft and draft.name~=line.name then draft=nil end
    local initial=draft or P.parts(line,param.aliases:old(),param.defaults)
    local prefix=react.useState(initial.prefix)
    local identifier=react.useState(initial.identifier)
    local suffix=react.useState(initial.suffix)
    local selectedMode=current and current.name==line.name and current.displayMode or ''
    local displayMode=react.useState(draft and draft.displayMode or (selectedMode=='TRAIN' and 'RER' or selectedMode))
    local function remember(patch)
      if not param.drafts then return end
      local before=param.drafts:get()[key] or {prefix=prefix:old(),identifier=identifier:old(),suffix=suffix:old(),displayMode=displayMode:old()}
      local value={name=line.name,prefix=before.prefix,identifier=before.identifier,suffix=before.suffix,displayMode=before.displayMode}
      for k,v in pairs(patch)do value[k]=v end
      param.drafts:get()[key]=value
    end
    local function candidate(parts,mode)
      local aliases={}
      for k,v in pairs(param.aliases:old())do aliases[k]=v end
      aliases[tostring(line.id)]={name=line.name,displayMode=mode or displayMode:old(),
        prefix=parts.prefix,identifier=parts.identifier,suffix=parts.suffix,autoBus=false}
      return aliases
    end
    -- Share the complete-roster defaults across rows. Only an unsaved
    -- display-mode change needs its own numbering calculation.
    local defaults=param.defaults
    if not defaults or displayMode:old()~=(selectedMode=='TRAIN' and 'RER' or selectedMode)then
      defaults=P.defaults(param.lines or {line},candidate(initial))
    end
    local function field(key,state,width,placeholder,tooltip)
      local function change(value)
        if param.batchBusy and param.batchBusy:get()then return end
        remember({[key]=value});state:set(value)
      end
      return builtin.TextInputField{value=state:old(),placeholderText=placeholder,
        onTyping=change,onValueChange=change,
        meta={id='linnan.bulb.'..key..'.'..line.id,class='font-scale-body, bulb-settings-alias',
          enabled=not param.batchPending,tooltip=tooltip,styleSheet=style{size=inputSize(width)}.styleSheet}}
    end
    local fields={
      field('prefix',prefix,g.prefix,'','编号前的文字，例如 T、快、RER；可留空'),
      field('identifier',identifier,g.number,P.defaultIdentifier(line,defaults),
        '数字或英文字母，例如 3、A、AA、12A；留空使用预览编号'),
      field('suffix',suffix,g.suffix,'','编号后的文字，例如 b、支线；可留空'),
    }
    local items,selected={},1
    -- Empty/legacy TRAIN configurations resolve to their actual display
    -- type; they do not need a second, identically named menu item.
    local actual=P.mode({mode=displayMode:old()~='' and displayMode:old() or line.mode},{})
    for i,mode in ipairs(modeChoices) do
      if mode==actual then selected=i end
      items[#items+1]=builtin.ComboBoxItem{value=i,content=label(modeNames[i],nil,24)}
    end
    local controls={
      builtin.ComboBox{value=selected,items=items,compact=true,
        meta={id='linnan.bulb.mode.'..line.id,class='bulb-settings-mode',
          enabled=not param.batchPending,
          tooltip='选择线路图中的交通标识样式',styleSheet=style{size={g.mode,32}}.styleSheet},
        onValueChange=function(value)
          if not modeChoices[value] or (param.batchBusy and param.batchBusy:get())then return end
          local oldMode=P.mode({mode=displayMode:old()~='' and displayMode:old() or line.mode},{})
          local newMode=modeChoices[value]
          local patch={displayMode=modeChoices[value]}
          if identifier:old()=='' and suffix:old()=='' and prefix:old()==(oldMode=='TRAM' and 'T' or '')then
            patch.prefix=newMode=='TRAM' and 'T' or '';prefix:set(patch.prefix)
          end
          remember(patch)
          displayMode:set(modeChoices[value])
        end},
      builtin.Button{meta={id='linnan.bulb.save.'..line.id,class='primary, bulb-settings-save',
        enabled=not param.batchPending,
        styleSheet=style{size=buttonSize(g.save)}.styleSheet},content=label('应用',nil,24),onClick=function()
        if param.batchBusy and param.batchBusy:get()then return end
        local submitted=param.drafts and param.drafts:get()[key]
        local latest=submitted or {prefix=prefix:old(),identifier=identifier:old(),suffix=suffix:old(),displayMode=displayMode:old()}
        local parts={prefix=latest.prefix:gsub('[\r\n]',''),identifier=latest.identifier:match('^%s*(.-)%s*$'),
          suffix=latest.suffix:gsub('[\r\n]','')}
        if not parts.identifier:match('^[A-Za-z0-9]*$')then
          param.message:set('编号仅支持数字或英文字母；其他文字请放在前缀或后缀。');return
        end
        local aliases=candidate(parts,latest.displayMode)
        local wanted=P.alias(line,aliases,P.defaults(param.lines or {line},aliases)):match('^%s*(.-)%s*$')
        local wantedMode=latest.displayMode
        local mergeNotice=''
        if collect.mergeStatus then
          local checked,count,warning=pcall(collect.mergeStatus,line,aliases)
          if not checked then param.message:set('未能校验同号线路，请稍后重试。');return end
          mergeNotice=warning or (count>1 and ('已合并 '..count..' 条同号线路。') or '')
        end
        param.message:set('正在应用线路配置…')
        local ok,err=pcall(aliasStore.save,line,wanted,function(_,success)
          react.enqueueJoin(function()
            if param.aliases:hasExpired() or param.message:hasExpired() then return end
            local loaded,value=pcall(aliasStore.read)
            local entry=loaded and value and value[tostring(line.id)]
            if success and entry and entry.name==line.name and entry.shortName==wanted
              and entry.prefix==parts.prefix and entry.identifier==parts.identifier and entry.suffix==parts.suffix
              and (entry.displayMode or '')==wantedMode then
              param.aliases:set(value)
              if param.drafts and param.drafts:get()[key]==submitted then param.drafts:get()[key]=nil end
              param.message:set('已应用。'..mergeNotice..'请保存游戏。')
            else param.message:set('配置未写入，请稍后重试。') end
          end,'LinnanBulbAliasRowNative:confirmSave')
        end,wantedMode,parts)
        if not ok then
          log.warning('[BULB native 0.1.61dev] settings save: '..tostring(err))
          param.message:set('应用失败，请稍后重试。')
        end
      end},
    }
    local badge,hasBadge=P.alias(line,param.aliases:old(),param.defaults)
    local nameWidth=g.line-20
    local value=B.fit(line.name,nameWidth,19,19)
    local nameCells={
      builtin.ImageView{path='linnan_bulb_cockpit::/gui/bulb_cockpit/symbols/circle.tga',
        scaling=builtin.type.ImageViewScaling.Stretch,meta=style{size={12,12},color=param.lineColor}},
      label(value,nameWidth,32,nil,line.name),
    }
    local badgeChildren={}
    if hasBadge and visuals then
      badgeChildren[1]=builtin.FloatingLayoutChild{h=.5,v=.5,
        item=visuals.badge(P.mode(line,param.aliases:old()),badge,param.lineColor,true,badge)}
    end
    local badgeCell=wrap(builtin.FloatingLayout{children=badgeChildren},'bulb-settings-badge',g.badge,32)
    local name=horizontal(nameCells,'bulb-settings-name',g.line,32)
    local cells
    if g.compact then
      cells={name,horizontal({badgeCell,fields[1],fields[2],fields[3]},'bulb-settings-controls',g.inner,32),
        horizontal(controls,'bulb-settings-controls',g.inner,32)}
    else
      cells={name,badgeCell}
      for _,item in ipairs(fields)do cells[#cells+1]=item end
      for _,item in ipairs(controls)do cells[#cells+1]=item end
    end
    return builtin.BoxLayout{children={wrap(builtin.BoxLayout{
      orientation=g.compact and builtin.type.Orientation.Vertical or builtin.type.Orientation.Horizontal,
      children=cells},'bulb-settings-row'..(param.striped and ', bulb-settings-striped' or ''),g.inner,g.rowHeight-8)}}
  end)
  local Content=react.RegisterRecipe('LinnanBulbSettingsContentNative',function(param)
    local query=react.useState('')
    local scope=react.useState(2)
    local order=react.useState(1)
    local message=react.useState('同类型、同完整标号且起终点连通的线路合并显示；请保存游戏。')
    local initialOptions=param.aliases:old().__options
    local flashChoice=react.useState(initialOptions and initialOptions.flashNextStop==true or false)
    local flashPending=react.useState(false)
    local flashBusy=react.useRef(false)
    -- Parent-owned drafts survive row unmounts caused by search/sorting.
    -- Closing this editor releases them; no global cache or timer is needed.
    local drafts=react.useRef({})
    local batchBusy=react.useRef(false)
    local batchPending=react.useState(false)
    local rows,g={},param.geometry
    local filtered,defaults=S.list(param.lines,param.aliases:old(),query:old(),
      ({'number','name','all'})[scope:old()],({'number_asc','number_desc','name'})[order:old()],P)
    for _,line in ipairs(filtered) do
      rows[#rows+1]=AliasRow{meta={localKey=tostring(line.id)..line.name},line=line,geometry=g,
        lines=param.lines,defaults=defaults,
        drafts=drafts,batchBusy=batchBusy,batchPending=batchPending:old(),
        striped=#rows%2==1,lineColor=param.color(line.color),aliases=param.aliases,message=message}
    end
    local function choice(id,names,state,width,tooltip)
      local items={}
      for i,name in ipairs(names)do items[#items+1]=builtin.ComboBoxItem{value=i,content=label(name,nil,24)}end
      return builtin.ComboBox{value=state:old(),items=items,compact=true,
        meta={id=id,class='bulb-settings-mode',tooltip=tooltip,styleSheet=style{size={width,32}}.styleSheet},
        onValueChange=function(value)if names[value]then state:set(value)end end}
    end
    local count=#rows
    if count==0 then rows[1]=label(query:old()=='' and '当前存档没有线路。' or '没有找到匹配的线路。',g.content-20,64) end
    local headings=g.compact and {label('标识',g.badge,24,'font-scale-annotation'),
        label('前缀',g.prefix,24,'font-scale-annotation'),label('编号',g.number,24,'font-scale-annotation'),
        label('后缀',g.suffix,24,'font-scale-annotation')}
      or {label('线路',g.line,24,'font-scale-annotation'),label('标识',g.badge,24,'font-scale-annotation'),
        label('前缀',g.prefix,24,'font-scale-annotation'),
        label('编号',g.number,24,'font-scale-annotation'),label('后缀',g.suffix,24,'font-scale-annotation'),
        label('显示类型',g.mode,24,'font-scale-annotation'),label('操作',g.save,24,'font-scale-annotation')}
    local children={}
    local footer={}
    if not stationSettings then footer[1]=label(tostring(count)..' 条线路',citySettings and 56 or 80,32,'font-scale-annotation')end
    if citySettings then footer[#footer+1]=builtin.Button{
      meta={id='linnan.bulb.settings.city',class='bulb-settings-save',
        styleSheet=style{size=buttonSize(112)}.styleSheet,tooltip='维护城市与 Express 的数字前缀对照表，默认关闭'},
      content=label('编号对照表',nil,24),onClick=function()
        local ok,lines=pcall(collect.listLines,true)
        if not ok then message:set('未能读取公交线路，请稍后重试。');return end
        local towns={}
        if collect.listTowns then
          local loaded,result=pcall(collect.listTowns)
          if not loaded then message:set('未能读取城市，请稍后重试。');return end
          towns=result
        end
        citySettings.open{aliases=param.aliases,lines=lines,towns=towns,viewport=param.viewport}
      end}
    end
    if stationSettings then footer[#footer+1]=builtin.Button{
      meta={id='linnan.bulb.settings.stations',class='bulb-settings-save',
        styleSheet=style{size=buttonSize(96)}.styleSheet,tooltip='让独立站组在线路图中共享换乘，例如火车站与站前公交站'},
      content=label('关联车站',nil,24),onClick=function()
        local ok,err=pcall(stationSettings.open,{aliases=param.aliases,viewport=param.viewport})
        if not ok then
          log.warning('[BULB native 0.1.61dev] station settings: '..tostring(err))
          message:set('未能读取车站，请稍后重试。')
        end
      end}
    end
    local statusWidth=g.content-(stationSettings and (citySettings and 224 or 104) or (citySettings and 184 or 88))
    local status=(stationSettings and tostring(count)..' 条 · ' or '')..message:old()
    footer[#footer+1]=label(P.ellipsize(status,math.max(2,math.floor(statusWidth/17)*2),true),
      statusWidth,40,'font-scale-annotation',status)
    local flashing=flashChoice:old()
    local stackedApply=g.content<304
    local function applyAll()
      if batchBusy:get()then return end
      local changes,candidate,defaults=prepareChanges(param.lines,param.aliases:old(),drafts:get(),P)
      if not changes then message:set(candidate);return end
      if #changes==0 then message:set('没有待应用的修改。');return end
      local assignments={}
      for _,change in ipairs(changes)do
        local key=tostring(change.line.id)
        if defaults[key]then assignments[key]=defaults[key]end
      end
      batchBusy:set(true);batchPending:set(true);message:set('正在应用全部修改…')
      local function complete(success)
        if param.aliases:hasExpired()then return end
        if success then
          -- Merge the acknowledged patch, without reading a stale engine
          -- snapshot or overwriting options/other edits made while pending.
          param.aliases:transform(function(latest)
            local updated={};for k,v in pairs(latest)do updated[k]=v end
            for _,change in ipairs(changes)do
              local key=tostring(change.line.id);updated[key]=candidate[key]
            end
            local saved={};for k,v in pairs(latest.__defaults or {})do saved[k]=v end
            for k,v in pairs(assignments)do saved[k]=v end
            updated.__defaults=saved;return updated
          end)
        end
        if message:hasExpired()then return end
        if success then
          for _,change in ipairs(changes)do
            local key=tostring(change.line.id)
            if drafts:get()[key]==change.draft then drafts:get()[key]=nil end
          end
        end
        batchBusy:set(false);batchPending:set(false)
        message:set(success and ('已应用 '..#changes..' 条修改，请保存游戏。') or '全部应用失败，修改已保留，请重试。')
      end
      local ok,err=pcall(aliasStore.saveAll,changes,function(_,success)
        react.enqueueJoin(function()complete(success==true)end,'LinnanBulbSettingsContentNative:confirmAll')
      end,assignments)
      if not ok then log.warning('[BULB native 0.1.61dev] apply all: '..tostring(err));complete(false)end
    end
    local applyButton=builtin.Button{meta={id='linnan.bulb.settings.apply-all',class='primary, bulb-settings-save',
      enabled=not batchPending:old(),tooltip='应用所有已编辑线路，包含被搜索筛选隐藏的修改',
      styleSheet=style{size=buttonSize(88)}.styleSheet},content=label('全部应用',nil,24),onClick=applyAll}
    local body={
      horizontal({builtin.ToggleButton{value=flashing and 1 or 0,
        meta={id='linnan.bulb.settings.flash',class='bulb-settings-flash',enabled=not flashPending:old(),
          styleSheet=style{size=buttonSize(88)}.styleSheet,
          tooltip='默认关闭，下一站黄灯常亮；开启后每半秒闪烁，可能降低性能'},
        content=label(flashing and '已开启' or '已关闭'),onValueChange=function(value)
          if (value~=0 and value~=1) or flashBusy:get()then return end
          local wanted=value==1
          if wanted==flashing then return end
          flashBusy:set(true);flashPending:set(true);flashChoice:set(wanted)
          message:set('正在应用…')
          local function complete(success)
            if param.aliases:hasExpired()then return end
            local current=param.aliases:old()
            if success then
              -- The command callback acknowledges the event; a GAME_SCRIPT
              -- component read can still contain its previous snapshot.
              -- Merge the accepted option without overwriting other edits.
              param.aliases:transform(function(latest)
                local updated,options={},{}
                for k,v in pairs(latest)do updated[k]=v end
                for k,v in pairs(latest.__options or {})do options[k]=v end
                options.flashNextStop=wanted;updated.__options=options
                return updated
              end)
            end
            -- The window may close before the command finishes. Keep the
            -- accepted root option, but never write expired local UI state.
            if message:hasExpired()then return end
            flashBusy:set(false);flashPending:set(false)
            if not success then flashChoice:set(current.__options and current.__options.flashNextStop==true or false)end
            message:set(success and '已应用，请保存游戏。' or '配置未写入，请稍后重试。')
          end
          local ok,err=pcall(aliasStore.saveOptions,{flashNextStop=wanted},function(_,success)
            react.enqueueJoin(function()complete(success==true)end,'LinnanBulbSettingsContentNative:confirmOptions')
          end)
          if not ok then log.warning('[BULB native 0.1.61dev] options: '..tostring(err));complete(false)end
        end},label(g.compact and '闪烁可能降低性能' or '下一站黄灯闪烁 · 开启可能降低性能',g.content-(stackedApply and 96 or 192),32,
          'font-scale-annotation','关闭时下一站黄灯常亮；开关随存档保存。'),
          not stackedApply and applyButton or nil},'bulb-settings-controls',g.content,32),
      horizontal({builtin.TextInputField{value=query:old(),placeholderText=scope:old()==1 and '搜索编号' or '搜索名称',
          meta={id='linnan.bulb.settings.search',class='font-scale-body',
            styleSheet=style{size=inputSize(g.content-200)}.styleSheet},
          onTyping=function(value)query:set(value)end,onValueChange=function(value)query:set(value)end},
        choice('linnan.bulb.settings.scope',{'编号','名称','全部'},scope,72,'按名称或完整线路标号搜索，例如 T1、T3b'),
        choice('linnan.bulb.settings.sort',{'编号 ↑','编号 ↓','名称 ↑'},order,112,
          '编号自然排序：2 在 10 前，字母按 A…Z、AA…；相同编号再按实际名称排列')},
        'bulb-settings-controls',g.content,32),
      horizontal(headings,'bulb-settings-heading',g.inner,24),
      builtin.ScrollArea{content=vertical(rows,'bulb-settings-list'),
        horizontalPolicy=builtin.type.ScrollBarPolicy.AlwaysOff,verticalPolicy=builtin.type.ScrollBarPolicy.AsNeeded,
        meta={class='bulb-settings-scroll',styleSheet=style{size={g.content,g.listHeight}}.styleSheet}},
      horizontal(footer,'bulb-settings-footer',g.content,40),
    }
    if stackedApply then table.insert(body,2,horizontal({applyButton},'bulb-settings-controls',g.content,32))end
    for _,item in ipairs(body) do children[#children+1]=item end
    return builtin.BoxLayout{children={vertical(children,'bulb-settings-body',g.content)}}
  end)
  local function button(id,caption,callback,width)
    return builtin.Button{meta={id=id,class='bulb-settings-save',styleSheet=style{size=buttonSize(width or 112)}.styleSheet},
      content=label(caption,nil,24),onClick=callback}
  end
  local Static=react.RegisterRecipe('LinnanBulbStaticRouteNative',function(param)
    -- Only this keyed child owns the visited graph. Parent navigation stores
    -- an ID and a release function; neither a diagram history nor a cache.
    local holder=react.useRef({disposed=false})
    local ready=react.useState(false)
    local locateError=react.useState('')
    local function release()local h=holder:get();h.snapshot=nil;h.aliases=nil;h.disposed=true end
    react.onUnmount(release)
    param.onReady(release)
    local h=holder:get()
    react.onMount(function()
      react.enqueueJoin(function()
        if h.disposed or ready:hasExpired() or param.aliases:hasExpired()then return end
        local aliases=param.aliases:old()
        -- Match the directory even before the defaults-save command has
        -- been acknowledged. A scoped read must not renumber B back to A.
        local effective={};for key,value in pairs(aliases)do effective[key]=value end
        effective.__defaults={};for key,value in pairs(aliases.__defaults or {})do effective.__defaults[key]=value end
        for key,value in pairs(P.defaults(param.lines,aliases))do effective.__defaults[key]=value end
        h.aliases=effective
        local ok,snapshot=pcall(collect.readLine,param.lineId,false,aliases.__stationLinks,effective)
        if ok then h.snapshot=snapshot
        else log.warning('[BULB native 0.1.61dev] static read: '..tostring(snapshot))end
        ready:set(true)
      end,'LinnanBulbStaticRouteNative:load')
    end)
    local g=param.geometry
    -- Match the diagram's first-station column; keep these two spacing tokens
    -- in sync with bulb-static-toolbar/identity in native.css.lua.
    local inset,identityGap=24,24
    local function locate()
      if h.disposed or ready:hasExpired() or not h.snapshot then return end
      local ok,located=pcall(function()
        -- Locate the real selected service, not its display number or the
        -- representative of a merged group. Validate only on this click.
        local id=param.lineId
        if not api.engine.entityExists(id) or not api.engine.getComponent(id,api.type.ComponentType.LINE)then return false end
        local stack=windows.getDefaultToolStackApi()
        local tool=stack and stack.getActiveTool()
        -- Match the native map picker: stop the cockpit camera before
        -- asking the game's Locate Line action to frame the route.
        if tool and tool.name=='FreeCam'then stack.pop(tool,nil)end
        api.gui.camera.followEntity(id,true)
        return true
      end)
      if ok and located then
        release();param.onClose()
      elseif not locateError:hasExpired()then
        locateError:set(ok and '线路已删除，无法定位。请返回目录刷新。' or '定位失败，请稍后重试。')
        if not ok then log.warning('[BULB native 0.1.61dev] locate line: '..tostring(located))end
      end
    end
    local children={horizontal({button('linnan.bulb.browser.back','返回线路目录',param.home,120),
      builtin.Button{meta={id='linnan.bulb.browser.locate',class='bulb-static-locate',tooltip='在地图上定位此线路',
          enabled=h.snapshot~=nil and not h.disposed,styleSheet=style{size={24,24}}.styleSheet},
        content=builtin.ImageView{path='::/gui/line_vehicle_mgmt/icons/symbol_locate_20.tga',
          scaling=builtin.type.ImageViewScaling.AutoFit,
          meta=style{size={20,20},anchorPoint={0.5,0.5},padding={0,0,0,0},margin={0,0,0,0}}},onClick=locate}},
      'bulb-static-toolbar',g.content,32)}
    if locateError:old()~=''then
      children[#children+1]=label(locateError:old(),g.content-inset,36,'font-scale-annotation, bulb-static-message',
        nil,'linnan.bulb.browser.locate-error')
    end
    if h.snapshot then
      local route=h.snapshot.route
      local aliases=h.aliases;local defaults=P.defaults(h.snapshot.lines,aliases)
      local mode=P.mode(route,aliases);local badge=P.alias(route,aliases,defaults)
      local mark,markWidth=visuals.mark(mode,badge,param.color(route.color),false,route.name)
      local titleWidth=math.max(32,g.content-inset-markWidth-identityGap)
      children[#children+1]=horizontal({mark,label(B.fit(route.name,titleWidth,19,19),
        titleWidth,44,'font-scale-body, bulb-static-title',route.name)},'bulb-static-identity',g.content,44)
      if h.snapshot.mergeWarning then
        children[#children+1]=label(h.snapshot.mergeWarning,g.content-inset,36,'font-scale-annotation, bulb-static-message')
        -- Disconnected services may share a badge. Keep every real service
        -- accessible without scanning their endpoints in the directory.
        local items,value={},1
        for _,line in ipairs(param.lines)do
          if P.mode(line,aliases)==mode and P.alias(line,aliases,defaults)==badge then
            items[#items+1]=builtin.ComboBoxItem{value=line.id,content=label(line.name,nil,24)}
            if line.id==param.lineId then value=line.id end
          end
        end
        children[#children+1]=builtin.ComboBox{value=value,items=items,compact=true,
          meta={id='linnan.bulb.browser.member',class='bulb-settings-mode, bulb-static-member',
            styleSheet=style{size={g.content-inset,32}}.styleSheet},
          onValueChange=function(id)if id~=param.lineId then param.navigate(id)end end}
      end
      -- React nodes belong to the current render context; store only plain
      -- snapshot data in the ref, never reuse a tree of old native node IDs.
      local drawn,diagram=pcall(visuals.draw,h.snapshot,aliases,param.navigate)
      if drawn then
        local mapHeight=math.max(h.snapshot.mergeWarning and 48 or 96,
          math.min(540,param.viewport.y-290-(h.snapshot.mergeWarning and 84 or 0)))
        children[#children+1]=builtin.ScrollArea{content=diagram,
          horizontalPolicy=builtin.type.ScrollBarPolicy.AsNeeded,verticalPolicy=builtin.type.ScrollBarPolicy.AsNeeded,
          meta={id='linnan.bulb.browser.map',class='bulb-settings-scroll',
            styleSheet=style{size={g.content,mapHeight}}.styleSheet}}
      else
        log.warning('[BULB native 0.1.61dev] static render: '..tostring(diagram))
        children[#children+1]=label('线路图暂时无法绘制。请返回目录重试。',g.content-inset,96,'font-scale-body, bulb-static-message')
      end
    elseif ready:old()then
      children[#children+1]=label('线路已删除、没有站点或暂时无法读取。请返回目录重试。',g.content-inset,96,'font-scale-body, bulb-static-message')
    else
      children[#children+1]=label('正在读取线路…',g.content-inset,96,'font-scale-body, bulb-static-message')
    end
    return builtin.BoxLayout{children={vertical(children,'bulb-settings-body, bulb-static-page',g.content)}}
  end)
  local Browser=react.RegisterRecipe('LinnanBulbBrowserNative',function(param)
    local page=react.useState(nil)
    local busQuery=react.useState('')
    local owner=react.useRef(nil)
    local function release()
      local fn=owner:get();owner:set(nil)
      if fn then fn()end
    end
    react.onUnmount(release)
    local function navigate(id)
      if page:hasExpired()then return end
      release();page:set(id)
    end
    local function home()navigate(nil)end
    local function back()if page:old()~=nil then home()else param.onClose()end end
    react.useInputAction('IA_MENU_BACK',react.iaHandler(back))
    react.useInputAction('IA_BACK',react.iaHandler(back))
    local g=param.geometry
    if page:old()=='config' then
      return builtin.BoxLayout{children={vertical({button('linnan.bulb.browser.back','返回线路目录',home,120),
        Content(param)},'bulb-settings-body',g.content)}}
    elseif type(page:old())=='number' then
      return builtin.BoxLayout{children={Static{meta={localKey='static:'..page:old()},lineId=page:old(),
        aliases=param.aliases,lines=param.lines,viewport=param.viewport,geometry=g,color=param.color,
        navigate=navigate,home=home,onClose=param.onClose,onReady=function(fn)owner:set(fn)end}}}
    end
    local groups=S.directory(param.lines,param.aliases:old(),busQuery:old(),P)
    local sections={}
    local tileWidth,tileHeight,tileGap=44,32,8
    local columns=math.max(1,math.floor((g.content-32+tileGap)/(tileWidth+tileGap)))
    for _,group in ipairs(groups)do
      local section={label(group.title,g.content-32,28,'font-scale-body')}
      if group.mode=='BUS' then
        section[#section+1]=builtin.TextInputField{value=busQuery:old(),placeholderText='搜索公交标号或线路名称',
          meta={id='linnan.bulb.browser.bus-search',class='font-scale-body',styleSheet=style{size={g.content-32,32}}.styleSheet},
          onTyping=function(value)busQuery:set(value)end,onValueChange=function(value)busQuery:set(value)end}
      end
      local row={}
      for i,item in ipairs(group.items)do
        local names={};for _,line in ipairs(item.members)do names[#names+1]=line.name end
        local tooltip=table.concat(names,'\n')
        local tile=visuals.badge(item.mode,item.badge,param.color(item.color),true,tooltip)
        local id=item.id
        row[#row+1]=builtin.Button{meta={id='linnan.bulb.browser.line.'..id,class='bulb-directory-tile',tooltip=tooltip,
          styleSheet=style{size={tileWidth,tileHeight}}.styleSheet},content=tile,onClick=function()navigate(id)end}
        if #row==columns or i==#group.items then
          section[#section+1]=horizontal(row,'bulb-directory-row');row={}
        end
      end
      if #group.items==0 then
        section[#section+1]=label(group.mode=='BUS' and
          (busQuery:old():match('^%s*$') and '输入标号或名称搜索公交线路。' or '没有匹配的公交线路。')
          or '当前没有此类线路。',g.content-32,32,'font-scale-annotation')
      end
      sections[#sections+1]=vertical(section,'bulb-directory-section',g.content-16)
    end
    return builtin.BoxLayout{children={vertical({
      horizontal({label('线路目录',g.content-152,32),button('linnan.bulb.browser.configure','线路与显示设置',function()navigate('config')end,144)},
        'bulb-settings-controls'),
      builtin.ScrollArea{content=vertical(sections,'bulb-directory-sections'),
        horizontalPolicy=builtin.type.ScrollBarPolicy.AlwaysOff,verticalPolicy=builtin.type.ScrollBarPolicy.AsNeeded,
        meta={class='bulb-settings-scroll',styleSheet=style{size={g.content,math.max(128,math.min(620,param.viewport.y-220))}}.styleSheet}},
    },'bulb-settings-body',g.content)}}
  end)
  local Window=react.RegisterWrapperRecipe('LinnanBulbSettingsWindowNative',builtin.Window,function(param)
    react.useInputAction('IA_MENU_BACK',react.iaHandler(param.onClose))
    react.useInputAction('IA_BACK',react.iaHandler(param.onClose))
    -- Wrapper recipes must return Window directly. Non-class metadata here
    -- inserts WithComponentParams and crashes WindowContainer. The sized
    -- content plus Window::Content padding already determines the width.
    return builtin.Window{title='线路图设置',id='linnan.bulb.settings.window',
      meta={class='bulb-settings-window'},
      closable=true,movable=true,pinnable=false,autoFocusOnBecomingVisible=true,autoVisibilityOnFocusChange=false,
      initialX=param.geometry.x,initialY=param.geometry.y,onClose=param.onClose,
      content=Browser(param)}
  end)
  return react.RegisterRecipe('LinnanBulbSettingsNative',function(param)
    diagnostic.note('settings.render')
    local open=react.useState(false)
    local opening=react.useRef({request=0})
    local control=opening:get()
    local function close()
      control.request=control.request+1
      if param.onOpenChange then param.onOpenChange(false)end
      local wc=windows.getDefaultWindowApi()
      if wc then wc.removeAllWindows(Window) end
      if citySettings then citySettings.close()end
      if stationSettings then stationSettings.close()end
      if not open:hasExpired() then open:set(false) end
    end
    react.onUnmount(close)
    return builtin.BoxLayout{children={builtin.ToggleButton{
      meta={id='linnan.bulb.settings.toggle',class='bulb-settings-toggle',
        tooltip=open:old() and '关闭线路图设置' or '线路图设置'},
      value=open:old() and 1 or 0,
      content=builtin.ImageView{path='::/gui/game_bar/icons/line_vehicle_manager_30.tga',
        scaling=builtin.type.ImageViewScaling.AutoFit,meta={class='bulb-settings-toggle-icon'}},
      onValueChange=function(value)
        if value~=1 then close();return end
        local request=control.request+1;control.request=request
        local function show(viewport)
          if open:hasExpired() or control.request~=request then return end
          local wc=windows.getDefaultWindowApi()
          if not wc then log.warning('[BULB native 0.1.61dev] window manager unavailable');return end
          local ok,lines=pcall(collect.listLines,false)
          if not ok then log.warning('[BULB native 0.1.61dev] settings: '..tostring(lines));return end
          if aliasStore.saveDefaults then
            local saved,err=pcall(aliasStore.saveDefaults,P.pendingDefaults(lines,param.aliases:old()))
            if not saved then log.warning('[BULB native 0.1.61dev] default labels: '..tostring(err))end
          end
          viewport=viewport or param.viewport
          wc.addSingletonWindow(Window,{aliases=param.aliases,lines=lines,geometry=S.geometry(viewport),
            viewport=viewport,color=param.color,onClose=close})
          open:set(true)
          if param.onOpenChange then param.onOpenChange(true)end
        end
        -- Measure only on demand outside the cockpit, before placing the
        -- window. The request token also cancels an open queued before close.
        if param.prepareOpen then param.prepareOpen(show)else show(param.viewport)end
      end,
    }}}
  end)
end
return S
