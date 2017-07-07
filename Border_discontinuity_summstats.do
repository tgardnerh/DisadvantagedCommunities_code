capture log close
***************************************
** Border_discontinuity_summstats.do
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

log using "${DisComm}/Log/Border_discontinuity_summstats.txt", text replace


use "${DisComm}/Data/CensusTractsAdjacentDisadvantagedStatus.dta", clear
merge 1:1 CensusTract using "${DisComm}/Data/demographics_by_CensusTract.dta", ///
	assert(master match) keep(match) nogen
	
**Generate a variable that indicates the treatement typd of the census tract
label define BorderDiscontinuity 1 "Disdva." 2 "Not Disadv." 3 "Border/Disadv." 4 "Border/Not Disadv."
gen byte BorderDiscontinuity:BorderDiscontinuity = cond(CensusTractDisadvantaged==1,1,2) if CensusTractDisadvantaged < .
replace BorderDiscontinuity = 3 if AdjacentCensusTractNot == 1 & CensusTractDisadvantaged == 1
replace BorderDiscontinuity = 4 if AdjacentCensusTractDisadvantaged == 1 & CensusTractDisadvantaged == 0

local demogs TotalPopulation Age Education Poverty Unemployment RoE*

label var TotalPopulation "Population"
label var Age "Age under 10 or over 65 (\%)"
label var Education "Over 25 less than high school (\%)"
label var Poverty "Below poverty level (\%)"
label var Unemployment "Unemployed (\%)"
label var RoE_Hispanic "Portion Hispanic (\%)"
label var RoE_White "Portion white (\%)"
label var RoE_AfricanAmerican  "Portion African American (\%)"
label var RoE_NativeAmerican  "Portion Native American (\%)"
label var RoE_AsianAmerican  "Portion Asian American (\%)"
label var RoE_Other "Portion other race (\%)"

outreg, clear
forvalues i=1/4 {
	local coltitle : label BorderDiscontinuity `i'
	
	mean `demogs' if BorderDiscontinuity == `i'
	
	outreg , merge varlab nostars se
}

#delim ;
	outreg ,
		replay
		ctitles(
			"", "\underline{\hspace{2em}All\hspace{2em}}", "", "\underline{\hspace{1em}Border\hspace{1em}}", ""\
			"", "Disadv.", "Not Disadv.", "Disadv.", "Not Disadv."
		)
		varlab
		se
	;
#delim cr

outreg using "${DisComm}/ResultsOut/${ResultsVersion}/Tables/SummaryStats/Demographics_BorderDiscontinuity_CensusTracts.tex",  ///
	replay tex fragment replace se ///
	multicol(1,2,2;1,4,2)
	

	
log close
	
	
