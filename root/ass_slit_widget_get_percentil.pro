function ass_slit_widget_get_percentil, slit, level

sz = size(slit)

td = dblarr(sz[2], sz[3])
for ka = 0, sz[2]-1 do begin
    for kf = 0, sz[3]-1 do begin
        idx = sort(slit[*, ka, kf])
        res = slit[idx, ka, kf]
        idxc = round(double(sz[1]-1) * level)
        td[ka, kf] = res[idxc]
    endfor
endfor

return, td

end
