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

global DisComm "$Dropbox/Erich_Dave_Projects/Project_DisadvantagedCommunities"
global DisStatus "$Dropbox/Erich_Dave_Projects/Data/Disdvantaged Community designation in CA (related to EFMP)"

log using "${DisComm}/Log/power_calcs.txt", text replace

use "${DisComm}/Data/DisadvantagedCensusTracts.dta"

*********************************
** The following program runs an RD on simulated data using the distribution of 
** the running variable in the underlying data.
** c() is the RD threshold
** effectsize() is the size of the effect to simulate
** errorvariance() is the variance in the unobserved error term
** The intent is you run this program with "simulate" to perform power and size calcs
*********************************
capture program drop SimRD
program define SimRD, rclass
	syntax varname(numeric) [if] [in], [effectsize(real 0) errorvariance(real 1) c(real 0)]
	
	marksample touse
	
	tempvar outcome
	qui gen `outcome' = rnormal(0,`errorvariance') + cond(`varlist' > `c',`effectsize',0)
	
	qui rdrobust `outcome' `varlist' if `touse', vce(cluster ZipCode) all c(`c')
	
	**Extract the robust parameter estiamte and variance
	tempname b V t p reject
	matrix `b' = e(b)
	matrix `V' = e(V)
	scalar `t' = `b'[1,3]/sqrt(`V'[3,3])
	scalar `p' = normal(-1*abs(`t'))*2
	scalar `reject' = `p' <= 0.05
	
	ereturn clear
	
	di "{txt}t-stat: {res}" `t'
	di "{txt}p-value: {res}" `p'
	if `reject' == 1 di "{txt}REJECT" 
	else di "{txt}No REJECT"
	
	return scalar reject = `reject'
	return scalar b = `b'[1,3]
	return scalar se = sqrt(`V'[3,3])
	return scalar t = `t'
end

**Test fire the program
SimRD CES20Score, effectsize(.2) errorvariance(1) c(36.6)

**Set number of simulations. They take about 0.25 seconds each
**And each set of calcs runs 20 sets of simulations. You do the math...
global NumReps 500



capture matrix drop RESULTS
forvalues i=0(0.05)1 {
	use "${DisComm}/Data/DisadvantagedCensusTracts.dta", clear
	
	simulate , reps(${NumReps}) : SimRD CES20Score, effectsize(`i') errorvariance(1) c(36.6)
	
	qui sum reject
	matrix RESULTS = nullmat(RESULTS) \ `i', r(mean)
}

matrix colnames RESULTS = EffectSize Power
clear
qui svmat RESULTS, names(col)

save "${DisComm}/Data/CES20_PowerCalcs_AllData.dta", replace


capture matrix drop RESULTS
forvalues i=0(0.05)1 {
	use "${DisComm}/Data/DisadvantagedCensusTracts.dta", clear
	
	simulate , reps(${NumReps}) : SimRD CES20Score if AQMD_ID == 24, effectsize(`i') errorvariance(1) c(36.6)
	
	qui sum reject
	matrix RESULTS = nullmat(RESULTS) \ `i', r(mean)
}

matrix colnames RESULTS = EffectSize Power
clear
qui svmat RESULTS, names(col)

save "${DisComm}/Data/CES20_PowerCalcs_SanJoaquinValley.dta", replace


capture matrix drop RESULTS
forvalues i=0(0.05)1 {
	use "${DisComm}/Data/DisadvantagedCensusTracts.dta", clear
	
	simulate , reps(${NumReps}) : SimRD CES20Score if AQMD_ID == 38, effectsize(`i') errorvariance(1) c(36.6)
	
	qui sum reject
	matrix RESULTS = nullmat(RESULTS) \ `i', r(mean)
}

matrix colnames RESULTS = EffectSize Power
clear
qui svmat RESULTS, names(col)

save "${DisComm}/Data/CES20_PowerCalcs_SCAQMD.dta", replace


log close
