capture log close
***************************************
** 4_CensusTract_demographics.do
**
** Load demographic data by census tract from various sources
**
** REVISION HISTORY:
**	20170522 - Zero left padded census tract FIPS
***************************************
clear
version 14.2
set more off


log using "${DisComm}/Log/CensusTract_demographics", text replace

import excel using "${DisStatus}/CalEnviroScreen2_Scores_Full_Oct_2014.xlsx", ///
	sheet(CES2.0FinalResults) firstrow allstring clear case(preserve)
	
	
keep CensusTract TotalPopulation Age Education Poverty Unemployment 

tempfile demogs
save `demogs'

**Import race demographics. There are two header rows, so 
**I rename manually
import excel using "${DisStatus}/CalEnviroScreen2_Scores_Full_Oct_2014.xlsx", ///
	sheet("Demographic Profile") allstring clear cellrange(A3)
	
keep A F G H I J K
rename (A F G H I J K) (CensusTract RoE_Hispanic RoE_White RoE_AfricanAmerican RoE_NativeAmerican RoE_AsianAmerican RoE_Other)

merge 1:1 CensusTract using `demogs', nogen assert(match)
	
foreach f of varlist TotalPopulation Age Education Poverty Unemployment RoE* {
	replace `f' = "." if `f' == "NA"
	destring `f', replace
	confirm numeric var `f'
}

**Left zero pad census tract
replace CensusTract = substr("0"*11,1,11-length(CensusTract)) + CensusTract

sort CensusTract
compress


label var TotalPopulation "Census Tract population, 2010 Census"
label var Age "Census tract portion of population under 10 or over 65, 2010 Census"
label var Education "Census tract portion of population over 25 less than high school"
label var Poverty "Census tract portion of population below federal poverty level"
label var Unemployment "Census tracr portion of population unemployed"
label var RoE_Hispanic "Census tract portion of population Hispanic"
label var RoE_White "Census tract portion of population white"
label var RoE_AfricanAmerican  "Census tract portion of population African American"
label var RoE_NativeAmerican  "Census tract portion of population Native American"
label var RoE_AsianAmerican  "Census tract portion of population Asian American"
label var RoE_Other "Census tract portion of population Other race"

save "${DisComm}/Data/demographics_by_CensusTract.dta", replace


log close




