local f=assert(io.open('tests/test_native.lua'));local harness=f:read('*a');f:close()
assert(load(harness..[=[
do
  for _,locale in ipairs(modules['localization.lua'].locales)do
    if locale.code~='zh' and locale.code~='en'then modules[locale.code..'.lua']=dofile('mod/content/gui/bulb_cockpit/locales/'..locale.code..'.lua')end
  end
  local V=modules['presets.lua']
  local requests={}
  modules['aliases.lua'].saveOptions=function(value,callback)requests[#requests+1]={value=value,callback=callback}end
  aliases={__options={language='en',routeMapScale=175,flashNextStop=true}}
  local param={aliases=aliasState,width=400,height=400,session={closed=false}}
  local function widgets()
    local result={}
    walk(render('LinnanBulbPresetSettingsNative',param),function(_,p)if p.meta and p.meta.id then result[p.meta.id]=p end end)
    return result
  end
  local all='linnan.bulb.presets.all'
  local metro='linnan.bulb.presets.metro'
  local rer='linnan.bulb.presets.rer'
  local controls=widgets()
  assert(controls[all].value==2 and #controls[all].items==5 and controls[metro].value==1)
  controls[metro].onValueChange(3)
  assert(#requests==1 and requests[1].value.linePresets.METRO=='shanghai')
  assert(widgets()[all].value==1 and widgets()[metro].value==3 and not widgets()[rer].meta.enabled)
  controls[rer].onValueChange(4)
  assert(#requests==1,'ignore duplicate selections while acknowledgment is pending')
  aliases.__options.language='fr';aliases.concurrent={name='keep'};aliases.__options.linePresets={TRAM='paris'}
  requests[1].callback(nil,true);join()
  assert(aliases.__options.linePresets.METRO=='shanghai' and aliases.__options.linePresets.TRAM=='paris')
  assert(aliases.__options.language=='fr' and aliases.__options.flashNextStop and aliases.__options.routeMapScale==175 and aliases.concurrent)
  local before=#requests
  widgets()[metro].onValueChange(3);widgets()[all].onValueChange(1)
  assert(#requests==before,'unchanged selections and mixed indicator do not save')
  widgets()[rer].onValueChange(4)
  requests[#requests].callback(nil,false);join()
  assert(widgets()[rer].value==1,'a failed save restores the accepted type preference')
  widgets()[all].onValueChange(3)
  for _,mode in ipairs(V.modes)do assert(requests[#requests].value.linePresets[mode]=='paris')end
  requests[#requests].callback(nil,true);join()
  assert(widgets()[all].value==3)
  widgets()[metro].onValueChange(4)
  param.session.closed=true
  for _,item in ipairs(contexts.LinnanBulbPresetSettingsNative)do item.expired=true end
  requests[#requests].callback(nil,true);join()
  assert(aliases.__options.linePresets.METRO=='munich','accepted command survives closing the child page')
  assert(not timers.LinnanBulbPresetSettingsNative,'presets introduce no timer')
  -- Each native row fits in the available width in every shipped language.
  for _,locale in ipairs(modules['localization.lua'].locales)do
    aliases={__options={language=locale.code}}
    for _,width in ipairs({248,400,856})do
      contexts.LinnanBulbPresetSettingsNative={}
      local tree=render('LinnanBulbPresetSettingsNative',{aliases=aliasState,width=width,height=400})
      walk(tree,function(kind,p)
        if kind=='TextView'then
          assert(B.textWidth(p.text,p.meta.styleSheet.fontSize or 19)<=p.meta.styleSheet.size[1],locale.code..': label overflow')
        elseif kind=='BoxLayout' and p.orientation==builtin.type.Orientation.Horizontal then
          local a,b=p.children[1].param,p.children[2].param
          assert(a.meta.styleSheet.size[1]+b.meta.styleSheet.size[1]+8<=width)
        end
      end)
    end
  end
  -- The settings entry opens the preset page; both Back and Esc return to
  -- line settings instead of closing the window or leaving a static graph.
  contexts.LinnanBulbBrowserNative={}
  local bp={aliases=aliasState,lines={},viewport={x=1280,y=720},color=settingsParam.color,onClose=function()error('unexpected close')end}
  local function child(tree,name)
    if type(tree)~='table'then return end
    if tree.recipe==name then return tree.param end
    for _,v in pairs(tree)do if type(v)=='table'then local found=child(v,name);if found then return found end end end
  end
  local home=render('LinnanBulbBrowserNative',bp)
  walk(home,function(_,p)if p.meta and p.meta.id=='linnan.bulb.browser.configure'then p.onClick()end end)
  local cp=assert(child(render('LinnanBulbBrowserNative',bp),'LinnanBulbSettingsContentNative'))
  local opened=false
  walk(render('LinnanBulbSettingsContentNative',cp),function(_,p)if p.meta and p.meta.id=='linnan.bulb.settings.presets'then p.onClick();opened=true end end)
  assert(opened)
  local presetPage=render('LinnanBulbBrowserNative',bp)
  assert(child(presetPage,'LinnanBulbPresetSettingsNative'))
  actions.LinnanBulbBrowserNative.IA_MENU_BACK()
  assert(child(render('LinnanBulbBrowserNative',bp),'LinnanBulbSettingsContentNative'))
  cp.showPresets()
  walk(render('LinnanBulbBrowserNative',bp),function(_,p)if p.meta and p.meta.id=='linnan.bulb.presets.back'then p.onClick()end end)
  assert(child(render('LinnanBulbBrowserNative',bp),'LinnanBulbSettingsContentNative'))
  unmounts.LinnanBulbBrowserNative()
  -- Both HUD and static diagrams use resolved track, station and transfer colors.
  local G=dofile('mod/content/gui/bulb_cockpit/merge.lua')
  local function service(id,ids)
    local stops={}
    for i,n in ipairs(ids)do stops[i]={id=n,name='Station '..n,sourceIndex=i-1,transfers={}}end
    stops[1].transfers={{id=900,name='RER transfer',mode='RER',color='#123456'}}
    return {id=id,name='Line '..id,mode='METRO',color='#123456',stops=stops}
  end
  local a,b=service(800,{1,2,3,4}),service(801,{5,2,3,4})
  aliases={__options={language='en',linePresets={METRO='shanghai',RER='munich'}}}
  for _,line in ipairs({a,b})do aliases[tostring(line.id)]={name=line.name,identifier='1',prefix='',suffix=''}end
  aliases['900']={name='RER transfer',prefix='S',identifier='1',suffix=''}
  local function near(actual,hex)
    assert(actual and math.abs(actual[1]-tonumber(hex:sub(2,3),16)/255)<.00001 and
      math.abs(actual[2]-tonumber(hex:sub(4,5),16)/255)<.00001 and
      math.abs(actual[3]-tonumber(hex:sub(6,7),16)/255)<.00001,'resolved color missing')
  end
  collect.read=function()return snapshot end
  collect.readLine=function()return snapshot end
  for _,branch in ipairs({false,true})do
    snapshot={vehicle=200,next=3,passed=2,route={lineId=a.id,name=a.name,mode=a.mode,color=a.color,stops=a.stops},
      lines={a,b},network=branch and assert(G.build({a,b})) or nil}
    local plan=V.decorate(P.plan(snapshot,aliases,true,1200),aliases,snapshot.route.color)
    assert(plan.color=='#e3002b' and plan.presentation.shape=='rectangle')
    for _,rail in ipairs(plan.rails or {})do assert(rail.color=='#e3002b')end
    assert(snapshot.route.color=='#123456' and a.stops[1].transfers[1].color=='#123456','never mutate collected game colors')
    for _,stop in ipairs(plan.stops)do
      if stop.id==1 then
        assert(not stop.lit,'presets cannot light a passed stop')
        assert(stop.transfers[1].color=='#1fbae7' and stop.transfers[1].presentation.shape=='capsule')
      end
    end
    tick()
    local hud=render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}})
    local rails=0
    walk(hud,function(_,p)
      local m=p.meta or {};local class=m.class or ''
      if class=='bulb-track' or class:find('bulb-branch-stroke',1,true)then
        near(m.styleSheet.backgroundColor1,'#e3002b');rails=rails+1
      end
    end)
    assert(rails>0)
    contexts.LinnanBulbStaticRouteNative={}
    local sp={lineId=800,aliases=aliasState,lines={a,b},viewport={x=1280,y=720},geometry=S.geometry({x=1280,y=720}),
      color=settingsParam.color,navigate=function()end,home=function()end,onClose=function()end,onReady=function()end}
    render('LinnanBulbStaticRouteNative',sp);mounts.LinnanBulbStaticRouteNative();join()
    local static=render('LinnanBulbStaticRouteNative',sp)
    local staticRails=0
    walk(static,function(_,p)
      local m=p.meta or {};local class=m.class or ''
      if class=='bulb-track' or class:find('bulb-branch-stroke',1,true)then near(m.styleSheet.backgroundColor1,'#e3002b');staticRails=staticRails+1 end
    end)
    assert(staticRails>0)
    unmounts.LinnanBulbStaticRouteNative()
  end
  -- Shapes use static shared primitives and retain their original click bounds.
  local _,_,badge=B.create(builtin,function(v)return {styleSheet=v}end,
    function(value,font,w,h,ink)return builtin.TextView{text=value,meta={styleSheet={size={w,h},fontSize=font,color=ink}}}end,
    function()return builtin.Component{}end)
  for _,mode in ipairs({'METRO','RER'})do
    local presentation=V.resolve(mode,mode=='METRO' and 'U7' or 'S1','#123456',{__options={linePresets={[mode]='munich'}}})
    local tile=badge(mode,mode=='METRO' and 'U7' or 'S1',{1,0,0,1},true,nil,nil,presentation)
    local masks=0
    walk(tile,function(kind,p)if kind=='ImageView'then masks=masks+1;assert(p.path:match('symbols/[%w-]+%.tga$'))end end)
    assert(tile.param.meta.styleSheet.size[1]==48 and tile.param.meta.styleSheet.size[2]==24)
    assert(masks==(mode=='METRO' and 1 or 2))
  end
  -- Wide city badges must fit their directory hit boxes and native map groups.
  aliases.__options.linePresets.METRO='munich'
  contexts.LinnanBulbBrowserNative={}
  local home=render('LinnanBulbBrowserNative',{aliases=aliasState,lines={a,b},viewport={x=1280,y=720},
    color=settingsParam.color,onClose=function()end})
  local tiles=0
  walk(home,function(kind,p)
    if kind=='Button' and p.meta.id=='linnan.bulb.browser.line.800'then
      assert(p.meta.styleSheet.size[1]>=58 and p.content.param.meta.styleSheet.size[1]==48)
      tiles=tiles+1
    end
  end)
  assert(tiles==1)
  tick()
  local hud=render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}})
  local fullLabels={}
  walk(hud,function(kind,p)
    if kind=='TextView' and p.meta.class=='bulb-transfer-label'then fullLabels[p.text]=true end
    if kind=='Component' and p.meta.class=='bulb-transfer-group'then
      assert(p.meta.styleSheet.size[1]>=71,'one 48px S badge plus icon and gap')
    end
  end)
  assert(fullLabels.S1,'native transfer glyph must contain S, not just the number')
  unmounts.LinnanBulbBrowserNative()
  print('PASS: native preset dropdowns, global/mixed state, acknowledgments, rollback, closing, 14-locale bounds, immutable plans and HUD/static branch colors')
end
]=],'@city_presets_ui'))()
