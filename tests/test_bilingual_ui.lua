local file=assert(io.open('tests/test_native.lua'));local harness=file:read('*a');file:close()
assert(load(harness..[=[
do
  local I=modules['localization.lua']
  local requests={}
  modules['aliases.lua'].saveOptions=function(value,callback)requests[#requests+1]={value=value,callback=callback}end
  local browser='LinnanBulbBrowserNative'
  contexts[browser]={}
  aliases={__options={flashNextStop=true,other=true,language='zh'}}
  local roster={{id=10,name='West Tram',mode='TRAM',color='#006db8'},
    {id=20,name='City Bus',mode='BUS',color='#ffcf00'}}
  local param={aliases=aliasState,lines=roster,geometry=S.geometry({x=1280,y=720}),viewport={x=1280,y=720},
    color=settingsParam.color,onClose=function()end,session={closed=false,lines=roster,owners={}}}
  local function controls(tree)
    local found={};walk(tree,function(kind,p)if p.meta and p.meta.id then found[p.meta.id]=p end end);return found
  end
  local function draw()return controls(render(browser,param))end
  local function selected(control)return control.items[control.value].param.content.param end
  local nativeNames={};for _,locale in ipairs(I.locales)do nativeNames[locale.name]=true end
  local function english(tree,allow)
    walk(tree,function(kind,p)
      for _,s in ipairs({p.text or '',p.placeholderText or '',p.title or '',p.meta and p.meta.tooltip or ''})do
        assert(not s:find('[\228-\233][\128-\191][\128-\191]') or nativeNames[s] or (allow and allow[s]),
          'untranslated UI in '..kind..': '..s)
      end
    end)
  end
  local button=draw()['linnan.bulb.browser.language']
  assert(#button.items==14 and selected(button).text=='简体中文' and selected(button).useUnicodeCompatibilityFont,
    'both languages remain discoverable with the native Unicode font')
  local initialReads=reads
  button.onValueChange(I.index('en'))
  assert(I.language(aliases)=='en' and #requests==1 and requests[1].value.language=='en')
  button.onValueChange(I.index('en'));assert(#requests==1,'ignore repeated click before callback')
  local pending=draw()
  assert(pending['linnan.bulb.browser.configure'].content.param.text=='Line settings'
    and selected(pending['linnan.bulb.browser.language']).text=='English'
    and not pending['linnan.bulb.browser.language'].meta.enabled,'first click updates the whole page immediately')
  assert(aliases.__options.flashNextStop and aliases.__options.other)
  aliases.__options.flashNextStop=false;aliases.concurrent={name='Concurrent edit'}
  requests[1].callback(nil,true);join()
  assert(draw()['linnan.bulb.browser.language'].meta.enabled and I.language(aliases)=='en'
    and not aliases.__options.flashNextStop and aliases.concurrent,'save acknowledgment preserves concurrent edits')
  assert(reads==initialReads and not timers[browser],'switching never polls vehicles or adds a timer')
  english(render(browser,param))
  assert(render('LinnanBulbSettingsWindowNative',param).param.title=='Route maps')
  pending['linnan.bulb.browser.configure'].onClick()
  local configNode
  local function find(v)
    if type(v)~='table'then return end
    if v.recipe=='LinnanBulbSettingsContentNative'then configNode=v;return end
    for _,child in pairs(v)do if type(child)=='table'then find(child)end end
  end
  find(render(browser,param));assert(configNode)
  contexts.LinnanBulbSettingsContentNative={}
  local editor=render('LinnanBulbSettingsContentNative',configNode.param);english(editor)
  assert(controls(editor)['linnan.bulb.settings.search'].placeholderText=='Search name')
  local row={line=roster[1],lines=roster,aliases=aliasState,geometry=configNode.param.geometry,
    lineColor=settingsParam.color(),message={set=function()end},defaults=P.defaults(roster,aliases)}
  contexts.LinnanBulbAliasRowNative={}
  english(render('LinnanBulbAliasRowNative',row))
  local towns={{id=100,name='Paris'}}
  contexts.LinnanBulbCityContentNative={}
  local city={aliases=aliasState,lines=roster,towns=towns,width=520,listHeight=200,onClose=function()end}
  english(render('LinnanBulbCityContentNative',city))
  assert(render('LinnanBulbCityWindowNative',city).param.title=='Bus numbering')
  local ok,err=P.validateBusCodes({expressCode='51',districts={['100']={name='杭州',code='A'}}},I.bind(aliases))
  assert(not ok and err=='The prefix for 杭州 must contain only digits; leave blank to skip.')
  contexts.LinnanBulbStationContentNative={}
  local station={aliases=aliasState,stations={},width=520,listHeight=200,onClose=function()end}
  english(render('LinnanBulbStationContentNative',station))
  assert(render('LinnanBulbStationWindowNative',station).param.title=='Link transfer stops')
  -- Names and user-entered affixes must remain byte-for-byte game data.
  roster[1].name='杭州电车';aliases['10']={name='杭州电车',prefix='快',identifier='1',suffix='支线'}
  assert(P.alias(roster[1],aliases,P.defaults(roster,aliases))=='快1支线')
  local route={lineId=10,name='杭州电车',mode='TRAM',stops={}}
  for i=1,40 do route.stops[i]={id=i,name='站 '..i,transfers={}}end
  local plan=P.plan({route=route,lines={roster[1]},next=20,passed=19},aliases,false,300,I.bind(aliases))
  assert(plan.name=='杭州电车' and plan.badge=='快1支线' and #plan.gaps>0)
  for _,gap in ipairs(plan.gaps)do assert(gap.text:match(' stops$'),'condensed map omissions use English')end
  for _,stop in ipairs(plan.stops)do assert(stop.fullName=='站 '..stop.index)end
  -- Return home, fail a switch, then retry and close before acknowledgment.
  controls(render(browser,param))['linnan.bulb.browser.back'].onClick()
  local switching=draw()['linnan.bulb.browser.language']
  switching.onValueChange(I.index('zh'));assert(I.language(aliases)=='zh')
  aliases.__options.flashNextStop=true
  requests[2].callback(nil,false);join()
  assert(I.language(aliases)=='en' and aliases.__options.flashNextStop)
  assert(draw()['linnan.bulb.browser.language'].meta.enabled)
  local errorFound=false
  walk(render(browser,param),function(kind,p)if p.text=='Could not save the language. Please retry.'then errorFound=true end end)
  assert(errorFound,'failed saves show an error in the restored language')
  draw()['linnan.bulb.browser.language'].onValueChange(I.index('zh'));assert(I.language(aliases)=='zh')
  param.session.closed=true
  requests[3].callback(nil,true);join()
  assert(I.language(aliases)=='zh','closing does not discard the saved language')
  -- Each new choice flows through the actual native selector and callbacks.
  param.session.closed=false;contexts[browser]={}
  local originalRequire=ug_require
  local loads={}
  ug_require=function(path)
    local locale=path:match('/locales/([%w-]+)%.lua$')
    if locale then
      loads[locale]=(loads[locale] or 0)+1
      return dofile('mod/content/gui/bulb_cockpit/locales/'..locale..'.lua')
    end
    return originalRequire(path)
  end
  for index,locale in ipairs(I.locales)do
    local ctrl=draw()['linnan.bulb.browser.language']
    local previous=I.language(aliases);local count=#requests
    ctrl.onValueChange(index)
    assert(I.language(aliases)==locale.code)
    local selectedControl=draw()['linnan.bulb.browser.language']
    assert(selected(selectedControl).text==locale.name)
    if locale.code~=previous then
      assert(#requests==count+1 and not selectedControl.meta.enabled)
      requests[#requests].callback(nil,true);join()
    else assert(#requests==count,'selecting the current language is a no-op')end
    local tree=render(browser,param)
    local page=controls(tree)
    assert(page['linnan.bulb.browser.configure'].content.param.text==I.bind(aliases)('线路设置'))
    assert(render('LinnanBulbSettingsWindowNative',param).param.title==I.bind(aliases)('线路图设置'))
  end
  for _,count in pairs(loads)do assert(count==1,'reuse each selected catalog')end
  assert(reads==initialReads and not timers[browser],'all-language switching adds no scans or timers')
  ug_require=originalRequire

  contexts[browser]={};param.session={closed=false,lines=roster,owners={}}
  assert(draw()['linnan.bulb.browser.configure'].content.param.text==I.bind(aliases)('线路设置'),'reopened windows read the saved preference')
end
print('PASS: bilingual native controls, optimistic switch, rollback, saved preference, literal game data and no extra timers')
]=],'@test_bilingual_ui.lua'))()
