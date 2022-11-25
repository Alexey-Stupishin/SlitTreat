function ass_slit_data2grid, data, grids, ind0
compile_opt idl2

common G_ASS_SLIT_WIDGET, global

szg = size(grids.x_grid)
szd = size(data)
if szd[0] eq 2 then szd[3] = 1
stratned = dblarr(szg[1], szg[2], szd[3])

nans = where(grids.x_grid lt global['arc_from', 0] or grids.x_grid ge global['arc_to', 0] or grids.y_grid lt global['arc_from', 1] or grids.y_grid ge global['arc_to', 1], count)

datx = dblarr(szg[1], szg[2])
daty = dblarr(szg[1], szg[2])
for k = 0, szg[1]-1 do begin
    for p = 0, szg[2]-1 do begin
        xy_lb_dat = ass_slit_widget_impoint_from_arc([grids.x_grid[k, p], grids.y_grid[k, p]], ind0)
        datx[k, p] = xy_lb_dat[0] 
        daty[k, p] = xy_lb_dat[1] 
    endfor
endfor            

for k = 0, szd[3]-1 do begin
    strt = bilinear(data[*, *, k], datx, daty)
    if count gt 0 then begin
        strt[nans] = !values.f_nan
    endif
    stratned[*, *, k] = strt
endfor

return, stratned

end
