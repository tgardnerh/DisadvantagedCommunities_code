clear 
version 15

log using "$Experian/Log/zip_readin.txt", text replace

import delimited using "$WorkingDirs/Tyler/zcta_cd111_rel_10.txt", stringcols(1) 


save  "$WorkingDirs/Tyler/zip_xwalk", replace
log close
