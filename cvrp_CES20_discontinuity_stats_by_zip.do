capture log close
***************************************
** cvrp_CES20_discontinuity_stats.do
**
** Create some summary stats of rebates across the CES20 percentile discontinuity
**
***************************************
clear all
version 14.2
set more off

global Dropbox "I:\Personal Files\Jim\Dropbox"
*global Dropbox "C:\Users\Jim\Dropbox"
global DisComm "${Dropbox}/Erich_Dave_Projects/Project_DisadvantagedCommunities"

do "${DisComm}/Code/Code_Globals.do"

log using "${DisComm}/Log/cvrp_CES20_discontinuity_stats_by_zip.txt", text replace

local CES20Threshold 36.6

**Define a bin size for collapsing graphs
local BinSize 1
local NBins 50


**********************************************
** Make some graphs of demographics around the discontinuity
*********************************************
use "${DisComm}/Data/demographics_by_ZipCode.dta", clear

xtile LowBin = ZipMaxCES20Score if ZipMaxCES20Score < `CES20Threshold', nq(`NBins')
xtile HighBin = ZipMaxCES20Score if ZipMaxCES20Score > `CES20Threshold', nq(`NBins')
gen bin = cond(LowBin < . , -1*LowBin, HighBin)
egen RoundCES20 = mean(ZipMaxCES20Score), by(bin)

local demogs TotalPopulation Age Education Poverty Unemployment RoE*
#delim ;
	collapse
		(mean) `demogs'
		,
		by(RoundCES20)
	;
#delim cr

label var TotalPopulation "Population"
label var Age "Age under 10 or over 65 (%)"
label var Education "Over 25 less than high school (%)"
label var Poverty "Below poverty level (%)"
label var Unemployment "Unemployed (%)"
label var RoE_Hispanic "Portion Hispanic (%)"
label var RoE_White "Portion white (%)"
label var RoE_AfricanAmerican  "Portion African American (%)"
label var RoE_NativeAmerican  "Portion Native American (%)"
label var RoE_AsianAmerican  "Portion Asian American (%)"
label var RoE_Other "Portion other race (%)"

drop if RoundCES20 >= .
foreach v of varlist `demogs' {
	qui sum `v'
	local YMin = r(min)
	local YMax = r(max)
	#delim ;
		twoway 
			(scatter `v' RoundCES20, mcolor(blue) msymbol(S))			
			,
			graphregion(color(white))
			xtitle("Zip Code Max CES 2.0 Score",size(small))
			ytitle(, size(small))
			legend(off)
			xline(`CES20Threshold', lcolor(red) lpattern(dash))
		;
	#delim cr
	graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/CES20_Discontinuity/Demog_`v'_v_CES20_by_zip.pdf", replace
}



		
			

log close

	
