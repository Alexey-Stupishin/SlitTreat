function ass_slit_widget_fit_orders, idx = idx, mode = mode

ord0 = {text:'', fitmode:'', limit:0}
ord = replicate(ord0, 2)

ord[0].text = 'Linear'
ord[0].fitmode = 'linear'
ord[0].limit = 2

ord[1].text = '3rd Order'
ord[1].fitmode = 'bezier3'
ord[1].limit = 9

if n_elements(idx) eq 0 then return, ord[*].text
if mode eq 'fittype' then return, ord[idx].fitmode
if mode eq 'index' then begin
    return, where(ord[*].fitmode eq idx)
endif
if mode eq 'limit' then begin
    index = where(ord[*].fitmode eq idx)
    return, ord[index].limit
endif

end
