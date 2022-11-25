function ass_slit_widget_get_appr, points, fit_order, norm_poly, reper_pts, err = err

np = points.Count()
x = dblarr(np) 
y = dblarr(np) 
for k = 0, np-1 do begin
    x[k] = points[k].x 
    y[k] = points[k].y 
endfor    

case fit_order of
    'linear': order = 1
    'bezier3': order = 3
endcase
maxdist = asm_bezier_appr(x, y, order, norm_poly, iter, simpseed = simpseed, tlims = tlims, maxiter = 10000, err = err)

reper_pts = !NULL
if err eq 0 then asm_bezier_norm_vs_points, norm_poly, reper_pts, 0

return, iter

end  
