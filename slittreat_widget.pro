;----------------------------------------------------------------------------------
pro ass_slit_widget_save_as, save_proj = save_proj
compile_opt idl2

common G_ASS_SLIT_WIDGET, global
common G_ASS_SLIT_WIDGET_PREF, pref
common G_ASW_WIDGET, asw_widget

WIDGET_CONTROL, /HOURGLASS

file = ''
if n_elements(save_proj) gt 0 && file_test(pref['proj_file']) then begin
    file = pref['proj_file']
endif else begin
    asw_control, 'FROMFILETEXT', GET_VALUE = str
    expr = stregex(str, '.*([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]).*',/subexpr,/extract)
    global['proj_name'] = expr[1]
    file = dialog_pickfile(DEFAULT_EXTENSION = 'spr', FILTER = ['*.spr'], GET_PATH = path, PATH = pref['proj_path'], file = expr[1], /write, /OVERWRITE_PROMPT)
    if file ne '' then begin
        pref['proj_path'] = path
        pref['proj_file'] = file
        save, filename = pref['pref_path'], pref 
    endif
endelse

save, filename = file, global
    
global['modified'] = 0
;ass_slit_widget_set_ctrl
        
end

;----------------------------------------------------------------------------------
pro ass_slit_widget_load, last_proj = last_proj
compile_opt idl2

common G_ASS_SLIT_WIDGET, global
common G_ASS_SLIT_WIDGET_PREF, pref
common G_ASW_WIDGET, asw_widget

WIDGET_CONTROL, /HOURGLASS

file = ''
if n_elements(last_proj) gt 0 && file_test(pref['proj_file']) then begin
    file = pref['proj_file']
endif else begin
    file = dialog_pickfile(DEFAULT_EXTENSION = 'spr', FILTER = ['*.spr'], GET_PATH = path, PATH = pref['proj_path'], file = pref['proj_file'], /read, /must_exist)
    if file ne '' then begin
        pref['proj_path'] = path
        pref['proj_file'] = file
        save, filename = pref['pref_path'], pref
    endif
endelse

if file eq '' then return

restore, file, /RELAXED_STRUCTURE_ASSIGNMENT

ass_slit_widget_add_keys

global['modified'] = 0
global['animation'] = 0
global['appredit'] = 0
global['byte_list'] = !NULL
global['byte_info'] = !NULL
ass_slit_widget_set_ctrl
asw_control, 'HIDEAPPR', SET_BUTTON = 0
asw_control, 'HIDEALL', SET_BUTTON = 0
asw_control, 'EDITAPPR', SET_BUTTON = 0

ass_slit_widget_make_bounds

end

;----------------------------------------------------------------------------------
pro ass_slit_widget_set_ctrl
compile_opt idl2

common G_ASS_SLIT_WIDGET, global
common G_ASS_SLIT_WIDGET_PREF, pref
common G_ASW_WIDGET, asw_widget

if global['proj_name'] ne '' then asw_control, 'SLITTREAT', BASE_SET_TITLE = 'SlitTreat - ' + global['proj_name']

asw_control, 'FROMFILETEXT', SET_VALUE = global['fromfile']
asw_control, 'TOFILETEXT', SET_VALUE = global['tofile']
asw_control, global['drawmode'], SET_BUTTON = 2
asw_control, 'ORDER', SET_DROPLIST_SELECT = ass_slit_widget_fit_orders(idx = global['fit_order'], mode = 'index')
sz = size(global['data_list'])
asw_control, 'SLIDER', SET_SLIDER_MIN = 1
asw_control, 'SLIDER', SET_SLIDER_MAX = sz[3]
asw_control, 'SLIDER', SET_VALUE = global['currpos'] + 1
asw_control, 'FRATE', SET_VALUE = round(global['framerate'])

ind = global['data_ind', global['currpos']]
asw_control, 'FRAMEDATE', SET_VALUE = asu_extract_time(ind.date_obs, out_style = 'asu_time_std')

asw_control, 'SLITWIDTH', SET_VALUE = global['slitwidth']
asw_control, global['slitmode'], SET_BUTTON = 1

asw_control, 'EDITAPPR', SET_BUTTON = 0
asw_control, 'ACTTIME', SET_BUTTON = 0

asw_control, 'SLITCONTR', SET_VALUE = global['slitcontr']
asw_control, 'SLITBRIGHT', SET_VALUE = global['slitbright']

ass_slit_widget_show_image
ass_slit_widget_get_timedist
ass_slit_widget_show_slit

end

;----------------------------------------------------------------------------------
function ass_slit_widget_need_save
compile_opt idl2

common G_ASS_SLIT_WIDGET, global

if global['data_list'] ne !NULL && global['modified'] then begin
    result = DIALOG_MESSAGE('All results will be lost! Exit anyway?', title = 'SlitTreat', /QUESTION)
    return, result eq 'Yes' ? 0 : 1
endif else begin
    return, 0
endelse    

end

;----------------------------------------------------------------------------------
pro ass_slit_widget_buttons_event, event
compile_opt idl2

common G_ASS_SLIT_WIDGET, global
common G_ASS_SLIT_WIDGET_PREF, pref
common G_ASW_WIDGET, asw_widget

if (tag_names(event, /structure_name) eq 'WIDGET_KILL_REQUEST') then begin
    if ~ass_slit_widget_need_save() then widget_control, event.top, /destroy
    return
endif

if TAG_NAMES(event, /STRUCTURE_NAME) eq  'WIDGET_TIMER' then begin
    eventval = 'TIMER'
endif else begin
    WIDGET_CONTROL, event.id, GET_UVALUE = eventval
endelse         

global['modified'] = 1

case eventval of
    'IMAGE' : begin
        if global['data_list'] eq !NULL then return
        sname = TAG_NAMES(event, /STRUCTURE_NAME)
;        case sname of
;            'WIDGET_DRAW': print, 'Draw, Type=' + string(event.type) + ' Press=' + string(event.press*1L) + ' Release=' + string(event.release*1L) + ' x=' + string(event.x) + ' y=' + string(event.y) $
;                                + ' Clicks=' + string(event.clicks) + ' Mod=' + string(event.modifiers) + ' Key=' + string(event.key)
;        endcase
        asw_control, 'HIDEAPPR', SET_BUTTON = 0
        asw_control, 'HIDEALL', SET_BUTTON = 0
        if global['appredit'] then begin
            if global['reper_pts'] eq !NULL then return
            case event.type of
                0: begin ; capture point
                    xy = ass_slit_widget_convert([event.x, event.y], mode = 'win2dat')
                    dists = dblarr(4)
                    for k = 0, 3 do begin
                        dists[k] = (xy[0] - global['reper_pts', 0, k])^2 + (xy[1] - global['reper_pts', 1, k])^2 
                    endfor
                    dm = min(dists, im)
                    if dm lt 400 then begin
                        ;print, 'Capture point: ' + string(im) + ' xy = [' + string(event.x) + ',' + string(event.y) + '], d = ' + string(sqrt(dm))
                        global['pt_to_drag'] = im
                        WIDGET_CONTROL, event.id, DRAW_MOTION_EVENTS = 1
                    endif
                end
                
                1: begin
                    WIDGET_CONTROL, event.id, DRAW_MOTION_EVENTS = 0
                    xy = ass_slit_widget_convert([event.x, event.y], mode = 'win2dat')
                    global['pt_to_drag'] = -1
                    global['approx'] = asm_bezier_create_line(global['reper_pts'], points = 1000) 
                    ;print, 'Finish capture: xy = [' + string(event.x) + ',' + string(event.y) + ']'
                    ass_slit_widget_make_bounds
                    ass_slit_widget_show_image
                    ass_slit_widget_update_td
                end
                
                2: begin
                    if global['pt_to_drag'] lt 0 then return
                    xy = ass_slit_widget_convert([event.x, event.y], mode = 'win2dat')
                    global['reper_pts', 0, global['pt_to_drag']] = xy[0]
                    global['reper_pts', 1, global['pt_to_drag']] = xy[1]
                    global['approx'] = asm_bezier_create_line(global['reper_pts'], points = 100) 
                    ;print, 'Drag capture: xy = [' + string(event.x) + ',' + string(event.y) + ']'
                    ass_slit_widget_show_image
                end
            endcase    
            return
        endif    
        if event.type eq 0 and event.modifiers eq 2 then begin ; start selection
            xy = ass_slit_widget_convert([event.x, event.y], mode = 'win2dat')
            if ~ass_slit_widget_in_scope(xy) then return
            WIDGET_CONTROL, event.id, DRAW_MOTION_EVENTS = 1
            global['xr'] = xy[0]
            global['yr'] = xy[1]
            global['select'] = 1
            ;print, string(event.x) + ', ' + string(event.y)
        endif else begin
            case event.type of
                0: begin
                    case event.press of
                        1: begin ; click point
                            xy = ass_slit_widget_convert([event.x, event.y], mode = 'win2dat')
                            if ~ass_slit_widget_in_scope(xy) then return
                            global['points'].Add, {x:xy[0], y:xy[1]}
                        end
                        
                        4: begin ; undo click point
                            if global['points'].Count() gt 0 then begin
                                global['points'].Remove
                            endif    
                        end        
                        
                        else: begin
                        end        
                    endcase    
                    ass_slit_widget_show_image
                end

                1: begin
                    WIDGET_CONTROL, event.id, DRAW_MOTION_EVENTS = 0 ; release button
                    if global['select'] eq 1 then begin ; release selection
                        xy = ass_slit_widget_convert([event.x, event.y], mode = 'win2dat')
                        xx = minmax([global['xr'], xy[0]])
                        yy = minmax([global['yr'], xy[1]])
                        ;xy_lb_dat_t = long(ass_slit_widget_convert([xx[0], yy[0]], mode = 'win2dat'))
                        xy_lb_dat_t = [xx[0], yy[0]]
                        in_scope = ass_slit_widget_in_scope(xy_lb_dat_t, xycorr = xy_lb_dat)
                        ;xy_rt_dat_t = long(ass_slit_widget_convert([xx[1], yy[1]], mode = 'win2dat'))
                        xy_rt_dat_t = [xx[1], yy[1]]
                        in_scope = ass_slit_widget_in_scope(xy_rt_dat_t, xycorr = xy_rt_dat)
                        global['xy_lb_dat'] = xy_lb_dat
                        global['xy_rt_dat'] = xy_rt_dat
                        asw_control, 'SELWIN', SET_BUTTON = 1
                        ass_slit_widget_show_image, mode = 'MAKESELECT'
                    end    
                    global['select'] = 0
                end
                
                else: begin
                end        
            endcase  
        endelse            
        if event.type eq 2 then begin
            ass_slit_widget_show_image, /drag
            device, decomposed = 1
            rcolor = 150
            rthick = 2
            t = ass_slit_widget_convert([event.x, event.y], mode = 'win2dat')
            xy = ass_slit_widget_convert(t, mode = 'dat2win')
            xy0 = ass_slit_widget_convert([global['xr'], global['yr']], mode = 'dat2win')
            xr = xy0[0]
            yr = xy0[1]
            oplot, [xr, xr], [yr, xy[1]], color = rcolor, thick = rthick
            oplot, [xy[0], xy[0]], [yr, xy[1]], color = rcolor, thick = rthick
            oplot, [xr, xy[0]], [yr, yr], color = rcolor, thick = rthick
            oplot, [xr, xy[0]], [xy[1], xy[1]], color = rcolor, thick = rthick
            ;print, string(xr) + '-' + string(event.x) + ', ' + string(yr) + '-' + string(event.y)
        endif    
    end
        
    'SLIDER' : begin
        if global['data_list'] eq !NULL then return
        
        asw_control, 'SLIDER', GET_VALUE = pos
        global['currpos'] = pos-1
        ind = global['data_ind', global['currpos']]
        asw_control, 'FRAMEDATE', SET_VALUE = ind.date_obs
        ass_slit_widget_show_image
        ass_slit_widget_show_slit
    end
        
    'FITWIN' : begin
        if event.select eq 0 then return
        ass_slit_widget_show_image, mode = 'FITWIN'
    end
    'ACTSIZE' : begin
        if event.select eq 0 then return
        ass_slit_widget_show_image, mode = 'ACTSIZE' 
    end
    'SELWIN' : begin
        if event.select eq 0 then return
        ass_slit_widget_show_image, mode = 'SELWIN'
    end
        
    'PROCEED' : begin
        ;if ass_slit_widget_need_save() then return 
        WIDGET_CONTROL, /HOURGLASS
        ass_slit_widget_cleanup
        global['data_list'] = asu_get_file_sequence_data(pref['path'], global['fromfile'], global['tofile'], ind = ind, err = err, cadence = cadence, jd_list = jd_list)
        global['data_ind'] = ind 
        case err of
            1: result = DIALOG_MESSAGE('Please select both first and last files!', title = 'SlitTreat Error', /ERROR)
            2: result = DIALOG_MESSAGE('Not enough files found!', title = 'SlitTreat Error', /ERROR)
            else: begin
                sz = size(global['data_list'])
                global['cadence'] = cadence
                global['jd_list'] = jd_list
                global['currpos'] = 0
                ass_slit_widget_store_arc_range, ind[0]
                global['byte_list'] = !NULL
                global['slit_list'] = !NULL
                asw_control, 'ACTSIZE', SET_BUTTON = 1
                ass_slit_widget_show_image, mode = 'ACTSIZE'
                asw_control, 'SLIDER', SET_SLIDER_MIN = 1
                asw_control, 'SLIDER', SET_SLIDER_MAX = sz[3]
                asw_control, 'SLIDER', SET_VALUE = global['currpos'] + 1
                pref['proj_file'] = ''
                ass_slit_widget_show_slit
            endelse    
        endcase    
    end

    'FILEFROM' : begin
        ;if ass_slit_widget_need_save() then return 
        file = dialog_pickfile(DEFAULT_EXTENSION = 'fits', FILTER = ['*.fits'], GET_PATH = path, PATH = pref['path'])
        if file ne '' then begin
            pref['path'] = path
            save, filename = pref['pref_path'], pref
            global['fromfile'] = file_basename(file)
            asw_control, 'FROMFILETEXT', SET_VALUE = global['fromfile']
            pref['proj_file'] = ''                
        endif
    end

    'FILETO' : begin
        ;if ass_slit_widget_need_save() then return 
        file = dialog_pickfile(DEFAULT_EXTENSION = 'fits', FILTER = ['*.fits'], GET_PATH = path, PATH = pref['path'])
        if file ne '' then begin
            pref['path'] = path
            save, filename = pref['pref_path'], pref
            global['tofile'] = file_basename(file)
            asw_control, 'TOFILETEXT', SET_VALUE = global['tofile']  
            pref['proj_file'] = ''                
        endif
    end

    'ORDER' : begin
        fit_order = widget_info(asw_getctrl('ORDER'), /DROPLIST_SELECT)
        global['fit_order'] = ass_slit_widget_fit_orders(idx = fit_order, mode = 'fittype')
    end

    'FIT' : begin
        fittype = global['fit_order']
        limpts = ass_slit_widget_fit_orders(idx = fittype, mode = 'limit')
        if global['points'].Count() lt limpts then begin
            result = DIALOG_MESSAGE('Number of points for selected approximation should be no less than ' + asu_compstr(limpts) + '.', title = 'SlitTreat Error', /ERROR)
            return
        endif
            
        WIDGET_CONTROL, /HOURGLASS

        t0 = systime(/seconds)
        iter = ass_slit_widget_get_appr(global['points'], fittype, norm_poly, reper_pts, err = err)
        if err eq 1 then begin
            result = DIALOG_MESSAGE('Too many fitting iterations! Please try another markup.', title = 'SlitTreat Error', /ERROR)
            return
        endif    
        
        ; asu_sec2hms(systime(/seconds)-t0, /issecs)        
        message, 'Number of iteration = ' + asu_compstr(iter), /info

        ass_slit_widget_clear_appr
        global['reper_pts'] = reper_pts
        global['approx'] = asm_bezier_create_line(reper_pts, points = 1000)
        
        ass_slit_widget_update_td
        ass_slit_widget_make_bounds
        
        ass_slit_widget_show_image
    end

    'EDITAPPR' : begin
        global['appredit'] = widget_info(asw_getctrl('EDITAPPR'), /BUTTON_SET)
        ass_slit_widget_show_image
    end
    
    'ACTTIME' : begin
        ass_slit_widget_show_slit
    end

    'CLEAR' : begin
        global['points'] = list()
        asw_control, 'IMAGE', GET_VALUE = drawID
        WSET, drawID
        erase
        ass_slit_widget_clear_appr
        ass_slit_widget_show_slit
    end

    'CLEARAPPR' : begin
        ass_slit_widget_clear_appr
        ass_slit_widget_show_slit
    end

    'SAVEAS' : begin
        if global['data_list'] eq !NULL then begin
            result = DIALOG_MESSAGE('Nothing to save!', title = 'SlitTreat Error', /ERROR)
            return
        endif    
        ass_slit_widget_save_as
    end

    'SAVE' : begin
        if global['data_list'] eq !NULL then begin
            result = DIALOG_MESSAGE('Nothing to save!', title = 'SlitTreat Error', /ERROR)
            return
        endif
            
        ass_slit_widget_save_as, /save_proj
    end

    'LOAD' : begin
        ass_slit_widget_load
    end

    'LAST' : begin
        ass_slit_widget_load, /last_proj
    end

    'EXPIMAGE' : begin
        if global['data_list'] eq !NULL then begin
            result = DIALOG_MESSAGE('Nothing to export!', title = 'SlitTreat Error', /ERROR)
            return
        endif    
        
        WIDGET_CONTROL, /HOURGLASS
        ass_slit_widget_export_image
    end
    
    'HIDEAPPR' : begin
        ass_slit_widget_show_image
    end
    
    'HIDEALL' : begin
        ass_slit_widget_show_image
    end
    
    'FRATE' : begin
        asw_control, 'FRATE', GET_VALUE = rate
        global['framerate'] = rate
    end
    
    'START' : begin
        if global['data_list'] eq !NULL then return
        if global['animation'] then return
        global['animation'] = 1
        WIDGET_CONTROL, event.ID, TIMER = 0
    end
    
    'STOP' : begin
        global['animation'] = 0
    end
    
    'TIMER' : begin
        if global['animation'] eq 0 then return
        global['currpos'] += 1
        if global['currpos'] ge n_elements(global['data_ind']) then global['currpos'] = 0 
        asw_control, 'SLIDER', SET_VALUE = global['currpos']
        ind = global['data_ind', global['currpos']]
        asw_control, 'FRAMEDATE', SET_VALUE = ind.date_obs
        ass_slit_widget_show_image
        ass_slit_widget_show_slit
        
        WIDGET_CONTROL, event.id, TIMER = 1d/global['framerate']
    end

    ;------ slit
    'ACTTIME' : begin
        ass_slit_widget_show_slit
    end

    'SLIT' : begin
        if global['straight'] eq !NULL then return
        if global['data_ind'] eq !NULL then return
        if event.type eq 0 then begin
            case event.press of
                1: begin
                    if global['speed_first_pt'] eq !NULL then begin
                        global['speed_first_pt'] = ass_slit_widget_slit_convert([event.x, event.y], mode = 'win2dat')
                    endif else begin
                        global['speed_list'].Add, {first:global['speed_first_pt'], second:ass_slit_widget_slit_convert([event.x, event.y], mode = 'win2dat')}
                        global['speed_first_pt'] = !NULL
                    endelse    
                    ass_slit_widget_show_slit
                end
                
                4: begin ; undo
                    if global['speed_first_pt'] eq !NULL && global['speed_list'].Count() gt 0 then begin
                        global['speed_first_pt'] = (global['speed_list'])[global['speed_list'].Count()-1].first
                        global['speed_list'].Remove
                    endif else begin
                        global['speed_first_pt'] = !NULL
                    endelse    
                    ass_slit_widget_show_slit
                end        
                
                else: begin
                end        
            endcase    
        endif    
    end
    
    'MODEMEAN' : begin
        global['slitmode'] = eventval
        ass_slit_widget_get_timedist
        ass_slit_widget_show_slit
    end     

    'MODEMED' : begin
        global['slitmode'] = eventval
        ass_slit_widget_get_timedist
        ass_slit_widget_show_slit 
    end     

    'MODEQ75' : begin
        global['slitmode'] = eventval
        ass_slit_widget_get_timedist
        ass_slit_widget_show_slit 
    end     

    'MODEQ95' : begin
        global['slitmode'] = eventval
        ass_slit_widget_get_timedist
        ass_slit_widget_show_slit 
    end     

    'SLITWIDTH' : begin
        asw_control, 'SLITWIDTH', GET_VALUE = pos
        global['slitwidth'] = pos
        ass_slit_widget_make_bounds
        ass_slit_widget_show_image
        ass_slit_widget_get_timedist
        ass_slit_widget_show_slit
    end
         
    'SLITCONTR' : begin
        asw_control, 'SLITCONTR', GET_VALUE = pos
        global['slitcontr'] = pos
        ass_slit_widget_get_timedist
        ass_slit_widget_show_slit
    end
         
    'SLITBRIGHT' : begin
        asw_control, 'SLITBRIGHT', GET_VALUE = pos
        global['slitbright'] = pos
        ass_slit_widget_get_timedist
        ass_slit_widget_show_slit
    end
         
    'EXPORT' : begin
        if global['straight'] eq !NULL then begin
            result = DIALOG_MESSAGE('Nothing to export!', title = 'SlitTreat Error', /ERROR)
            return
        endif    
        
        WIDGET_CONTROL, /HOURGLASS
        ass_slit_widget_export
    end

    'EXPFLUX' : begin
        if global['straight'] eq !NULL then begin
            result = DIALOG_MESSAGE('Nothing to export!', title = 'SlitTreat Error', /ERROR)
            return
        endif    
        
        WIDGET_CONTROL, /HOURGLASS
        ass_slit_widget_export_flux
    end

    'EXPSAV' : begin
        if global['straight'] eq !NULL then begin
            result = DIALOG_MESSAGE('Nothing to export!', title = 'SlitTreat Error', /ERROR)
            return
        endif    
        
        WIDGET_CONTROL, /HOURGLASS
        ass_slit_widget_export_sav
    end
    
endcase
end

;----------------------------------------------------------------------------------
pro ass_slit_widget_add_keys

common G_ASS_SLIT_WIDGET, global

if global['data_ind'] ne !NULL && ~global.hasKey('jd_list') then begin
    global['jd_list'] = asu_get_sequence_juldates(global['data_ind'])
endif

end

;----------------------------------------------------------------------------------
pro ass_slit_widget_cleanup

common G_ASS_SLIT_WIDGET, global
common G_ASS_SLIT_WIDGET_PREF, pref

global['data_list'] = !NULL
global['data_ind'] = !NULL 
global['data_jd'] = !NULL 
global['slit_list'] = !NULL
global['byte_list'] = !NULL
global['byte_info'] = !NULL
global['dat_range'] = lonarr(2, 2)
global['win_range'] = lonarr(2, 2)
global['xy_lb_dat'] = !NULL
global['xy_rt_dat'] = !NULL
global['currpos'] = 0
global['select'] = 0
global['animation'] = 0
global['appredit'] = 0
global['left_bound'] = !NULL
global['right_bound'] = !NULL
global['reper_pts'] = !NULL
global['pt_to_drag'] = -1
global['data_shift'] = !NULL
global['coef'] = 1

global['points'] = list()
global['fit_order'] = 'linear'
global['norm_poly'] = !NULL
global['approx'] = !NULL
global['markup'] = !NULL
global['grids'] = !NULL
global['straight'] = !NULL
global['speed_first_pt'] = !NULL
global['speed_list'] = list()

global['timedist'] = !NULL
global['timedistshow'] = !NULL

end


;----------------------------------------------------------------------------------
pro SlitTreat_widget

common G_ASS_SLIT_WIDGET, global
common G_ASS_SLIT_WIDGET_PREF, pref
common G_ASW_WIDGET, asw_widget

resolve_routine,'slittreat_widget_data',/compile_full_file, /either
resolve_routine,'slittreat_widget_slit',/compile_full_file, /either

asw_widget = hash()
global = hash()
pref = hash()
global['proj_name'] = ''
global['fromfile'] = ''
global['tofile'] = ''
global['workpath'] = ''
global['xmargimg'] = [8, 1]
global['ymargimg'] = [6d, 3d]*double(!d.x_ch_size)/double(!d.y_ch_size)
global['framerate'] = 5d

global['cadence'] = 12d
global['slitwidth'] = 1
global['slitmode'] = 'MODEMEAN'
global['slitcontr'] = 0
global['slitbright'] = 100

ass_slit_widget_cleanup

global['xmargin'] = [10, 1]
global['ymargin'] = [5, 1]

ass_slit_widget_add_keys

global['modified'] = 0

global['maxslitwidth'] = 100
winsize = [800, 800]
global['winsize'] = winsize
slitsize = [800, 350]
global['slitsize'] = slitsize

pref['path'] = ''
pref['proj_path'] = ''
pref['proj_file'] = ''
pref['export_path'] = ''
pref['expsav_path'] = ''
pref['pref_path'] = ''
dirpath = file_dirname((ROUTINE_INFO('SlitTreat_widget', /source)).path, /mark)
if n_elements(dirpath) gt 0 then begin
    pref['pref_path'] = dirpath + 'slittreat.pref'
    if file_test(pref['pref_path']) then begin
        restore, pref['pref_path'], /RELAXED_STRUCTURE_ASSIGNMENT
    endif    
endif    

base = WIDGET_BASE(TITLE = 'SlitTreat', UNAME = 'SLITTREAT', /column, /TLB_KILL_REQUEST_EVENTS)
asw_widget['widbase'] = base

;filecol = WIDGET_BASE(base, /column)
;    fromrow = WIDGET_BASE(filecol, /row)
;        dummy = WIDGET_LABEL(fromrow, VALUE = 'From: ', XSIZE = 40)
;        fromfiletext = WIDGET_TEXT(fromrow, UNAME = 'FROMFILETEXT', VALUE = '', XSIZE = 120, YSIZE = 1, /FRAME)
;        frombutton = WIDGET_BUTTON(fromrow, VALUE = '...', UVALUE = 'FILEFROM', SCR_XSIZE = 30)
;    torow = WIDGET_BASE(filecol, /row)
;        dummy = WIDGET_LABEL(torow, VALUE = 'To: ', XSIZE = 40)
;        tofiletext = WIDGET_TEXT(torow, UNAME = 'TOFILETEXT', VALUE = '', XSIZE = 120, YSIZE = 1, /FRAME)
;        frombutton = WIDGET_BUTTON(torow, VALUE = '...', UVALUE = 'FILETO', SCR_XSIZE = 30)

mainrow = WIDGET_BASE(base, /row)
    imagecol = WIDGET_BASE(mainrow, /column)
        fromrow = WIDGET_BASE(imagecol, /row)
            dummy = WIDGET_LABEL(fromrow, VALUE = 'From: ', XSIZE = 40)
            fromfiletext = WIDGET_TEXT(fromrow, UNAME = 'FROMFILETEXT', VALUE = '', XSIZE = 120, YSIZE = 1, /FRAME)
            frombutton = WIDGET_BUTTON(fromrow, VALUE = '...', UVALUE = 'FILEFROM', SCR_XSIZE = 30)
        torow = WIDGET_BASE(imagecol, /row)
            dummy = WIDGET_LABEL(torow, VALUE = 'To: ', XSIZE = 40)
            tofiletext = WIDGET_TEXT(torow, UNAME = 'TOFILETEXT', VALUE = '', XSIZE = 120, YSIZE = 1, /FRAME)
            frombutton = WIDGET_BUTTON(torow, VALUE = '...', UVALUE = 'FILETO', SCR_XSIZE = 30)
        showimage = WIDGET_DRAW(imagecol, GRAPHICS_LEVEL = 0, UNAME = 'IMAGE', UVALUE = 'IMAGE', XSIZE = winsize[0], YSIZE = winsize[1], /BUTTON_EVENTS)
        slider = WIDGET_SLIDER(imagecol, VALUE = 0, UNAME = 'SLIDER', UVALUE = 'SLIDER', XSIZE = winsize[0])
        framerow = WIDGET_BASE(imagecol, /row)
            dummy = WIDGET_LABEL(framerow, VALUE = 'Frame', XSIZE = 40)
            framedate = WIDGET_TEXT(framerow, UNAME = 'FRAMEDATE', VALUE = '', XSIZE = 30, YSIZE = 1, /FRAME)
            startbutton = WIDGET_BUTTON(framerow, VALUE = 'Start', UVALUE = 'START', XSIZE = 80)
            stopbutton = WIDGET_BUTTON(framerow, VALUE = 'Stop', UVALUE = 'STOP', XSIZE = 80)
            dummy = WIDGET_LABEL(framerow, VALUE = '    fps:', XSIZE = 30)
            rate = WIDGET_SLIDER(framerow, VALUE = round(global['framerate']), MINIMUM = 1, MAXIMUM = 20, UNAME = 'FRATE', UVALUE = 'FRATE', XSIZE = 90)
            
    ctrlcol = WIDGET_BASE(mainrow, /column, /align_left)
        dummy = WIDGET_LABEL(ctrlcol, VALUE = ' ', XSIZE = 40)
        dummy = WIDGET_LABEL(ctrlcol, VALUE = ' ', XSIZE = 40)
        dummy = WIDGET_LABEL(ctrlcol, VALUE = ' ', XSIZE = 40)
        dummy = WIDGET_LABEL(ctrlcol, VALUE = ' ', XSIZE = 40)
        procbutton = WIDGET_BUTTON(ctrlcol, VALUE = 'Proceed Files', UVALUE = 'PROCEED', XSIZE = 120)
        dummy = WIDGET_LABEL(ctrlcol, VALUE = ' ', XSIZE = 40)
        saveasbutton = WIDGET_BUTTON(ctrlcol, VALUE = 'Save As ...', UVALUE = 'SAVEAS', XSIZE = 120)
        savebutton = WIDGET_BUTTON(ctrlcol, VALUE = 'Save', UVALUE = 'SAVE', XSIZE = 120)
        loadbutton = WIDGET_BUTTON(ctrlcol, VALUE = 'Load ...', UVALUE = 'LOAD', XSIZE = 120)
        lastbutton = WIDGET_BUTTON(ctrlcol, VALUE = 'Last', UVALUE = 'LAST', XSIZE = 120)
        dummy = WIDGET_LABEL(ctrlcol, VALUE = ' ', XSIZE = 40)
        winfitrow = WIDGET_BASE(ctrlcol, /column, /Exclusive)
            size1 = WIDGET_BUTTON(winfitrow, VALUE = 'Fit to Window', UNAME = 'FITWIN', UVALUE = 'FITWIN', XSIZE = 120)
            size2 = WIDGET_BUTTON(winfitrow, VALUE = 'Actual Size', UNAME = 'ACTSIZE', UVALUE = 'ACTSIZE', XSIZE = 120)
            size3 = WIDGET_BUTTON(winfitrow, VALUE = 'Selection', UNAME = 'SELWIN', UVALUE = 'SELWIN', XSIZE = 120)
            WIDGET_CONTROL, size1, SET_BUTTON = 1
            global['drawmode'] = 'FITWIN'
        ;selinforow = WIDGET_BASE(ctrlcol, /column)
        dummy = WIDGET_LABEL(ctrlcol, VALUE = '    (Ctrl+LeftMouse+Drag)', XSIZE = 120)
        dummy = WIDGET_LABEL(ctrlcol, VALUE = ' ', XSIZE = 40)
        orderbutton = WIDGET_DROPLIST(ctrlcol, VALUE = ass_slit_widget_fit_orders(), UNAME = 'ORDER', UVALUE = 'ORDER', XSIZE = 120)
        fitbutton = WIDGET_BUTTON(ctrlcol, VALUE = 'Fit', UVALUE = 'FIT', XSIZE = 120)
        editapprrow = WIDGET_BASE(ctrlcol, /column, /Nonexclusive)
            editapprcheck = WIDGET_BUTTON(editapprrow, VALUE = 'Edit Approx. ...', UNAME = 'EDITAPPR', UVALUE = 'EDITAPPR', XSIZE = 120)
        hiderow = WIDGET_BASE(ctrlcol, /column, /Nonexclusive)
            hidecheck = WIDGET_BUTTON(hiderow, VALUE = 'Hide Markup', UNAME = 'HIDEAPPR', UVALUE = 'HIDEAPPR', XSIZE = 120)
        hideallrow = WIDGET_BASE(ctrlcol, /column, /Nonexclusive)
            hideallcheck = WIDGET_BUTTON(hideallrow, VALUE = 'Hide All', UNAME = 'HIDEALL', UVALUE = 'HIDEALL', XSIZE = 120)
        clearbutton = WIDGET_BUTTON(ctrlcol, VALUE = 'Clear Slit', UVALUE = 'CLEAR', XSIZE = 120)
        clearapprbutton = WIDGET_BUTTON(ctrlcol, VALUE = 'Clear Approx.', UVALUE = 'CLEARAPPR', XSIZE = 120)
        dummy = WIDGET_LABEL(ctrlcol, VALUE = ' ', XSIZE = 40)
        exportimage = WIDGET_BUTTON(ctrlcol, VALUE = 'Export Image ...', UVALUE = 'EXPIMAGE', XSIZE = 120)
        exportflux = WIDGET_BUTTON(ctrlcol, VALUE = 'Export Flux ...', UVALUE = 'EXPFLUX', XSIZE = 110)
        exportbutton = WIDGET_BUTTON(ctrlcol, VALUE = 'Export T-D ...', UVALUE = 'EXPORT', XSIZE = 110)
        dummy = WIDGET_LABEL(ctrlcol, VALUE = ' ', XSIZE = 40)
        expsavbutton = WIDGET_BUTTON(ctrlcol, VALUE = 'T-D to SAV...', UVALUE = 'EXPSAV', XSIZE = 110)
        
    slitcol = WIDGET_BASE(mainrow, /column, /base_align_left) ;xsize = slitsize[0])
        ;fluxhead = WIDGET_LABEL(slitcol, VALUE = 'Flux Dynamics', XSIZE = slitsize[0], UNAME = 'FLUXTEXT', UVALUE = 'FLUXTEXT', /align_center)
        fluximage = WIDGET_DRAW(slitcol, GRAPHICS_LEVEL = 0, UNAME = 'FLUX', UVALUE = 'FLUX', XSIZE = slitsize[0], YSIZE = slitsize[1], /BUTTON_EVENTS)
        tdcoords = WIDGET_LABEL(slitcol, VALUE = '', XSIZE = slitsize[0], UNAME = 'TDCOORDS', UVALUE = 'TDCOORDS', /align_center)
        slitimage = WIDGET_DRAW(slitcol, GRAPHICS_LEVEL = 0, UNAME = 'SLIT', UVALUE = 'SLIT', XSIZE = slitsize[0], YSIZE = slitsize[1], /BUTTON_EVENTS)
        markrow = WIDGET_BASE(slitcol, /row)
            tdfrom = WIDGET_LABEL(markrow, VALUE = '', XSIZE = 120, UNAME = 'TDFROM', UVALUE = 'TDFROM')
            tdlength = WIDGET_LABEL(markrow, VALUE = '', XSIZE = slitsize[0] - 240, /align_center, UNAME = 'TDLNG', UVALUE = 'TDLNG')
            tdto = WIDGET_LABEL(markrow, VALUE = '', XSIZE = 120, /align_right, UNAME = 'TDTO', UVALUE = 'TDTO')
        acttimerow = WIDGET_BASE(slitcol, /row, /align_right)
            acttimercol = WIDGET_BASE(acttimerow, /column, /Nonexclusive, /align_right)
                acttimecheck = WIDGET_BUTTON(acttimercol, VALUE = 'Absolute Time', UNAME = 'ACTTIME', UVALUE = 'ACTTIME', /align_right) ;, XSIZE = 120)
        moderow = WIDGET_BASE(slitcol, /row, /Exclusive)
            modemean = WIDGET_BUTTON(moderow, VALUE = 'Mean', UNAME = 'MODEMEAN', UVALUE = 'MODEMEAN', XSIZE = 80)
            modemed = WIDGET_BUTTON(moderow, VALUE = 'Median', UNAME = 'MODEMED', UVALUE = 'MODEMED', XSIZE = 80)
            modeq75 = WIDGET_BUTTON(moderow, VALUE = '75 %', UNAME = 'MODEQ75', UVALUE = 'MODEQ75', XSIZE = 80)
            modeq95 = WIDGET_BUTTON(moderow, VALUE = '95 %', UNAME = 'MODEQ95', UVALUE = 'MODEQ95', XSIZE = 80)
            WIDGET_CONTROL, modemean, SET_BUTTON = 1
        slitwidth = WIDGET_SLIDER(slitcol, VALUE = 0, UNAME = 'SLITWIDTH', UVALUE = 'SLITWIDTH', XSIZE = slitsize[0], title = 'Time-Distance Halfwidth')
        BCrow = WIDGET_BASE(slitcol, /row)
            slitcontr = WIDGET_SLIDER(BCrow, VALUE = 0, UNAME = 'SLITCONTR', UVALUE = 'SLITCONTR', XSIZE = slitsize[0]/2, title = 'Time-Distance Contrast')
            slitbright = WIDGET_SLIDER(BCrow, VALUE = 100, UNAME = 'SLITBRIGHT', UVALUE = 'SLITBRIGHT', XSIZE = slitsize[0]/2, title = 'Time-Distance Upper Threshold')

WIDGET_CONTROL, base, /REALIZE
XMANAGER, 'ass_slit_widget_buttons', base, GROUP_LEADER = GROUP, /NO_BLOCK

WIDGET_CONTROL, slitwidth, SET_SLIDER_MIN = 1
WIDGET_CONTROL, slitwidth, SET_SLIDER_MAX = global['maxslitwidth']
WIDGET_CONTROL, slitcontr, SET_SLIDER_MIN = -100
WIDGET_CONTROL, slitcontr, SET_SLIDER_MAX = 100
WIDGET_CONTROL, slitbright, SET_SLIDER_MIN = 0
WIDGET_CONTROL, slitbright, SET_SLIDER_MAX = 100
WIDGET_CONTROL, slitbright, SET_VALUE = global['slitbright']

;ass_slit_widget_set_win, 'IMAGE', 'winsize'
;ass_slit_widget_set_win, 'SLIT', 'slitsize'

end