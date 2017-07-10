capture log close
***************************************
** CES20_disadvantaged_threshold_power_calcs.do
**
** Do some RD power calcs using the CES2.0 zip code score
** As the threshold
**
**
**	REVISION HISTORY - 
**		20170522 - File created
***************************************
clear
version 14.2
set more off

log using "${DisComm}/Log/power_calc_graphs.txt", text replace

foreach d in AllData SanJoaquinValley SCAQMD {

	use "${DisComm}/Data/CES20_PowerCalcs_`d'.dta"
	
	**Make a graph of power as a function of signal
	#delim ;
		twoway 
			(line Power EffectSize, lcolor(black) lwidth(medthick))
			,
			graphregion(color(white))
			xtitle("Signal-to-Noise" "(Effect)/(Resid. Variance)", size(small))
			xlab(0(0.2)1, labsize(small))
			xmtick(0(0.1)1)
			ytitle("Power", size(small))
			ylab(0(0.2)1,labsize(small))
			ymtick(0(0.1)1)
			legend(off)
		;
	#delim cr
	graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/PowerCalcs/CES20Disadvantaged/Power_CES20_RD_`d'.pdf", replace
}

***************************
** Combine all power datasets
***************************
use "${DisComm}/Data/CES20_PowerCalcs_AllData.dta", clear
rename Power Power_AllData

foreach d in SanJoaquinValley SCAQMD {

	merge 1:1 EffectSize using "${DisComm}/Data/CES20_PowerCalcs_`d'.dta", assert(match) nogen
	rename Power Power_`d'
}

*************************
** Combined graph
*************************
#delim ;
	twoway 
		(line Power_AllData Power_SanJoaquinValley Power_SCAQMD EffectSize, 
			lcolor(black orange blue) 
			lwidth(medthick medthick medthick)
		)
		,
		graphregion(color(white))
		xtitle("Signal-to-Noise" "(Effect)/(Resid. Variance)", size(small))
		xlab(0(0.2)1, labsize(small))
		xmtick(0(0.1)1)
		ytitle("Power", size(small))
		ylab(0(0.2)1,labsize(small))
		ymtick(0(0.1)1)
		legend(
			rows(1)
			size(small)
			label(1 "All Data")
			label(2 "San Joaquin Valley Only")
			label(3 "SCAQMD Only")			
		)
	;
#delim cr
graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/PowerCalcs/CES20Disadvantaged/Power_CES20_RD_Combined.pdf", replace


log close

