capture log close
***************************************
** cvrp_summary_stats.do
**
** Create some summary stats of rebates across the discontinuity
**
***************************************
clear all
version 14.2
set more off

global Dropbox "I:\Personal Files\Jim\Dropbox"
*global Dropbox "C:\Users\Jim\Dropbox"
global DisComm "${Dropbox}/Erich_Dave_Projects/Project_DisadvantagedCommunities"

do "${DisComm}/Code/Code_Globals.do"

log using "${DisComm}/Log/cvrp_summary_stats.txt", text replace

use "${DisComm}/Data/RebatesWithDisadvantagedStatus_${ResultsVersion}.dta"

**Round Application date
scalar DaysPerBlock = 35
gen int RoundApplicationDate = floor((ApplicationDate - mdy(3,28,2016))/DaysPerBlock)*DaysPerBlock + mdy(3,28,2016)
rename (RoundApplicationDate ApplicationDate) (ApplicationDate ApplicationDateOrig)

format ApplicationDate %td 

gen byte moy = month(ApplicationDateOrig)
gen int year = year(ApplicationDateOrig)
gen byte dow = dow(ApplicationDateOrig)

***********************************
** Make graphs of mean rebate values over time
***********************************
/* preserve
	replace ApplicationDate = dofw(wofd(ApplicationDate))
	collapse (mean) RebateDollars, by(ApplicationDate VehicleCategory)
	qui levelsof VehicleCategory, local(VCList)
	foreach vc of local VCList {
		local VCName : label VehicleCategory `vc'
		#delim ;
			twoway 
				(line RebateDollars ApplicationDate, lcolor(black) lwidth(medthick) )
				if VehicleCategory==`vc'
				,
				graphregion(color(white))
				xtitle("Date", size(small))
				xlab(, format(%tdMon-YY) labsize(small))
				ytitle("Mean Rebate Value ($)", size(small))
				ylab(,labsize(small))
				xline(`=mdy(3,28,2016)', lcolor(black) lpattern(dash))
				legend(off)
			;
		#delim cr
		graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/RebateValueByWeek/RebateValueByWeek_`VCName'.pdf", replace
	}
restore */

***********************************************
** Make graphs of the number of rebates over time
***********************************************
preserve
	keep if DiscontinuityZip == 1
	#delim ;
		collapse 
			(count) RebateCount = RebateDollars 
			(mean) RebateDollars
			(firstnm) ZipDisadvantaged dow moy year
			,
			by(ApplicationDateOrig VehicleCategory ZIP)
		;
	#delim cr
	
	egen CT = group(ZIP)
	xtset CT
	
	gen byte PostReform = ApplicationDateOrig >= mdy(3,28,2016)
	qui levelsof VehicleCategory, local(VCList)
	local EstList
	outreg , clear
	
	foreach vc of local VCList {
	local VCName : label VehicleCategory `vc'	
		**Run regression
		xtreg RebateCount i.dow i.moy i.year 1.PostReform i.ZipDisadvantaged#1.PostReform ///
			if VehicleCategory == `vc', fe vce(cluster ZIP)
		
		local EstName RebateCount`VCName'
		estimates store `EstName'
		local EstList : list EstList | EstName
		#delim ;
			outreg , 
				se
				keep(1.PostReform 1.ZipDisadvantaged#1.PostReform)
				ctitles("", "`VCName'")
				rtitles(
					"Post Reform" \ "" \ 
					"Zip Disadvantaged $\times$ Post Reform" \ ""
				)
				merge
			;
		#delim cr
				
	}
	estimates table `EstList', ///
		keep(1.PostReform 1.ZipDisadvantaged#1.PostReform) ///
		b se 
		
	outreg using "${DisComm}/ResultsOut/${ResultsVersion}/Tables/PolicyChangeEffects/EffectOnRebateCounts.tex", ///
		tex fragment replace replay

	local EstList
	outreg , clear
	
	foreach vc of local VCList {
	local VCName : label VehicleCategory `vc'	
		**Run regression
		xtpoisson RebateCount i.dow i.moy i.year 1.PostReform i.ZipDisadvantaged#1.PostReform ///
			if VehicleCategory == `vc', fe vce(robust)
		
		margins 1.PostReform 1.ZipDisadvantaged#1.PostReform, post
		local EstName RebateCountP`VCName'
		estimates store `EstName'
		local EstList : list EstList | EstName
		#delim ;
			outreg , 
				se
				keep(1.PostReform 1.ZipDisadvantaged#1.PostReform)
				ctitles("", "`VCName'")
				rtitles(
					"Post Reform" \ "" \ 
					"Zip Disadvantaged $\times$ Post Reform" \ ""
				)
				merge
			;
		#delim cr
				
	}
	estimates table `EstList', ///
		keep(1.PostReform 1.ZipDisadvantaged#1.PostReform) ///
		b se 
		
	outreg using "${DisComm}/ResultsOut/${ResultsVersion}/Tables/PolicyChangeEffects/EffectOnRebateCounts_Poisson.tex", ///
		tex fragment replace replay		
		
		
	local EstList
	outreg , clear
	foreach vc of local VCList {
	local VCName : label VehicleCategory `vc'	
		**Run regression
		xtreg RebateDollars i.dow i.moy i.year 1.PostReform i.ZipDisadvantaged#1.PostReform ///
			if VehicleCategory == `vc', fe vce(cluster ZIP)
		
		local EstName RebateDollars`VCName'
		estimates store `EstName'
		local EstList : list EstList | EstName
		#delim ;
			outreg , 
				se
				keep(1.PostReform 1.ZipDisadvantaged#1.PostReform)
				ctitles("", "`VCName'")
				rtitles(
					"Post Reform" \ "" \ 
					"Zip Disadvantaged $\times$ Post Reform" \ ""
				)
				merge
			;
		#delim cr
	}
	estimates table `EstList', ///
		keep(1.PostReform 1.ZipDisadvantaged#1.PostReform) ///
		b se
		
	outreg using "${DisComm}/ResultsOut/${ResultsVersion}/Tables/PolicyChangeEffects/EffectOnRebateValues.tex", ///
		tex fragment replace replay	
restore


preserve

	/*keep if DiscontinuityCensusTract == 1*/
	collapse (count) RebateCount = RebateDollars, by(ApplicationDate VehicleCategory CensusTractDisadvantaged)
	
	egen G = group(VehicleCategory CensusTractDisadvantaged)
	drop if missing(G)
	xtset G ApplicationDate, delta(`=DaysPerBlock' days)

	qui levelsof VehicleCategory, local(VCList)
	foreach vc of local VCList {
		local VCName : label VehicleCategory `vc'	
			**Normalize to portion of rebates issued in 2015
		forvalues i=0/1 {
			qui sum RebateCount if CensusTractDisadvantaged == `i' & VehicleCategory == `vc' & year(ApplicationDate) == 2015
			replace RebateCount = RebateCount/r(mean) if CensusTractDisadvantaged == `i' & VehicleCategory == `vc'
		}
		
		#delim ;
			twoway
				(line RebateCount ApplicationDate if CensusTractDisadvantaged == 0, lcolor(orange) )
				(line RebateCount ApplicationDate if CensusTractDisadvantaged == 1, lcolor(blue) )
				if VehicleCategory==`vc' 
				,
				graphregion(color(white))
				xtitle("Date", size(small))
				xlab(, format(%tdMon-YY) labsize(small))
				ytitle("Rate of Rebate Applications" "Compared to 2015 Mean", size(small))
				ylab(,labsize(small))
				xline(`=mdy(3,28,2016)', lcolor(black) lpattern(dash))
				legend(
					rows(1)
					order(- "Disadvantaged:" 1 2)
					label(1 "No")
					label(2 "Yes")
					size(small)
				)
			;
		#delim cr
		graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/RebateValueByWeek/RebateCountByWeek_`VCName'.pdf", replace	
		
		#delim ;
			twoway
				(line D.RebateCount ApplicationDate if CensusTractDisadvantaged == 0, lcolor(orange) )
				(line D.RebateCount ApplicationDate if CensusTractDisadvantaged == 1, lcolor(blue) )
				if VehicleCategory==`vc' 
				,
				graphregion(color(white))
				xtitle("Date", size(small))
				xlab(, format(%tdMon-YY) labsize(small))
				ytitle("First Difference Rate of Rebate Applications" "Compared to 2015 Mean", size(small))
				ylab(,labsize(small))
				xline(`=mdy(3,28,2016)', lcolor(black) lpattern(dash))
				legend(
					rows(1)
					order(- "Disadvantaged:" 1 2)
					label(1 "No")
					label(2 "Yes")
					size(small)
				)
			;
		#delim cr
		graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/RebateValueByWeek/RebateCountByWeek_`VCName'_FirstDiffs.pdf", replace		
	}
restore

***********************************************
** Make graphs of the range of rebate values over time
***********************************************
preserve
	#delim ;
		collapse 
			(p5) MinRebate = RebateDollars
			(p50) P50Rebate = RebateDollars
			(p95) MaxRebate = RebateDollars
			, 
			by(ApplicationDate VehicleCategory CensusTractDisadvantaged DiscontinuityCensusTract)
		;
	#delim cr
		
	egen G = group(VehicleCategory CensusTractDisadvantaged DiscontinuityCensusTract)
	drop if missing(G)
	xtset G ApplicationDate, delta(`=DaysPerBlock' days)
	
	qui levelsof VehicleCategory, local(VCList)
	foreach vc of local VCList {
		local VCName : label VehicleCategory `vc'	
		#delim ;
			twoway
				(line MinRebate MaxRebate ApplicationDate if CensusTractDisadvantaged == 0, lcolor(orange orange) lpattern(dash dash) )
				(line P50Rebate ApplicationDate if CensusTractDisadvantaged == 0, lcolor(orange) lwidth(thick))
				
				(line MinRebate MaxRebate ApplicationDate if CensusTractDisadvantaged == 1, lcolor(blue blue) lpattern(dash dash) )
				(line P50Rebate ApplicationDate if CensusTractDisadvantaged == 1, lcolor(blue) lwidth(thick))
				
				if VehicleCategory == `vc' & DiscontinuityCensusTract == 1
				,
				graphregion(color(white))
				xtitle("Date", size(small))
				xlab(, format(%tdMon-YY) labsize(small))
				ytitle("Rebate Value ($)", size(small))
				ylab(,labsize(small))
				xline(`=mdy(3,28,2016)', lcolor(black) lpattern(dash))
				legend(
					off
				)
			;
		#delim cr
		graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/RebateValueByWeek/RebateValueDistributionByMonthDisadvantaged_`VCName'.pdf", replace				

		#delim ;
			twoway
				(line D.MinRebate MaxRebate ApplicationDate if CensusTractDisadvantaged == 0, lcolor(orange orange) lpattern(dash dash) )
				(line D.P50Rebate ApplicationDate if CensusTractDisadvantaged == 0, lcolor(orange) lwidth(thick))
				
				(line D.MinRebate MaxRebate ApplicationDate if CensusTractDisadvantaged == 1, lcolor(blue blue) lpattern(dash dash) )
				(line D.P50Rebate ApplicationDate if CensusTractDisadvantaged == 1, lcolor(blue) lwidth(thick))
				
				if VehicleCategory == `vc' & DiscontinuityCensusTract == 1
				,
				graphregion(color(white))
				xtitle("Date", size(small))
				xlab(, format(%tdMon-YY) labsize(small))
				ytitle("Rebate Value ($)", size(small))
				ylab(,labsize(small))
				xline(`=mdy(3,28,2016)', lcolor(black) lpattern(dash))
				legend(
					off
				)
			;
		#delim cr
		graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/RebateValueByWeek/RebateValueDistributionByMonthDisadvantaged_`VCName'_FirstDiffs.pdf", replace				

	}
restore


***********************************************
** Graph the empricial hazard of obtaining a large (supra-modal) rebate
***********************************************
preserve
	
	egen ModalRebate = mode(RebateDollars), by(ApplicationDate VehicleCategory) maxmode
	gen byte LargeRebate = RebateDollars > ModalRebate
	
	#delim ;
		collapse 
			(mean) LargeRebate
			, 
			by(ApplicationDate VehicleCategory CensusTractDisadvantaged /*DiscontinuityCensusTract*/)
		;
	#delim cr
	
			
	egen G = group(VehicleCategory CensusTractDisadvantaged /*DiscontinuityCensusTract*/)
	drop if missing(G)
	xtset G ApplicationDate, delta(`=DaysPerBlock' days)
	sort G ApplicationDate
	
	*qui levelsof VehicleCategory, local(VCList)
	local VCList 1 4
	
	foreach vc of local VCList {
		local VCName : label VehicleCategory `vc'	
	
			
		#delim ;
			twoway
				(line LargeRebate ApplicationDate if CensusTractDisadvantaged == 0, lcolor(orange) )
				(line LargeRebate ApplicationDate if CensusTractDisadvantaged == 1, lcolor(blue) )
				if VehicleCategory == `vc' /*& DiscontinuityCensusTract == 1*/
				,
				graphregion(color(white))
				xtitle("Date", size(small))
				xlab(, format(%tdMon-YY) labsize(small))
				ytitle("Pr(Rebate > Mode(Rebate))", size(small))
				ylab(,labsize(small))
				xline(`=mdy(3,28,2016)', lcolor(black) lpattern(dash))
				legend(
					rows(1)
					order(- "Disadvantaged:" 1 2)
					label(1 "No")
					label(2 "Yes")
					size(small)
				)
			;
		#delim cr
		graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/RebateValueByWeek/LargeRebateProbability_`VCName'.pdf", replace
		
		#delim ;
			twoway
				(line D.LargeRebate ApplicationDate if CensusTractDisadvantaged == 0, lcolor(orange) )
				(line D.LargeRebate ApplicationDate if CensusTractDisadvantaged == 1, lcolor(blue) )
				if VehicleCategory == `vc' /*& DiscontinuityCensusTract == 1*/
				,
				graphregion(color(white))
				xtitle("Date", size(small))
				xlab(, format(%tdMon-YY) labsize(small))
				ytitle("Pr(Rebate > Mode(Rebate))", size(small))
				ylab(,labsize(small))
				xline(`=mdy(3,28,2016)', lcolor(black) lpattern(dash))
				legend(
					rows(1)
					order(- "Disadvantaged:" 1 2)
					label(1 "No")
					label(2 "Yes")
					size(small)
				)
			;
		#delim cr
		graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/RebateValueByWeek/LargeRebateProbability_`VCName'_FirstDiffs.pdf", replace
		
	}
restore


**********************************
** Summary of mean rebate 
** by category
**********************************
gen byte sample = 1
foreach g in CensusTract Zip {
	capture matrix drop RESULT
	foreach c in ALL DisNo DisYes {
		if "`c'" == "ALL" {
			local ctitle All
			replace sample = Discontinuity`g' == 1
		}
		else if "`c'" == "DisNo"  {
			local ctitle No
			replace sample = Discontinuity`g' == 1 & `g'Disadvantaged == 0
		}
		else if "`c'" == "DisYes" {
			local ctitle Yes
			replace sample = Discontinuity`g' == 1 & `g'Disadvantaged == 1
		}
		else {
			di "{err}Unknown sample"
			exit 99
		}
		**Limit the sample to one year before and after the cuttoff date
		**We currently don't have data out this far, but we'll go with it anyway
		**since the limititaion applies to both groups
		replace sample = 0 if !inrange(ApplicationDate, mdy(8,1,2015), mdy(1,1,2017))

		capture matrix drop RESULT_COL
		foreach vc in BEV PHEV {
			forvalues p=0/1 {
				sum RebateDollars if sample == 1 & VehicleCategory == "`vc'":VehicleCategory & PostRebateDifferentiation == `p', det
				matrix RESULT_COL = nullmat(RESULT_COL) \ r(mean), r(sd) \ r(N), .
			}
		}
		
		matrix RESULT = nullmat(RESULT), RESULT_COL
	}

	#delim ;
		frmttable using "${DisComm}/ResultsOut/${ResultsVersion}/Tables/SummaryStats/RebatesBy`g'.tex", 
			statmat(RESULT) substat(1) 
			tex fragment replace sdec(0 \ 2 ) noblankrows
			rtitles(
				"BEV", "Pre", "Mean Rebate" \ 
				"", "", "" \
				"", "", "N Trans" \
				"", "", "" \
				"", "Post", "Mean Rebate" \
				"", "", "" \
				"", "", "N Trans" \
				"", "", "" \
				"PHEV", "Pre", "Mean Rebte" \
				"", "", "" \
				"", "", "N Trans" \
				"", "", "" \
				"", "Post", "Mean Rebate" \
				"", "", "" \
				"", "", "N Trans" \
				"", "", "" 
			)
			ctitles("Disadvantaged Status", "", "", "All", "No", "Yes")
			hlines(11000000010000001)
			multicol(1,1,3)
		;
	#delim cr
}

		
