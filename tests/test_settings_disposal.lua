-- Keep old native callback/parameter trees alive deliberately: closing the
-- entry must release page data without depending on C++ unmount scheduling.
local file=assert(io.open('tests/test_native.lua'));local harness=file:read('*a');file:close()
assert(load(harness..[=[
do
  local entry,browser,static,content='LinnanBulbSettingsNative','LinnanBulbBrowserNative',
    'LinnanBulbStaticRouteNative','LinnanBulbSettingsContentNative'
  local weak=setmetatable({},{__mode='v'})
  local loads=0
  collect.listLines=function()
    return {{id=10,name='Tram 乘客-杭州-LO-1',mode='TRAM',color='#006db8'}}
  end
  collect.readLine=function(id)
    loads=loads+1
    local graph={static=true,next=0,passed=0,lines={},route={lineId=id,name='测试',mode='TRAM',color='#006db8',stops={}}}
    for i=1,100 do graph.route.stops[i]={id=i,name='站 '..i,transfers={}}end
    weak[loads]=graph;return graph
  end
  local param={aliases=aliasState,viewport={x=1280,y=720},color=function()return {.1,.4,.8,1}end}
  local function controls(tree)
    local result={}
    walk(tree,function(_,p)if p.meta and p.meta.id then result[p.meta.id]=p end end)
    return result
  end
  local function selected(tree)
    if type(tree)~='table'then return end
    if tree.recipe==static then return tree.param end
    for _,v in pairs(tree)do local found=selected(v);if found then return found end end
  end
  local retainedNativeParams={}
  for i=1,301 do
    contexts[entry]={};contexts[browser]={};contexts[static]={};contexts[content]={}
    controls(render(entry,param))['linnan.bulb.settings.toggle'].onValueChange(1)
    local window=assert(windowParam);retainedNativeParams[i]=window
    local c=controls(render(browser,window))
    c['linnan.bulb.browser.line.10'].onClick()
    local visit=assert(selected(render(browser,window)))
    render(static,visit);mounts[static]()
    if i%2==0 then join();render(static,visit)end
    local before=loads
    window.onClose() -- deliberately no browser/static onUnmount
    join()
    assert(loads==before,'close cancels a static read queued before native unmount')
    assert(contexts[static][1]:get().snapshot==nil,'close immediately releases the static graph')
    assert(window.session.closed and #window.lines==0 and next(window.session.owners)==nil,
      'close empties the roster and callback owners even while old window parameters survive')
    c['linnan.bulb.browser.line.10'].onClick()
    assert(contexts[browser][1]:old()==10,'expired native callbacks cannot navigate a closed session')
    unmounts[static]();unmounts[browser]();unmounts[entry]()
  end
  collectgarbage('collect');collectgarbage('collect')
  assert(next(weak)==nil,'301 closed windows retain no graphs even with old native parameter trees alive')

  contexts[entry]={};contexts[browser]={};contexts[content]={}
  controls(render(entry,param))['linnan.bulb.settings.toggle'].onValueChange(1)
  local window=windowParam
  controls(render(browser,window))['linnan.bulb.browser.configure'].onClick()
  render(content,window)
  local drafts=contexts[content][8]:get();drafts['10']={prefix='T',identifier='7',suffix=''}
  for i=1,100 do render(browser,window);render(content,window)end
  local owners=0;for _ in pairs(window.session.owners)do owners=owners+1 end
  assert(owners==2,'rerenders replace the two owner slots instead of appending cleanup callbacks')
  window.onClose()
  assert(next(drafts)==nil and #window.lines==0,'close clears unsaved editor drafts synchronously')
  controls(render(entry,param))['linnan.bulb.settings.toggle'].onValueChange(1)
  local reopened=windowParam
  window.onClose()
  assert(windowParam==reopened and #reopened.lines==1 and not reopened.session.closed,
    'a stale native close callback must not close or clear a newer window session')
  reopened.onClose()
  unmounts[content]();unmounts[browser]();unmounts[entry]()
  assert(not timers[entry] and not timers[browser] and not timers[static] and not timers[content],
    'settings pages must never own recurring timers')
  print('PASS: 301 closes before native disposal; zero retained graphs/rosters, cancelled joins, bounded owners and cleared drafts')
end
]=],'@settings_disposal'))()
