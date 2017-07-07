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

log using "${DisComm}/Log/cvrp_CES20_discontinuity_stats.txt", text replace

use "${DisComm}/Data/RebatesWithDisadvantagedStatus_${ResultsVersion}.dta"

**Define the discontinuity
local CES20Threshold 36.6

**Define a bin size for collapsing graphs
local BinSize 1
local NBins 50


/*gen RoundCES20 = round(CES20Score,`BinSize')
gen byte OnRoundedThreshold = RoundCES20 == round(`CES20Threshold',`BinSize') 

*Jitter rounding on observations whos bin size rounds to the threshold
replace RoundCES20 = RoundCES20 - `BinSize'/2 if OnRoundedThreshold == 1 & CES20Score < `CES20Threshold'
replace RoundCES20 = RoundCES20 + `BinSize'/2 if OnRoundedThreshold == 1 & CES20Score > `CES20Threshold'
*/
xtile LowBin = CES20Score if CES20Score < `CES20Threshold', nq(`NBins')
xtile HighBin = CES20Score if CES20Score > `CES20Threshold', nq(`NBins')
gen bin = cond(LowBin < . , -1*LowBin, HighBin)
egen RoundCES20 = mean(CES20Score), by(bin)


preserve
	gen RebateDollarsPre = RebateDollars if PostRebateDifferentiation == 0
	gen RebateDollarsPost = RebateDollars if PostRebateDifferentiation == 1
	#delim ;
		collapse
			(mean) 
				CensusTractDisadvantaged
				RebateDollarsPre
				RebateDollarsPost
			(count) 
				ObsCount = CensusTractDisadvantaged
			,
			by(RoundCES20)
		;
	#delim cr
	
	**First create a graph showing how disadvantaged status varies across the threshold
	#delim ;
		twoway 
			(scatter CensusTractDisadvantaged RoundCES20, mcolor(black) msymbol(T))
			,
			graphregion(color(white))
			xtitle("CES 2.0 Score",size(small))
			ytitle("Disadvantaged Status", size(small))
			legend(off)
			xline(`CES20Threshold', lcolor(red) lpattern(dash))
		;
	#delim cr
	graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/CES20_Discontinuity/DisadvantagedStatus_v_CES20.pdf", replace

restore

*****************************************
** Make some graphs of rebate dollar amounts across the discontinuity
*****************************************
preserve
	gen RebateDollarsPre = RebateDollars if PostRebateDifferentiation == 0
	gen RebateDollarsPost = RebateDollars if PostRebateDifferentiation == 1
	#delim ;
		collapse
			(mean) 
				RebateDollarsPre
				RebateDollarsPost
			,
			by(RoundCES20 VehicleCategory)
		;
	#delim cr
	
	foreach vc in BEV PHEV {
	
		#delim ;
			twoway 
				(scatter RebateDollarsPre RoundCES20, mcolor(black) msymbol(T))
				if VehicleCategory == "`vc'":VehicleCategory
				,
				graphregion(color(white))
				xtitle("CES 2.0 Score",size(small))
				ytitle("Mean Rebate ($)" "Pre Period", size(small))
				legend(off)
				xline(`CES20Threshold', lcolor(red) lpattern(dash))
			;
		#delim cr
		
		graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/CES20_Discontinuity/RebateDollars_v_CES20_PrePeriod_`vc'.pdf", replace
		
		#delim ;
			twoway 
				(scatter RebateDollarsPost RoundCES20, mcolor(blue) msymbol(S))
				if VehicleCategory == "`vc'":VehicleCategory				
				,
				graphregion(color(white))
				xtitle("CES 2.0 Score",size(small))
				ytitle("Mean Rebate ($)" "Post Period", size(small))
				legend(off)
				xline(`CES20Threshold', lcolor(red) lpattern(dash))
			;
		#delim cr
		graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/CES20_Discontinuity/RebateDollars_v_CES20_PostPeriod_`vc'.pdf", replace
		
		#delim ;
			twoway 
				(scatter RebateDollarsPre RoundCES20, mcolor(black) msymbol(T))
				(scatter RebateDollarsPost RoundCES20, mcolor(blue) msymbol(S))
				if VehicleCategory == "`vc'":VehicleCategory				
				,
				graphregion(color(white))
				xtitle("CES 2.0 Score",size(small))
				ytitle("Mean Rebate ($)", size(small))
				legend(
					rows(1)
					size(small)
					label(1 "Pre Period")
					label(2 "Post Period")
				)
				xline(`CES20Threshold', lcolor(red) lpattern(dash))
			;
		#delim cr
		graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/CES20_Discontinuity/RebateDollars_v_CES20_BothPeriod_`vc'.pdf", replace
		
	}
restore


**********************************************
** Make some graphs of demographics around the discontinuity
*********************************************
use "${DisComm}/Data/CensusTractsAdjacentDisadvantagedStatus.dta", clear
merge 1:1 CensusTract using "${DisComm}/Data/demographics_by_CensusTract.dta", ///
	assert(master match) keep(match) nogen
	
/*gen RoundCES20 = round(CES20Score,`BinSize')
gen byte OnRoundedThreshold = RoundCES20 == round(`CES20Threshold',`BinSize') 

*Jitter rounding on observations whos bin size rounds to the threshold
replace RoundCES20 = RoundCES20 - `BinSize'/2 if OnRoundedThreshold == 1 & CES20Score < `CES20Threshold'
replace RoundCES20 = RoundCES20 + `BinSize'/2 if OnRoundedThreshold == 1 & CES20Score > `CES20Threshold'
*/
xtile LowBin = CES20Score if CES20Score < `CES20Threshold', nq(`NBins')
xtile HighBin = CES20Score if CES20Score > `CES20Threshold', nq(`NBins')
gen bin = cond(LowBin < . , -1*LowBin, HighBin)
egen RoundCES20 = mean(CES20Score), by(bin)

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
			xtitle("CES 2.0 Score",size(small))
			ytitle(, size(small))
			legend(off)
			xline(`CES20Threshold', lcolor(red) lpattern(dash))
		;
	#delim cr
	graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/CES20_Discontinuity/Demog_`v'_v_CES20.pdf", replace
}



		
			

log close

	
