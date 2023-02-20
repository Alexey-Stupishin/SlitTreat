pro slittreat_widget_data
end

;----------------------------------------------------------------------------------
pro ass_slit_widget_make_bounds
compile_opt idl2

common G_ASS_SLIT_WIDGET, global

if ~global.hasKey('slitwidth') || ~global.hasKey('grids') $
|| global['grids'] eq !NULL $
|| ~global.hasKey('xmargimg') || ~global.hasKey('ymargimg') $
|| ~global.hasKey('data_shift') || ~global.hasKey('coef') $
|| global['data_shift'] eq !NULL $
|| ~global.hasKey('currpos') || ~global.hasKey('data_ind') $ 
|| global['currpos'] eq !NULL || global['data_ind'] eq !NULL then return

hwidth = global['slitwidth']
if hwidth gt 1 then begin
    grids = global['grids']
    sz = size(grids.x_grid)
    p0 = (sz[1]-1)/2
    from = p0-hwidth+1
    to   = p0+hwidth-1
    xy_left = dblarr(2, sz[2])
    for k = 0, sz[2]-1 do begin
        xy_left[*, k] = ass_slit_widget_convert([grids.x_grid[from, k], grids.y_grid[from, k]], mode = 'dat2win')
    endfor
    global['left_bound'] = xy_left
    xy_right = dblarr(2, sz[2])
    for k = 0, sz[2]-1 do begin
        xy_right[*, k] = ass_slit_widget_convert([grids.x_grid[to, k], grids.y_grid[to, k]], mode = 'dat2win')
    endfor
    global['right_bound'] = xy_right
endif else begin
    global['left_bound'] = !NULL
    global['right_bound'] = !NULL
endelse

end

;----------------------------------------------------------------------------------
function ass_slit_widget_in_scope, xy, xycorr = xycorr
compile_opt idl2

common G_ASS_SLIT_WIDGET, global

xycorr = xy

if global['data_list'] eq !NULL then return, 0

xycorr[0] = global['arc_from', 0] > xy[0] < global['arc_to', 0]
xycorr[1] = global['arc_from', 1] > xy[1] < global['arc_to', 1]

return, xycorr[0] eq xy[0] && xycorr[1] eq xy[1]

end

;----------------------------------------------------------------------------------
function ass_slit_widget_impoint_to_arc, pt, ind
compile_opt idl2

common G_ASS_SLIT_WIDGET, global

return, (pt - ([ind.naxis1, ind.naxis2]-1d)*0.5d)*[ind.cdelt1, ind.cdelt2] + [ind.xcen, ind.ycen]

end

;----------------------------------------------------------------------------------
function ass_slit_widget_impoint_from_arc, pt, ind
compile_opt idl2

common G_ASS_SLIT_WIDGET, global

return, (pt - [ind.xcen, ind.ycen])/[ind.cdelt1, ind.cdelt2] + ([ind.naxis1, ind.naxis2]-1d)*0.5d 

end

;----------------------------------------------------------------------------------
pro ass_slit_widget_store_arc_range, ind
compile_opt idl2

common G_ASS_SLIT_WIDGET, global

sz = size(global['data_list'])
global['arc_from'] = ass_slit_widget_impoint_to_arc([0, 0], ind)
global['arc_to'] = ass_slit_widget_impoint_to_arc(sz[1:2], ind)

end

;----------------------------------------------------------------------------------
function ass_slit_widget_convert, xy, mode = mode
compile_opt idl2

common G_ASS_SLIT_WIDGET, global
common G_ASS_SLIT_WIDGET_SET, settings

xmargpix = global['xmargimg'] * !d.x_ch_size * settings['charsize']
ymargpix = global['ymargimg'] * !d.y_ch_size * settings['charsize']

ind0 = global['data_ind', 0]
out = dblarr(2)
if n_elements(mode) gt 0 && mode eq 'win2dat' then begin
    out[0] = double(xy[0]-global['data_shift', 0] - xmargpix[0])*global['coef']
    out[1] = double(xy[1]-global['data_shift', 1] - ymargpix[0])*global['coef']
    out = ass_slit_widget_impoint_to_arc(out, ind0)
endif else begin
    out = xy
endelse    

return, out

end

;----------------------------------------------------------------------------------
pro ass_slit_widget_show_image, mode = mode, drag = drag
compile_opt idl2

common G_ASS_SLIT_WIDGET, global
common G_ASS_SLIT_WIDGET_SET, settings

if global['data_list'] eq !NULL then return
sz = size(global['data_list'])

if n_elements(drag) eq 0 then drag = 0

if global['xy_rt_dat'] eq !NULL && (n_elements(mode) gt 0 && mode eq 'SELWIN') then mode = 'FITWIN'

winsize = global['winsize']
xmargpix = global['xmargimg'] * !d.x_ch_size * settings['charsize']
ymargpix = global['ymargimg'] * !d.y_ch_size * settings['charsize']
picsize = [winsize[0] - xmargpix[0] - xmargpix[1], winsize[1] - ymargpix[0] - ymargpix[1]]
ind0 = global['data_ind', 0]

is_new = global['byte_list'] eq !NULL

if global['byte_info'] eq !NULL then global['byte_info'] = lonarr(sz[3])
if is_new then global['byte_list'] = dblarr(picsize[0], picsize[1], sz[3])

if is_new || (n_elements(mode) gt 0 && (mode eq 'MAKESELECT' || global['drawmode'] ne mode)) then begin
    if n_elements(mode) gt 0 && mode eq 'MAKESELECT' then mode = 'SELWIN'
    if n_elements(mode) eq 0 then mode = 'ACTSIZE'
    global['drawmode'] = mode
    case mode of
        'ACTSIZE': begin
            corn = long((picsize-sz[1:2])/2d)
            global['data_shift'] = corn
            global['coef'] = 1d
            for d = 0, 1 do begin
                if corn[d] ge 0 then begin
                    global['dat_range', d, 0] = 0
                    global['dat_range', d, 1] = sz[d+1]-1
                    global['win_range', d, 0] = corn[d]
                    global['win_range', d, 1] = sz[d+1]-1 + corn[d]
                endif else begin
                    global['dat_range', d, 0] = -corn[d]
                    global['dat_range', d, 1] = picsize[d]-1 - corn[d]
                    global['win_range', d, 0] = 0
                    global['win_range', d, 1] = picsize[d]-1
                endelse    
             endfor   
        end
            
        'FITWIN': begin
            global['coef'] = asu_get_scale_keep_ratio(picsize, [0, 0], sz[1:2]-1, newsize)
            global['newsize'] = newsize
            delta = round((picsize-newsize)/2d)
            global['data_shift'] = delta
            for d = 0, 1 do begin
                global['dat_range', d, 0] = 0
                global['dat_range', d, 1] = sz[d+1]-1
                global['win_range', d, 0] = delta[d]
                global['win_range', d, 1] = newsize[d]-1 + delta[d]
            endfor
        end
        
        'SELWIN': begin
            xy_lb_dat_arc = global['xy_lb_dat']
            xy_rt_dat_arc = global['xy_rt_dat']
            xy_lb_dat = ass_slit_widget_impoint_from_arc(xy_lb_dat_arc, ind0)
            xy_rt_dat = ass_slit_widget_impoint_from_arc(xy_rt_dat_arc, ind0)
            global['coef'] = asu_get_scale_keep_ratio(picsize, xy_lb_dat, xy_rt_dat, newsize)
            global['newsize'] = newsize
            global['dat_range', 0, 0] = xy_lb_dat[0]
            global['dat_range', 0, 1] = xy_rt_dat[0]
            global['dat_range', 1, 0] = xy_lb_dat[1]
            global['dat_range', 1, 1] = xy_rt_dat[1]
            delta = round((picsize-newsize)/2d)
            for d = 0, 1 do begin
                global['win_range', d, 0] = delta[d]
                global['win_range', d, 1] = newsize[d]-1 + delta[d]
            endfor
            global['data_shift'] = [global['win_range', 0, 0] - round(xy_lb_dat[0]/global['coef']), global['win_range', 1, 0] - round(xy_lb_dat[1]/global['coef'])]
        end    
    endcase
endif 

p = global['currpos']
dat_range = global['dat_range']
win_range = global['win_range']
if global['byte_info', p] eq 0 || ~drag then begin
    if global['drawmode'] eq 'ACTSIZE' then begin
        res = global['data_list', dat_range[0, 0]:dat_range[0, 1], dat_range[1, 0]:dat_range[1, 1], p]
    endif else begin
        newsize = global['newsize']
        coef = global['coef']
        res = bilinear(global['data_list', dat_range[0, 0]:dat_range[0, 1], dat_range[1, 0]:dat_range[1, 1], p], indgen(newsize[0])*coef, indgen(newsize[1])*coef)
    endelse
    base0 = dblarr(picsize[0], picsize[1])
    base0[win_range[0, 0]:win_range[0, 1], win_range[1, 0]:win_range[1, 1]] = res
    scbase = bytscl(base0)
    if settings['backwhite'] then begin    
        base = bytarr(picsize[0], picsize[1]) + 255
        base[win_range[0, 0]:win_range[0, 1], win_range[1, 0]:win_range[1, 1]] = scbase[win_range[0, 0]:win_range[0, 1], win_range[1, 0]:win_range[1, 1]]
        scbase = base
    endif    
    global['byte_list', *, *, p] = scbase
    global['byte_info', p] = 1
end

asw_control, 'IMAGE', GET_VALUE = drawID
WSET, drawID
!p.background = settings['colorback']
!P.CHARSIZE = settings['charsize']
device, decomposed = 0
loadct, 0, /silent

darc = global['arc_to'] - global['arc_from']
dx = ind0.cdelt1*global['coef']
dy = ind0.cdelt2*global['coef']
x0 = global['arc_from', 0] - global['data_shift', 0]*dx
x1 = x0 + picsize[0]*dx
y0 = global['arc_from', 1] - global['data_shift', 1]*dy
y1 = y0 + picsize[1]*dy
xrange = [x0, x1]
x_arg = xrange
yrange = [y0, y1]
y_arg = yrange

title = asu_lang_convert(settings['cyrillic'], ' ”гл. с.', 'arcsec') ; 1252 codepage
asu_tvplot_as, global['byte_list', *, *, p], x_arg, y_arg, xrange = xrange, yrange = yrange $
                , xmargin = global['xmargimg'], ymargin = global['ymargimg'] $
                , color = settings['colorplot'] $
                , xtitle = title, ytitle = title, scale = 0

hideall = widget_info(asw_getctrl('HIDEALL'), /BUTTON_SET)
hidemark = widget_info(asw_getctrl('HIDEAPPR'), /BUTTON_SET)
editappr = widget_info(asw_getctrl('EDITAPPR'), /BUTTON_SET)

if hideall && ~editappr then return

device, decomposed = 1

if ~hidemark && ~editappr && global['points'].Count() gt 0 then begin
    for k = 0, global['points'].Count()-1 do begin
        x = (global['points'])[k].x 
        y = (global['points'])[k].y 
        xy = ass_slit_widget_convert([x, y], mode = 'dat2win')
        oplot, [xy[0]], [xy[1]], psym = 2, symsize = 1.5, thick = 1.5, color = '00FF00'x
    endfor    
endif

if global['approx'] ne !NULL then begin
    xy = global['approx']
    sz = size(xy)
    for k = 0, sz[2]-1 do begin
        xy[*, k] = ass_slit_widget_convert(xy[*, k], mode = 'dat2win')
    endfor
    hwidth = global['slitwidth']
    thick = hwidth gt 1 && ~editappr ? 0.5 : 1.5    
    oplot, xy[0, *], xy[1, *], thick = thick, color = 'FF00FF'x
    
    if ~editappr then begin
        if hwidth gt 1 then begin
            grids = global['grids']
            sz = size(grids.x_grid)
            p0 = (sz[1]-1)/2
            from = p0-hwidth+1
            to   = p0+hwidth-1
            xy = dblarr(2, sz[2])
            for k = 0, sz[2]-1 do begin
                xy[*, k] = ass_slit_widget_convert([grids.x_grid[from, k], grids.y_grid[from, k]], mode = 'dat2win')
            endfor
            oplot, xy[0, *], xy[1, *], thick = 1.5, color = 'FFC0FF'x
            xy = dblarr(2, sz[2])
            for k = 0, sz[2]-1 do begin
                xy[*, k] = ass_slit_widget_convert([grids.x_grid[to, k], grids.y_grid[to, k]], mode = 'dat2win')
            endfor
            oplot, xy[0, *], xy[1, *], thick = 1.5, color = 'FFD0FF'x
        endif
    endif
endif

if global['appredit'] && global['reper_pts'] ne !NULL then begin
    xy0 = global['reper_pts']
    xy = ass_slit_widget_convert(xy0[*, 0], mode = 'dat2win')
    oplot, [xy[0]], [xy[1]], psym = 6, symsize = 2, thick = 1.5, color = 'FF0000'x
    for k = 1, 3 do begin
        xyp = xy
        xy = ass_slit_widget_convert(xy0[*, k], mode = 'dat2win')
        oplot, [xy[0]], [xy[1]], psym = 6, symsize = 2, thick = 2, color = 'FF0000'x
        oplot, [xyp[0], xy[0]], [xyp[1], xy[1]], thick = 1.5, color = 'FF0000'x
    endfor
endif


end

;----------------------------------------------------------------------------------
pro ass_slit_widget_clear_appr
compile_opt idl2

common G_ASS_SLIT_WIDGET, global

global['approx'] = !NULL
global['markup'] = !NULL
global['grids'] = !NULL
global['straight'] = !NULL
global['speed_first_pt'] = !NULL
global['speed_list'] = list()
global['timedist'] = !NULL
global['reper_pts'] = !NULL
asw_control, 'SLIT', GET_VALUE = drawID
asw_control, 'EDITAPPR', SET_BUTTON = 0
WSET, drawID
erase
ass_slit_widget_show_image

end

;----------------------------------------------------------------------------------
pro ass_slit_widget_export_image
compile_opt idl2

common G_ASS_SLIT_WIDGET, global
common G_ASS_SLIT_WIDGET_PREF, pref
common G_ASW_WIDGET, asw_widget

ind = global['data_ind', global['currpos']]
expr = stregex(ind.date_obs, '.*T([0-9][0-9]):([0-9][0-9]):([0-9][0-9]).*',/subexpr,/extract)
fname = 'Image-' + global['proj_name'] + '-' + expr[1] + expr[2] + expr[3]
file = dialog_pickfile(DEFAULT_EXTENSION = 'png', FILTER = ['*.png'], GET_PATH = path, PATH = pref['export_path'], file = fname, /write, /OVERWRITE_PROMPT)
if file eq '' then return

WIDGET_CONTROL, /HOURGLASS

asw_control, 'IMAGE', GET_VALUE = drawID
WSET, drawID
write_png, file, tvrd(true=1)
pref['export_path'] = path
save, filename = pref['pref_path'], pref

end
