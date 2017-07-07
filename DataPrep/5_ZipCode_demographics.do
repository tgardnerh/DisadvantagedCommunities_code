capture log close
***************************************
** 4_CensusTract_demographics.do
**
** Load demographic data by census tract from various sources
**
** REVISION HISTORY:
**	20170522 - Zero left padded census tract FIPS
***************************************
clear all
version 14.2
set more off

global Dropbox "I:\Personal Files\Jim\Dropbox"
*global Dropbox "c:\Users\Jim\Dropbox"
global DisComm "${Dropbox}/Erich_Dave_Projects/Project_DisadvantagedCommunities"
global DisStatus "$Dropbox/Erich_Dave_Projects/Data/Disdvantaged Community designation in CA (related to EFMP)"
global MapFiles "${Dropbox}/Erich_Dave_Projects/Data/mapfiles"

log using "${DisComm}/Log/ZipCode_demographics", text replace

import delim CensusTract ZipCode AreaOverlap ///
	using "${MapFiles}/overlapMatrix/CA_Census_Tracts_to_ZIP_codes_2010.txt", ///
	delim(tab) stringcols(1) clear

drop if missing(ZipCode)
bysort CensusTract (AreaOverlap) : keep if _n == _N
drop AreaOverlap

sort CensusTract

tempfile CTToZip
save `CTToZip'

import excel using "${DisStatus}/CalEnviroScreen2_Scores_Full_Oct_2014.xlsx", ///
	sheet(CES2.0FinalResults) firstrow allstring clear case(preserve)
	
	
keep CensusTract CES20Score TotalPopulation Age Education Poverty Unemployment 
replace CES20Score = "" if CES20Score == "NA"
destring CES20Score, replace

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

merge m:1 CensusTract using `CTToZip', keep(master match) assert(match) nogen

#delim ;
	collapse
		(rawsum)
			TotalPopulation
		(mean)
			Age
			Education
			Poverty
			Unemployment
			RoE*
		(max)
			ZipMaxCES20Score = CES20Score
		[aw=TotalPopulation]
		,
		by(ZipCode)
	;
#delim cr

sort ZipCode
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

save "${DisComm}/Data/demographics_by_ZipCode.dta", replace


log close




