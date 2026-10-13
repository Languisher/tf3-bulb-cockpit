-- Narrow test double for the game's carrier-filter factory. The integration
-- test uses the locally compiled original game module instead.
return function(builtin)
  return {createCarrierCategoryFilter=function(categories,statsType,old,transform)
    assert(statsType==nil,'settings filter does not request map-visible-only checks')
    local buttons={}
    for i,category in ipairs(categories)do
      buttons[i]=builtin.ToggleButton{value=old().category[i] and 1 or 0,
        content=builtin.ImageView{path=category.imageFile,meta={class='category',tooltip=category.tooltip}},
        onValueChange=function(value)
          transform(function(before)
            local state={category={}}
            for key,enabled in pairs(before.category)do state.category[key]=enabled end
            state.category[i]=value==1;return state
          end)
        end}
    end
    return builtin.BoxLayout{orientation=builtin.type.Orientation.Horizontal,children=buttons}
  end}
end
