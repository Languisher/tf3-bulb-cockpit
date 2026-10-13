local file=assert(io.open('tests/test_native.lua'));local harness=file:read('*a');file:close()
assert(load(harness..[=[
do
  for _,rule in ipairs(css)do
    assert(not rule.selector:find('*',1,true),'global BULB selectors must never have universal leaves')
  end
  local angles,scales=0,0
  for _,rule in ipairs(css)do
    if rule.selector:find('bulb-track-angle',1,true)then
      assert(rule.selector:match('^R::LinnanBulbTrackStrokeNative!'),
        'rotation bank must not target game-wide generic components')
      angles=angles+1
    end
    if rule.selector:find('bulb-canvas-scale',1,true)then
      assert(rule.selector:match('^R::LinnanBulbScaledCanvasNative!'),
        'scale bank must not target game-wide generic components')
      scales=scales+1
    end
  end
  assert(angles==181 and scales==0,'retain curve precision without a canvas scaling bank')
  local stroke=render('LinnanBulbTrackStrokeNative',{})
  assert(stroke.kind=='FloatingLayout' and #stroke.param.children==0,
    'the dedicated recipe owns the painted component; no nested rail nodes')
  print('PASS: rotation transforms target only the dedicated BULB native type, with no extra rail children')
end
]=],'@stylesheet_scope'))()
