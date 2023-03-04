pro SlitTreat_widget_set_cyrillic_strings
compile_opt idl2

; !!!!!!!!!! *********** DO NOT EDIT IN IDL IDE *********** !!!!!!!!!!

common G_ASS_SLIT_WIDGET_CYRILLIC_STRINGS, slit_treat_cyr_str

slit_treat_cyr_str = hash()
; 1252 codepage
slit_treat_cyr_str['arcsec'] = ' Угл. с.'
slit_treat_cyr_str['dist_Mm'] = ' Расстояние, Мм'
slit_treat_cyr_str['time_min'] = ' Время, мин'
slit_treat_cyr_str['time_HHMM'] = ' Время, ЧЧ:ММ'
slit_treat_cyr_str['speed_kms'] = ' км/с'
slit_treat_cyr_str['flux_rel'] = ' Отн. поток, -'

end
