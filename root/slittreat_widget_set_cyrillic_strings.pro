pro SlitTreat_widget_set_cyrillic_strings
compile_opt idl2

; !!!!!!!!!! *********** DO NOT EDIT IN IDL IDE *********** !!!!!!!!!!

common G_ASS_SLIT_WIDGET_CYRILLIC_STRINGS, slit_treat_cyr_str

slit_treat_cyr_str = hash()
; 1252 codepage
slit_treat_cyr_str['arcsec'] = ' ���. �.'
slit_treat_cyr_str['dist_Mm'] = ' ����������, ��'
slit_treat_cyr_str['time_min'] = ' �����, ���'
slit_treat_cyr_str['time_HHMM'] = ' �����, ��:��'
slit_treat_cyr_str['speed_kms'] = ' ��/�'
slit_treat_cyr_str['flux_rel'] = ' ���. �����, -'

end
