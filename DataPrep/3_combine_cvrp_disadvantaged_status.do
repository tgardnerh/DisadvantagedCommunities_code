capture log close
***************************************
** combine_cvrp_disadvantaged_status.do
**
** Load CVRP data and add flags for whether the census tract
** containing the rebate is disadvantaged or adjacent to a disadvantaged 
** commuinity
**
***************************************
clear all
version 14.2
set more off

global Dropbox "I:\Personal Files\Jim\Dropbox"
*global Dropbox "c:\Users\Jim\Dropbox"
global DisComm "${Dropbox}/Erich_Dave_Projects/Project_DisadvantagedCommunities"
global CVRPData "${Dropbox}/Erich_Dave_Projects/Data/CVRP Incentives"
global CVRPDate 20170418
do "${DisComm}/Code/Code_Globals.do"

log using "${DisComm}/Log/combine_cvrp_disadvantaged_status", text replace

use "${CVRPData}/Data/Out/CVRP_list_${CVRPDate}.dta"

**Left zero pad census tract
replace CensusTract = substr("0"*11,1,11-length(CensusTract)) + CensusTract
**There is an orphan census tract in los angeles that represents 38 rebates.
**Drop it
count if CensusTract == "06037137000"
drop if CensusTract == "06037137000"

merge m:1 CensusTract using "${DisComm}/Data/CensusTractsAdjacentDisadvantagedStatus.dta", ///
	keep(master match) assert(match using) nogen


**Create a variable specifying tracts and zips on the border discontinuity
foreach g in CensusTract Zip {
	gen Discontinuity`g' = 0
	replace Discontinuity`g' = 1 if `g'Disadvantaged == 1 & Adjacent`g'Not == 1
	replace Discontinuity`g' = 1 if `g'Disadvantaged == 0 & Adjacent`g'Disadvantaged == 1
	tab Discontinuity`g'
	label var Discontinuity`g' "True if `g' adjoins a unit with different disadvantaged status"
}

**********************************
** Make some graphs that show how rebates differ by disadvantaged status
** over time. By looking at the graphs, I've determined that they started diverging
** on March 28, 2016 (a monday).
***********************************	
preserve
	**Round Application date
	scalar DaysPerBlock = 35
	gen int RoundApplicationDate = floor((ApplicationDate - mdy(3,28,2016))/DaysPerBlock)*DaysPerBlock + mdy(3,28,2016)
	rename (RoundApplicationDate ApplicationDate) (ApplicationDate ApplicationDateOrig)
	format %td ApplicationDate

	drop if missing(CensusTractDisadvantaged)
	
	collapse (mean) RebateDollars, by(ApplicationDate CensusTractDisadvantaged VehicleCategory)
	egen G = group(CensusTractDisadvantaged VehicleCategory)
	xtset G ApplicationDate, delta(`=DaysPerBlock' days)
	
	#delim ;
		twoway
			(line RebateDollars ApplicationDate if CensusTractDisadvantaged == 1, lcolor(blue) lwidth(thin) )
			(line RebateDollars ApplicationDate if CensusTractDisadvantaged == 0, lcolor(orange) lwidth(thin) )
			if inrange(ApplicationDate, mdy(1,1,2015), mdy(12,31,2016)) &
			VehicleCategory == "BEV":VehicleCategory
			,
			legend(
				size(small)
				rows(1)
				order(- "Disadvantaged Status:" 1 2)
				label(1 "Yes")
				label(2 "No")
			)
			xline(`=mdy(3,28,2016)' , lcolor(black) lpattern(dash))
			text(2000 `=mdy(3,28,2016)' "2016-03-28", size(small) placement(e))
			graphregion(color(white))
			xtitle("Application Date", size(small))
			ytitle("Week Mean Rebate ($)", size(small))
			ylab(,labsize(small))
			xlab(,labsize(small))
		;
	#delim cr
	graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/RebateValueByWeek/RebateValueByWeekAndDisadvantaged_BEVs.pdf", replace
	
	#delim ;
		twoway
			(line RebateDollars ApplicationDate if CensusTractDisadvantaged == 1, lcolor(blue) lwidth(thin) )
			(line RebateDollars ApplicationDate if CensusTractDisadvantaged == 0, lcolor(orange) lwidth(thin) )
			if inrange(ApplicationDate, mdy(1,1,2015), mdy(12,31,2016)) &
			VehicleCategory == "PHEV":VehicleCategory
			,
			legend(
				size(small)
				rows(1)
				order(- "Disadvantaged Status:" 1 2)
				label(1 "Yes")
				label(2 "No")
			)
			xline(`=mdy(3,28,2016)' , lcolor(black) lpattern(dash))
			text(1400 `=mdy(3,28,2016)' "2016-03-28", size(small) placement(e))
			graphregion(color(white))
			xtitle("Application Date", size(small))
			ytitle("Week Mean Rebate ($)", size(small))
			ylab(,labsize(small))
			xlab(,labsize(small))
		;
	#delim cr
	graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/RebateValueByWeek/RebateValueByWeekAndDisadvantaged_PHEVs.pdf", replace
	
	
	#delim ;
		twoway
			(line D.RebateDollars ApplicationDate if CensusTractDisadvantaged == 1, lcolor(blue) lwidth(thin) )
			(line D.RebateDollars ApplicationDate if CensusTractDisadvantaged == 0, lcolor(orange) lwidth(thin) )
			if inrange(ApplicationDate, mdy(1,1,2015), mdy(12,31,2016)) &
			VehicleCategory == "BEV":VehicleCategory
			,
			legend(
				size(small)
				rows(1)
				order(- "Disadvantaged Status:" 1 2)
				label(1 "Yes")
				label(2 "No")
			)
			xline(`=mdy(3,28,2016)' , lcolor(black) lpattern(dash))
			text(2000 `=mdy(3,28,2016)' "2016-03-28", size(small) placement(e))
			graphregion(color(white))
			xtitle("Application Date", size(small))
			ytitle("First Difference Week Mean Rebate ($)", size(small))
			ylab(,labsize(small))
			xlab(,labsize(small))
		;
	#delim cr
	graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/RebateValueByWeek/RebateValueByWeekAndDisadvantaged_BEVs_FirstDiffs.pdf", replace
	
	#delim ;
		twoway
			(line D.RebateDollars ApplicationDate if CensusTractDisadvantaged == 1, lcolor(blue) lwidth(thin) )
			(line D.RebateDollars ApplicationDate if CensusTractDisadvantaged == 0, lcolor(orange) lwidth(thin) )
			if inrange(ApplicationDate, mdy(1,1,2015), mdy(12,31,2016)) &
			VehicleCategory == "PHEV":VehicleCategory
			,
			legend(
				size(small)
				rows(1)
				order(- "Disadvantaged Status:" 1 2)
				label(1 "Yes")
				label(2 "No")
			)
			xline(`=mdy(3,28,2016)' , lcolor(black) lpattern(dash))
			text(1400 `=mdy(3,28,2016)' "2016-03-28", size(small) placement(e))
			graphregion(color(white))
			xtitle("Application Date", size(small))
			ytitle("First Difference Week Mean Rebate ($)", size(small))
			ylab(,labsize(small))
			xlab(,labsize(small))
		;
	#delim cr
	graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/RebateValueByWeek/RebateValueByWeekAndDisadvantaged_PHEVs_FirstDiffs.pdf", replace
	
restore

**Generate a Pre/Post rebate differentiation period flag
gen byte PostRebateDifferentiation = ApplicationDate >= mdy(3,28,2016)





save "${DisComm}/Data/RebatesWithDisadvantagedStatus_${ResultsVersion}.dta", replace


log close

