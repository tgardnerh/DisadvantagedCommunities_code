clear 
version 15

log using "$Experian/Log/CBP_readin.txt", text replace

import delimited using "${Dropbox}/Erich_Dave_Projects/Data/census/CountyBusinessPatterns/Data/zbp15detail.txt", stringcols(1) varnames(1)

rename (zip est ) (zipcode CBP_establisment_count)


save  "$WorkingDirs/Tyler/CBP", replace
log close
