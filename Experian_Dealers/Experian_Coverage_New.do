<<dd_include: header.txt >>

~~~~
<<dd_do: qui >>
//Set Locals

//set Bandwidth 
local bandwidth_s = 10
local bandwidth_m = 20
local bandwidth_w = 40
local RD_Cutoff = 36.6
//Vehicle technologies
local tech_1 `""Hybrid", "BEV", "PHEV""'
local tech_2 `""Conventional", "OTHER""'


//read in model clean-up directory
import delimited using "${ExperianCode}/models_after.csv", clear case(preserve) stringcol(_all) varnames(1)

merge 1:m VehicleModel VehicleMake using  "$WorkingDirs/Tyler/Experian_merged",  assert( match) nogen


//look to see about pricing data
hist PurchasePrice if Source == "New Data"  & NewUsedIndicator == "N" & PurchasePrice < 50000, ///
	title("New Cars in New Data") ///
	xtitle("Reported Purchase Price") ///
	ytitle("Density") ///
	note("new sales with a reported purchase price below $50,000") ///
	name("PriceNewinNew")

hist PurchasePrice if Source == "Backfill"  & NewUsedIndicator == "N" & PurchasePrice < 50000, ///
	title("New Cars in Backfill Data") ///
	xtitle("Reported Purchase Price") ///
	ytitle("Density") ///
	note("new sales with a reported purchase price below $50,000") ///
	name("PriceNewinBackfill")


hist PurchasePrice if Source == "New Data"  & NewUsedIndicator == "U" & PurchasePrice < 50000, ///
	title("Used Cars in New Data") ///
	xtitle("Reported Purchase Price") ///
	ytitle("Density") ///
	note("used sales with a reported purchase price below $50,000") ///
	name("PriceUsedinNew")
	
hist PurchasePrice if Source == "Backfill"  & NewUsedIndicator == "U" & PurchasePrice < 50000, ///
	title("Used Cars in Backfill Data") ///
	xtitle("Reported Purchase Price") ///
	ytitle("Density") ///
	note("used sales with a reported purchase price below $50,000") ///
	name("PriceUsedinBackfill")

count if  Source == "New Data"  
local NewDataCount = r(N)

count if  Source == "New Data"  & NewUsedIndicator == "N"
local NewinNewCount = r(N)

count if  Source == "New Data"  & NewUsedIndicator == "U"
local UsedinNewCount = r(N)


count if  Source == "Backfill"  
local BackfillDataCount = r(N)

count if  Source == "Backfill"  & NewUsedIndicator == "N"
local NewinBackfillCount = r(N)

count if  Source == "Backfill"  & NewUsedIndicator == "U"
local UsedinBackfillCount = r(N)


count if PurchasePrice  < 10000 &  Source == "New Data"  & NewUsedIndicator == "U"
local LowPriceUsedinNewCount = r(N)

sum OdometerReading if PurchasePrice  < 10000 &  Source == "New Data"  & NewUsedIndicator == "U", d
local Odo90inLowPriceUsedinNew = r(p90)

sum VehicleYear if PurchasePrice  < 10000 &  Source == "New Data"  & NewUsedIndicator == "U", d
local Year10inLowPriceUsedinNew = r(p90)




local carlist Leaf Prius Volt model Civic
local min_purchase_price 10000 //Prices are bimodal, I suspect that the lower bunching is misreported prices.

bys VIN: gen flag =  (new_car_in_new_data & new_car_in_old_data) & _n == 1
count if flag
local NewCarOverlap = `r(N)'
drop flag


bys VIN: gen flag =  (used_car_in_new_data & used_car_in_old_data) & _n == 1
count if flag
local UsedCarOverlap = `r(N)'
drop flag

tab Source VehicleYear if (strpos(VehicleModel , "LEAF")|strpos(VehicleModel , "Leaf")) & DealerState == "CA"

foreach car of local carlist {
	preserve
		if "`car'" == "model" {
			local carname  "Tesla"
		}
		else {
			local carname "`car'"
		}
		gen flag = 1
		keep if strpos(lower(VehicleModel) , lower("`car'")) & DealerState == "CA"
		collapse (count) CarsSold = flag, by(VehicleYear NewUsedIndicator)
		generate Car = "`car'"
		save "${WorkingDirs}/Tyler/`car'_counts", replace
		//add to stack the bars
		bysort VehicleYear : egen New_Data_stack = sum(CarsSold)
		graph twoway ///
			(bar  New_Data_stack VehicleYear if  NewUsedIndicator == "N") ///
			(bar  CarsSold VehicleYear if  NewUsedIndicator == "U") ///
			,  ///
			xtitle("Model Year") ytitle("Vehicle Sales") ///
			legend( label(1 "New Cars") label( 2 "Used Cars")) ///
			title("CA `carname' Sales") name("`car'_sales", replace)


	restore
}
preserve
	clear
	foreach car of local carlist {
		append using "${WorkingDirs}/Tyler/`car'_counts"
	}
restore




//Time series of prices, by model 
foreach car of local carlist {
	preserve
		if "`car'" == "model" {
			local carname  "Tesla"
		}
		else {
			local carname "`car'"
		}
		keep if PurchasePrice > `min_purchase_price' | NewUsedIndicator == "U"
		keep if strpos(lower(VehicleModel) , lower("`car'")) & DealerState == "CA"
		collapse (p50) PurchasePrice, by(VehicleYear NewUsedIndicator)
		generate Car = "`car'"
		save "${WorkingDirs}/Tyler/`car'_Prices", replace
		//add to stack the bars
		generate VehicleYear_OffsetR = VehicleYear + .25
		generate VehicleYear_OffsetL = VehicleYear - .25
		graph twoway ///
			(bar  PurchasePrice VehicleYear_OffsetR if  NewUsedIndicator == "N", barwidth(.5)) ///
			(bar  PurchasePrice VehicleYear_OffsetL if  NewUsedIndicator == "U", barwidth(.5) ) ///
			,  ///
			yscale(range(0,)) ylabel(#5) ///
			xtitle("Model Year") ytitle("Median Purchase Price") ///
			legend( label(1 "New Cars") label( 2 "Used Cars")) ///
			title("CA `carname' Prices") name("`car'_prices", replace) ///
			note("note that new car transaction prices < $`min_purchase_price' have been dropped")


	restore
}
preserve
	clear
	foreach car of local carlist {
		append using "${WorkingDirs}/Tyler/`car'_prices"
	}
restore


//figure out change in comparison cars
save "${WorkingDirs}/Tyler/testdata", replace

/*
forvalues i = 1/2 {
	preserve
		gen flag = 1
		keep if inlist(Replacement_Vehicle_Tech, "`tech_`i''")
		collapse (count) VehicleCount = flag , by(ConsolidatedMake Source)
		replace Source = substr(Source, 1, 3)
		reshape wide VehicleCount , i(ConsolidatedMake ) j(Source ) string
	
		rename (VehicleCount* ConsolidatedMake) (*Data Make)
		replace NewData = 0 if missing(NewData)
		replace OldData = 0 if missing(OldData)
		tempfile group`i'
		save `group`i''
	restore
}


*/

**********CVRP DATA MERGE

import delimited "${Data}/mapfiles/overlapMatrix/CA_Census_Tracts_to_ZIP_codes_2010.txt", clear
tostring v1 , format(%12.0f) generate(tract)
tostring v2, generate(OwnerZipCode)
drop v1 v2 v3
save "$scratch/CensusZipMap", replace


//Prep tract-level info
import excel using "${Data}/CVRP Incentives/Data/Source/CVRPStats_20170418/CVRPStats.xlsx", clear firstrow
tostring CensusTract , format(%12.0f) generate(tract)
tostring ZIP, generate(OwnerZipCode)
keep tract DACCensusTractFlag DACZIPCodeFlag OwnerZipCode 
duplicates drop

merge 1:1 OwnerZipCode tract using "$scratch/CensusZipMap", nogen

//fill in the zip code flags that we know
tempvar zipflag
bysort OwnerZipCode : egen `zipflag' = mean(DACZIPCodeFlag )
replace DACZIPCodeFlag = `zipflag' if missing(DACZIPCodeFlag)
assert inlist( DACZIPCodeFlag, 1 , 0, .)

//fill in the tract flags that we know
tempvar tractflag
bysort tract : egen `tractflag' = mean(DACCensusTractFlag )
replace DACCensusTractFlag = `tractflag' if missing(DACCensusTractFlag)
assert inlist( DACCensusTractFlag, 1 , 0, .)


tempfile preCES
save `preCES'
save "$scratch/preCES", replace

import excel using "${Data}/Disdvantaged Community designation in CA (related to EFMP)/CalEnviroScreen2_Scores_Full_Oct_2014.xlsx", clear firstrow
rename ZIP CESZip
tostring CensusTract , format(%12.0f) generate(tract)
keep CESZip tract CES20Score 

merge 1:m tract using `preCES'

save "${WorkingDirs}/Tyler/testdata179", replace
destring CES20Score , replace ignore("NA")
gen CES20Score_rnd = round(CES20Score )
bysort CES20Score_rnd : egen zip_fraction = mean(DACZIPCodeFlag )
scatter zip_fraction CES20Score_rnd , ///
	title("Tract-Level CES and Zip-level DAC status") ///
	xtitle("CES Score (rounded)") ///
	ytitle("Fraction of Tracts falling in a DAC Zip code") ///
	xline(36.6 ) note("Vertical line at DAC Threshold") ///
	name("ZipCESDAC", replace) 

scatter DACCensusTractFlag CES20Score , ///
	title("Tract-level CES and Tract level DAC status") ///
	xtitle("CES Score") ///
	ytitle("Tract level DAC status") ///
	xline(36.6) note("Vertical line at DAC Threshold") ///
	name("tractCESDAC", replace)
	
bysort OwnerZipCode : egen MaxCES = max(CES20Score )
gen MaxCES_rnd = round(MaxCES  )
bysort MaxCES_rnd : egen zip_fraction_maxCES = mean(DACZIPCodeFlag )

scatter zip_fraction_maxCES  MaxCES_rnd , ///
	title("DAC Status by highest CES in Zip") ///
	xtitle("Highest CES in Zip (rounded)") ///
	ytitle("Fraction of Tracts falling in a DAC Zip code") ///
	xline(36.6) note("Vertical line at DAC Threshold") ///
	name("running_var", replace)
		
		
//Save tract-CES score mapping
preserve
	keep tract CES20Score DACCensusTractFlag
	duplicates drop
	isid tract
	tempfile tractCES
	save `tractCES'
restore
//Save Zip--maxCES mapping
preserve 
	keep OwnerZipCode MaxCES DACZIPCodeFlag 
	duplicates drop
	drop if missing(OwnerZipCode)
	isid OwnerZipCode
	tempfile maxCES
	save `maxCES'
restore


//RD binscatter
//Merge in CVRP data

use "${WorkingDirs}/Tyler/testdata", clear
keep if !missing(OwnerCensusBlockGroup)

tostring OwnerCensusBlockGroup , format(%12.0f) generate(tract)
replace tract = substr(tract, 1, 10)



merge m:1 tract using `tractCES', keep(master match) assert(master match using) nogen

tostring OwnerZipCode, replace
merge m:1 OwnerZipCode using `maxCES', keep(master match) assert(master match using) nogen

//Restrict to only EFMP eligible districts
preserve
	use "${Data}/mapfiles/Air Quality Districts/CensusTract_to_AQMD_map.dta", clear
	keep if inlist( AQMD_ID, 24, 38)
	keep CensusTract
	rename CensusTract tract
	replace tract = substr(tract, 2, 10)
	duplicates drop
	tempfile eligible_AQMD
	save `eligible_AQMD'
restore
merge m:1 tract using `eligible_AQMD', keep(matched)
pause 313

foreach bandwidth_spec in s m w {
	local bw_H = `RD_Cutoff'+`bandwidth_`bandwidth_spec''
	local bw_L = `RD_Cutoff'-`bandwidth_`bandwidth_spec''
	di `bw_H' `bw_L'
	keep if inlist(Replacement_Vehicle_Tech, "`tech_1'") & inrange(MaxCES , `bw_L',`bw_H') & (PurchasePrice > `min_purchase_price' | NewUsedIndicator == "U")

	foreach new_used in New Used {
		preserve
			keep if strpos("`new_used'", NewUsedIndicator)
			di "`new_used'"
			if "`new_used'" == "New" {
				local restriction " with reported sales prices over $10,000"
			}
			else {
				local restriction
			}
			pause 237
			binscatter PurchasePrice MaxCES , ///
				rd(`RD_Cutoff')  n(40) ///
				title("Uncontrolled RD Plot") ///
				ytitle("Average Purchase Price") ///
				xtitle("Highest CES score in Zip") ///
				note("restricted to `new_used' Zero Emissions Vehicles`restriction'") ///
				name("uncontRD`new_used'_bw_`bandwidth_spec'", replace)
		pause 335
			binscatter PurchasePrice MaxCES , ///
				rd(`RD_Cutoff')  n(40) controls(CES20Score) ///
				title("Controlled RD Plot") ///
				ytitle("Average Purchase Price" "Controlling for tract-level CES") ///
				xtitle("Highest CES score in Zip") ///
				note("restricted to `new_used' Zero Emissions Vehicles`restriction'") ///
				name("contRD`new_used'_bw_`bandwidth_spec'" , replace)
			
	

		restore
	}

}

pause 348
gen Eligible = (MaxCES > `RD_Cutoff')
tempfile data_for_reg
save `data_for_reg'
pause 352
foreach new_used in New Used {
	preserve
		keep if strpos("`new_used'", NewUsedIndicator)
		
		if "`new_used'" == "New" {
			local restriction " with reported sales prices over $10,000"
		}
		else {
			local restriction
		}
		
		gen MaxCES_rnd = round(MaxCES )

		collapse (count) Transaction_count = PurchasePrice , by(MaxCES_rnd )

		graph twoway bar Transaction_count MaxCES_rnd , ///
			title("Transaction Density by Forcing Variable") ///
			xtitle("Highest CES score in Zip") ///
			ytitle("Transaction Count") ///
			xline(36.6) ///
			note("restricted to `new_used' Zero Emissions Vehicles`restriction'" "Vertical line at DAC Threshold") ///
			name("rd_density_plot`new_used'", replace)	
	restore
}

<</dd_do>>
~~~~
#Update to Experian and CES RDD Groundwork
This document updates the prior effort to lay groundwork for the Experian/EFMP RD effort.  
It only contains sections that have been updated since out August 9 meeting.

Prepared by Tyler Hoppenfeld

##General Data Quality:

###Sales Numbers
Sales numbers appear to be volatile between model years.  They seem to be roughly comparable 
between data sets, however I do not observe a clear time trend.  
<<dd_graph: graphname(Leaf_sales) saving(leaf_sales.png) replace height(400) width(500) >>


Leaf sales appear particularly volitile, which is consistant with the actual American sales numbers for that vehicle.  
Wikipedia aggregates a variety of sources to give us the following US sales by year of sale (not vehicle model year).


Year|	2015|	2014|	2013|	2012|	2011|	2010
----|----|----|----|----|----|----|
 US Leaf Sales |	17,269	|30,200|	22,610|	9,819	|9,674 |19
 



##RD Design Studies
From conversations with Erich and David, I understand that DAC zip-code status is based on 
the most disadvantaged (highest CES score) Census Block in a Zip Code.  However, while we 
have transaction data at the Census Block level, we have CES data at the larger Census 
Tract level, and DAC status data at the Zip and Tract level.  


Tract level CES score perfectly predicts Tract level DAC status, as we can see here:  
<<dd_graph: graphname(tractCESDAC) saving(tractCESDAC.png) replace height(400) width(500) >>


CES scores at the Tract level generally predict whether the containing zip code will have 
DAC status.  Few tracts with low CES scores fall into DAC Zip Codes, and nearly all tracts 
with a CES high enough to be a DAC tract are also in a DAC zip code:  
<<dd_graph: graphname(ZipCESDAC) saving(ZipCESDAC.png) replace height(400) width(500) >>


While the running variable  actually depends on the CES at the Census Block level, we can 
approximate it using Census Tract level CES.  Using Jim's mapping of zip to census-tract, 
we see much improved behavior--there is a rather sharp cutoff at the location we expect.

<<dd_graph: graphname(running_var) saving(running_var.png) replace height(400) width(500) >>

If car buyers or dealers are able to affect their eligibility, that undermines the validity
of the RD design.  To assess this, I present a density plot by the forcing variable in the San Joaquin and South Coast air
quality districts, where the EFMP program was piloted for new and used cars.
:
 <<dd_graph: graphname(rd_density_plotNew) saving(rd_density_plotNew.png) replace height(400) width(500) >>
 <<dd_graph: graphname(rd_density_plotUsed) saving(rd_density_plotUsed.png) replace height(400) width(500) >>


##RD Graphs and Regressions

For these exercises, I have restricted the data to the San Joaquin and South Coast air
quality districts, where the EFMP program was piloted.


As a proof-of-concept, here are two binscatters of average purchase price against the forcing variable.
One is with a control for the CES of the specific tract, and one is without.  Both are
 restricted to a bandwidth of 20 on either side of the RD threshold of 36.6.  Presented for new and used cars:
 
 <<dd_graph: graphname(contRDNew_bw_m) saving(contRDNew_bw_m.png) replace height(400) width(500) >>
 <<dd_graph: graphname(uncontRDNew_bw_m) saving(uncontRDNew_bw_m.png) replace height(400) width(500) >>

 <<dd_graph: graphname(contRDUsed_bw_m) saving(contRDUsed.png_bw_m) replace height(400) width(500) >>
 <<dd_graph: graphname(uncontRDUsed_bw_m) saving(uncontRDUsed.png_bw_m) replace height(400) width(500) >>


As a trial run, I present two potential specifications for the RD regression, with minimal 
controls, with the same bandwidth and restrictions as the above plots. The dummy variable 
"eligible" signifies whether the forcing variable is over the 36.6 cutoff.

~~~~
<<dd_do:nocommands>>
use `data_for_reg', clear
quietly keep if inrange(MaxCES ,`RD_Cutoff'-`bandwidth_m',`RD_Cutoff'+`bandwidth_m')
encode ConsolidatedMake, generate( VehicleMake_code)
encode ConsolidatedModel, generate( VehicleModel_code)
di "New Cars:"
regress PurchasePrice Eligible MaxCES if NewUsedIndicator == "N"
di "Used Cars"
regress PurchasePrice Eligible MaxCES if NewUsedIndicator == "U"
<</dd_do>>
~~~~
Using the tract-level CES score as a covariate:

~~~~
<<dd_do:nocommands>>
di "New Cars"
regress PurchasePrice Eligible MaxCES CES20Score if NewUsedIndicator == "N"
di "Used Cars"
regress PurchasePrice Eligible MaxCES CES20Score if NewUsedIndicator == "U"
<</dd_do>>
~~~~

Adding in Make/Model controlls
~~~~
<<dd_do:nocommands>>
di "New Cars"
regress PurchasePrice Eligible MaxCES CES20Score i.VehicleMake_code i.VehicleModel_code if NewUsedIndicator == "N"
di "Used Cars"
regress PurchasePrice Eligible MaxCES CES20Score i.VehicleMake_code i.VehicleModel_code if NewUsedIndicator == "N"
<</dd_do>>
~~~~


 Finally, I estimate the OLS version of these regressions. 
The variable "Zip_Code_Elig" indicates whether the owner lives in a DAC zip code.

~~~~
<<dd_do:nocommands>>


rename DACZIPCodeFlag Zip_Code_Elig
regress PurchasePrice Zip_Code_Elig  MaxCES 
<</dd_do>>
~~~~
Using the a broader set of covariates:

~~~~
<<dd_do:nocommands>>
regress PurchasePrice Zip_Code_Elig  DACCensusTractFlag MaxCES CES20Score i.VehicleMake_code i.VehicleModel_code
<</dd_do>>
~~~~


#CVRP vs Experian transaction overlap:
I attempted to assess the overlap of the CVRP and Experian data, but the CVRP data that I see
 does not include VIN, so any assessment will involve matching make, model, zip code, and a 
 rough transaction date. I will attempt to do this, but it won't be as quick as I had hoped a 
 VIN based match would be.



#L&L List:
## To assess the possibility of manipulation of the assignment variable, show its distribution.

 <<dd_graph: graphname(rd_density_plotNew) saving(rd_density_plotNew.png) replace height(400) width(500) >>
 <<dd_graph: graphname(rd_density_plotUsed) saving(rd_density_plotUsed.png) replace height(400) width(500) >>


## Present the main RD graph using
binned local averages. 
 <<dd_graph: graphname(contRDNew_bw_m) saving(contRDNew_bw_m.png) replace height(400) width(500) >>
 <<dd_graph: graphname(uncontRDNew_bw_m) saving(uncontRDNew_bw_m.png) replace height(400) width(500) >>

 <<dd_graph: graphname(contRDUsed_bw_m) saving(contRDUsed_bw_m.png) replace height(400) width(500) >>
 <<dd_graph: graphname(uncontRDUsed_bw_m) saving(uncontRDUsed_bw_m.png) replace height(400) width(500) >>
 
## Graph a benchmark polynomial specification
--Calculated but not graphed.  Graphs will take time, because I can't use the binscatter command.
~~~
<<dd_do:nocommands>>

use `data_for_reg', clear
quietly keep if inrange(MaxCES ,`RD_Cutoff'-`bandwidth_s',`RD_Cutoff'+`bandwidth_s')
encode ConsolidatedMake, generate( VehicleMake_code)
encode ConsolidatedModel, generate( VehicleModel_code)
di "New Cars:"
regress PurchasePrice Eligible c.MaxCES##c.MaxCES if NewUsedIndicator == "N"
di "Used Cars"
regress PurchasePrice Eligible c.MaxCES##c.MaxCES if NewUsedIndicator == "U"
<</dd_do>>
~~~~
Using the tract-level CES score as a covariate:

~~~~
<<dd_do:nocommands>>

di "New Cars"
regress PurchasePrice Eligible c.MaxCES##c.MaxCES CES20Score if NewUsedIndicator == "N"
di "Used Cars"
regress PurchasePrice Eligible c.MaxCES##c.MaxCES CES20Score if NewUsedIndicator == "U"
<</dd_do>>
~~~~

Adding in Make/Model controlls
~~~~
<<dd_do:nocommands>>

di "New Cars"
regress PurchasePrice Eligible c.MaxCES##c.MaxCES CES20Score i.VehicleMake_code i.VehicleModel_code if NewUsedIndicator == "N"
di "Used Cars"
regress PurchasePrice Eligible c.MaxCES##c.MaxCES CES20Score i.VehicleMake_code i.VehicleModel_code if NewUsedIndicator == "N"
<</dd_do>>
~~~~

## Explore the sensitivity of the results to a range of bandwidths, and a range of orders to the polynomial.

BW = 10

 <<dd_graph: graphname(contRDNew_bw_s) saving(contRDNew_bw_s.png) replace height(400) width(500) >>
 <<dd_graph: graphname(uncontRDNew_bw_s) saving(uncontRDNew_bw_s.png) replace height(400) width(500) >>

 <<dd_graph: graphname(contRDUsed_bw_s) saving(contRDUsed_bw_s.png) replace height(400) width(500) >>
 <<dd_graph: graphname(uncontRDUsed_bw_s) saving(uncontRDUsed_bw_s.png) replace height(400) width(500) >>
 
BW = 40

 <<dd_graph: graphname(contRDNew_bw_w) saving(contRDNew_bw_w.png) replace height(400) width(500) >>
 <<dd_graph: graphname(uncontRDNew_bw_w) saving(uncontRDNew_bw_w.png) replace height(400) width(500) >>

 <<dd_graph: graphname(contRDUsed_bw_w) saving(contRDUsed_bw_w.png) replace height(400) width(500) >>
 <<dd_graph: graphname(uncontRDUsed_bw_w) saving(uncontRDUsed_bw_w.png) replace height(400) width(500) >>
 
Regression on narrow bandwidth (+/- 10):
~~~
<<dd_do:nocommands>>

use `data_for_reg', clear
quietly keep if inrange(MaxCES ,`RD_Cutoff'-`bandwidth_s',`RD_Cutoff'+`bandwidth_s')
encode ConsolidatedMake, generate( VehicleMake_code)
encode ConsolidatedModel, generate( VehicleModel_code)
di "New Cars:"
regress PurchasePrice Eligible MaxCES if NewUsedIndicator == "N"
di "Used Cars"
regress PurchasePrice Eligible MaxCES if NewUsedIndicator == "U"
<</dd_do>>
~~~~
Using the tract-level CES score as a covariate:

~~~~
<<dd_do:nocommands>>

di "New Cars"
regress PurchasePrice Eligible MaxCES CES20Score if NewUsedIndicator == "N"
di "Used Cars"
regress PurchasePrice Eligible MaxCES CES20Score if NewUsedIndicator == "U"
<</dd_do>>
~~~~

Adding in Make/Model controlls
~~~~
<<dd_do:nocommands>>

di "New Cars"
regress PurchasePrice Eligible MaxCES CES20Score i.VehicleMake_code i.VehicleModel_code if NewUsedIndicator == "N"
di "Used Cars"
regress PurchasePrice Eligible MaxCES CES20Score i.VehicleMake_code i.VehicleModel_code if NewUsedIndicator == "N"
<</dd_do>>
~~~~

 
Regression on wide bandwidth (+/- 40):
~~~
<<dd_do:nocommands>>

use `data_for_reg', clear
quietly keep if inrange(MaxCES ,`RD_Cutoff'-`bandwidth_w',`RD_Cutoff'+`bandwidth_w')
encode ConsolidatedMake, generate( VehicleMake_code)
encode ConsolidatedModel, generate( VehicleModel_code)
di "New Cars:"
regress PurchasePrice Eligible MaxCES if NewUsedIndicator == "N"
di "Used Cars"
regress PurchasePrice Eligible MaxCES if NewUsedIndicator == "U"
<</dd_do>>
~~~~
Using the tract-level CES score as a covariate:

~~~~
<<dd_do:nocommands>>

di "New Cars"
regress PurchasePrice Eligible MaxCES CES20Score if NewUsedIndicator == "N"
di "Used Cars"
regress PurchasePrice Eligible MaxCES CES20Score if NewUsedIndicator == "U"
<</dd_do>>
~~~~

Adding in Make/Model controlls
~~~~
<<dd_do:nocommands>>

di "New Cars"
regress PurchasePrice Eligible MaxCES CES20Score i.VehicleMake_code i.VehicleModel_code if NewUsedIndicator == "N"
di "Used Cars"
regress PurchasePrice Eligible MaxCES CES20Score i.VehicleMake_code i.VehicleModel_code if NewUsedIndicator == "N"
<</dd_do>>
~~~~

## Conduct a parallel RD analysis on
the baseline covariates. 

Gender:
~~~
 <<dd_do:nocommands>>
use `data_for_reg', clear
quietly keep if inrange(MaxCES ,`RD_Cutoff'-`bandwidth_m',`RD_Cutoff'+`bandwidth_m')
encode ConsolidatedMake, generate( VehicleMake_code)
encode ConsolidatedModel, generate( VehicleModel_code)
encode Ethnicity, generate(Ethnicity_code)
generate White_code = Ethnicity == "Non-Hispanic White"

generate male_code = Gender == "M"
generate female_code = Gender == "F"
di "New Cars:"
regress male_code   Eligible MaxCES  if NewUsedIndicator == "N"
regress female_code   Eligible MaxCES  if NewUsedIndicator == "N"
di "Used Cars"
regress male_code   Eligible MaxCES  if NewUsedIndicator == "U"
regress female_code   Eligible MaxCES  if NewUsedIndicator == "U"

<</dd_do>>
~~~~

Income
~~~~
<<dd_do:nocommands>>
di "New Cars:"
regress Income   Eligible MaxCES  if NewUsedIndicator == "N"
di "Used Cars:"
regress Income   Eligible MaxCES  if NewUsedIndicator == "U"
<</dd_do>>
~~~~

Race is sparsely populated, but grouping "Other" and "Null" with all non-whites, we have:
~~~~
<<dd_do:nocommands>>
di "New Cars:"
regress White_code  Eligible MaxCES  if NewUsedIndicator == "N"
di "Used Cars:"
regress White_code  Eligible MaxCES  if NewUsedIndicator == "U"
<</dd_do>>
~~~~

## Explore the sensitivity of the results
to the inclusion of baseline covariates.

~~~
 <<dd_do:nocommands>>
use `data_for_reg', clear
quietly keep if inrange(MaxCES ,`RD_Cutoff'-`bandwidth_m',`RD_Cutoff'+`bandwidth_m')
encode ConsolidatedMake, generate( VehicleMake_code)
encode ConsolidatedModel, generate( VehicleModel_code)
encode Ethnicity, generate(Ethnicity_code)
generate male_code = Gender == "M"
generate female_code = Gender == "F"

di "New Cars:"
regress PurchasePrice Eligible MaxCES i.Ethnicity_code male_code female_code Income if NewUsedIndicator == "N"
di "Used Cars"
regress PurchasePrice Eligible MaxCES i.Ethnicity_code male_code female_code Income if NewUsedIndicator == "U"
<</dd_do>>
~~~~
Using the tract-level CES score as a covariate:

~~~~
<<dd_do:nocommands>>
di "New Cars"
regress PurchasePrice Eligible MaxCES CES20Score i.Ethnicity_code male_code female_code Income if NewUsedIndicator == "N"
di "Used Cars"
regress PurchasePrice Eligible MaxCES CES20Score i.Ethnicity_code male_code female_code Income if NewUsedIndicator == "U"
<</dd_do>>
~~~~

Adding in Make/Model controlls
~~~~
<<dd_do:nocommands>>
di "New Cars"
regress PurchasePrice Eligible MaxCES CES20Score i.Ethnicity_code male_code female_code Income i.VehicleMake_code i.VehicleModel_code if NewUsedIndicator == "N"
di "Used Cars"
regress PurchasePrice Eligible MaxCES CES20Score i.Ethnicity_code male_code female_code Income i.VehicleMake_code i.VehicleModel_code if NewUsedIndicator == "N"
<</dd_do>>
~~~~

