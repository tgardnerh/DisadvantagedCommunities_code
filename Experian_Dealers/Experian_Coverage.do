<<dd_do:quietly >>


//Prep Experian

use "$WorkingDirs/Tyler/Experian", clear
drop if DealerZipCode == ""
drop if strpos(DealerName , "UNKNOWN")
drop if strpos(DealerName , "NAME NOT IDENTIFIED")
drop if DealerType == "UD"
keep DealerZipCode DealerName
duplicates drop

gen flag = 1 
collapse  (count) ExperienCount = flag , by(DealerZipCode )

tempfile processedExperian
save `processedExperian'

use "$WorkingDirs/Tyler/CBP", clear

rename zipcode zcta5
keep if strpos(naics ,"441110")

joinby zcta5 using "$WorkingDirs/Tyler/zip_xwalk", unmatched(using)
//restrict to only 50 states+DC
keep if state <= 51

rename   zcta5 DealerZipCode
keep DealerZipCode CBP_establisment_count state
collapse (first) CBP state , by(Dealer)
duplicates drop

tempfile processedCBP
save `processedCBP'

merge 1:m DealerZipCode using `processedExperian'


replace CBP_establisment_count = 0 if missing(CBP_establisment_count )
replace ExperienCount = 0 if missing(ExperienCount )

destring DealerZipCode , replace
regress CBP E
local C_E_Beta_zeros _b[CBP_establisment_count]
local C_E_cons_zeros _b[_cons]

regress E CBP
local E_C_Beta_zeros _b[CBP_establisment_count]
local E_C_cons_zeros _b[_cons]

regress CBP E if CBP_establisment_count + ExperienCount != 0
local C_E_Beta _b[ExperienCount]
local C_E_cons _b[_cons]

regress E CBP if CBP_establisment_count + ExperienCount != 0
local E_C_Beta _b[ExperienCount]
local E_C_cons _b[_cons]

tempfile regression_file
save `regression_file'

preserve
collapse (count) DealerZipCode, by(CBP_establisment_count ExperienCount)
gen Experian_Weight = DealerZipCode * ExperienCount
gen CBP_Weight = DealerZipCode * CBP_establisment_count

scatter ExperienCount CBP_establisment_count [weight = DealerZipCode],  ///
xtitle("CBP Establishment Count") ytitle("Experian Establishment Count") ///
title("Establishment Counts") msymbol(oh) ///
note("circle size indicates number of zip codes")

graph export  "$WorkingDirs/Tyler/EstCounts.png", replace

scatter ExperienCount CBP_establisment_count [weight = DealerZipCode] ///
if CBP_establisment_count + ExperienCount != 0,  ///
xtitle("CBP Establishment Count") ytitle("Experian Establishment Count") ///
title("Establishment Counts") msymbol(oh) ///
note("circle size indicates number of zip codes")
graph save 
graph export  "$WorkingDirs/Tyler/EstCounts_NoZero.png", replace

restore
preserve

collapse CBP_establisment_count (count) NumberofZips = CBP_establisment_count, by(ExperienCount)
list
restore
preserve
collapse ExperienCount (count) NumberofZips = ExperienCount, by(CBP_establisment_count)
list

restore

*/
<</dd_do>>

#Establishment coverage




