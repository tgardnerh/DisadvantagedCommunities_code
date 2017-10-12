**The purpose of this code is to compare the experian data (inclusive of the used
**car backfill) to the DMV data.  

//set maximum number of duplicates to be indiscriminately dropped
local duplicates_max 113
use "$WorkingDirs/Tyler/Experian", clear
gen XFER_YEAR = yofd(PurchaseDate )
tostring XFER_YEAR, replace



keep if backfill == 1

bysort VIN XFER_YEAR (OdometerReading):  keep if _n == 1	


tempfile EXP 
save `EXP'


import delimited using "$scratch/backfill_2016_DMVout_20171005.csv", clear case(preserve) varnames(1)
gen dta_yr = 2016



generate XFER_YEAR = substr(datLAST_XFER_DATE , 1, 4)
replace XFER_YEAR = "" if XFER_YEAR == "NA"

keep VIN XFER_YEAR ODO *PRICE dta_yr LAST_OWNERSHIP_DATE
duplicates drop


duplicates tag VIN ODO XFER_YEAR dta_yr, gen(flag)
count if flag
assert r(N) < `duplicates_max'
drop if flag
drop flag


merge m:1 VIN XFER_YEAR using `EXP', gen(merge2)

gen last_own_date = date("20"+string(LAST_OWNERSHIP_DATE ) , "YMD")
format last_own_date %td

save "$scratch/Merged_EXP_DMV", replace
codebook last_own_date
codebook PurchaseDate

//Count cases where DMV ownership date is before Experian purchase date
count if last_own_date < PurchaseDate & !missing(PurchaseDate) 

reg PurchasePrice LOW_PURCH_PRICE HI_PURCH_PRICE 
reg OdometerReading ODO