<<dd_include: header.txt >>

~~~~
<<dd_do: qui >>

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

hist PurchasePrice if Source == "New Data"  & NewUsedIndicator == "U" & PurchasePrice < 50000, ///
	title("Used Cars in New Data") ///
	xtitle("Reported Purchase Price") ///
	ytitle("Density") ///
	note("used sales with a reported purchase price below $50,000") ///
	name("PriceUsedinNew")

count if  Source == "New Data"  
local NewDataCount = r(N)

count if  Source == "New Data"  & NewUsedIndicator == "N"
local NewinNewCount = r(N)

count if  Source == "New Data"  & NewUsedIndicator == "U"
local UsedinNewCount = r(N)

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
		collapse (count) NewCarsSold = flag, by(VehicleYear Source)
		generate Car = "`car'"
		save "${WorkingDirs}/Tyler/`car'_counts", replace
		//add to stack the bars
		bysort VehicleYear : egen New_Data_stack = sum(NewCarsSold)
		graph twoway ///
			(bar  New_Data_stack VehicleYear if  Source == "New Data") ///
			(bar  NewCarsSold VehicleYear if  Source == "Old Data") ///
			,  ///
			xtitle("Model Year") ytitle("New Vehicle Sales") ///
			legend( label(1 "New Data") label( 2 "Old Data")) ///
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
		keep if PurchasePrice > `min_purchase_price'
		keep if strpos(lower(VehicleModel) , lower("`car'")) & DealerState == "CA"
		collapse (p50) PurchasePrice, by(VehicleYear Source)
		generate Car = "`car'"
		save "${WorkingDirs}/Tyler/`car'_Prices", replace
		//add to stack the bars
		generate VehicleYear_OffsetR = VehicleYear + .25
		generate VehicleYear_OffsetL = VehicleYear - .25
		graph twoway ///
			(bar  PurchasePrice VehicleYear_OffsetR if  Source == "New Data", barwidth(.5)) ///
			(bar  PurchasePrice VehicleYear_OffsetL if  Source == "Old Data", barwidth(.5) ) ///
			,  ///
			yscale(range(0,)) ylabel(#5) ///
			xtitle("Model Year") ytitle("Median Purchase Price") ///
			legend( label(1 "New Data") label( 2 "Old Data")) ///
			title("CA `carname' Prices") name("`car'_prices", replace) ///
			note("note that transaction prices < $`min_purchase_price' have been dropped")


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
forvalues i = 1/2 {
	preserve
		gen flag = 1
		keep if strpos(VehicleGroup, "`i'")
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


keep if VehicleGroup == "GROUP 1 - ZEV" & inrange(MaxCES , 16.6,56.6) & PurchasePrice > 10000

binscatter PurchasePrice MaxCES , ///
	rd(36.6)  n(40) ///
	title("Uncontrolled RD Plot") ///
	ytitle("Average Purchase Price") ///
	xtitle("Highest CES score in Zip") ///
	note("restricted to Zero Emissions Vehicles with reported sales prices over $10,000") ///
	name("uncontRD", replace)
	
binscatter PurchasePrice MaxCES , ///
	rd(36.6)  n(40) controls(CES20Score) ///
	title("Controlled RD Plot") ///
	ytitle("Average Purchase Price" "Controlling for tract-level CES") ///
	xtitle("Highest CES score in Zip") ///
	note("restricted to Zero Emissions Vehicles with reported sales prices over $10,000") ///
	name("contRD" , replace)
	





gen Eligible = (MaxCES > 36.6)
tempfile data_for_reg
save `data_for_reg'

gen MaxCES_rnd = round(MaxCES )

collapse (count) Transaction_count = PurchasePrice , by(MaxCES_rnd )

graph twoway bar Transaction_count MaxCES_rnd , ///
	title("Transaction Density by Forcing Variable") ///
	xtitle("Highest CES score in Zip") ///
	ytitle("Transaction Count") ///
	xline(36.6) ///
	note("restricted to Zero Emissions Vehicles with reported sales prices over $10,000" "Vertical line at DAC Threshold") ///
	name("rd_density_plot")	
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


Leaf sales appear particularly voloitile, which is consistant with the actual American sales numbers for that vehicle.  
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
quality districts, where the EFMP program was piloted.
:
 <<dd_graph: graphname(rd_density_plot) saving(rd_density_plot.png) replace height(400) width(500) >>


##RD Graphs and Regressions

For these exercises, I have restricted the data to the San Joaquin and South Coast air
quality districts, where the EFMP program was piloted.


As a proof-of-concept, here are two binscatters of average purchase price against the forcing variable.
One is with a control for the CES of the specific tract, and one is without.  Both are
 restricted to a bandwidth of 20 on either side of the RD threshold of 36.6.
 
 <<dd_graph: graphname(contRD) saving(contRD.png) replace height(400) width(500) >>
 <<dd_graph: graphname(uncontRD) saving(uncontRD.png) replace height(400) width(500) >>


As a trial run, I present two potential specifications for the RD regression, with minimal 
controls, with the same bandwidth and restrictions as the above plots. The dummy variable 
"eligible" signifies whether the forcing variable is over the 36.6 cutoff.

~~~~
<<dd_do:nocommands>>
use `data_for_reg', clear
encode ConsolidatedMake, generate( VehicleMake_code)
encode ConsolidatedModel, generate( VehicleModel_code)
regress PurchasePrice Eligible MaxCES
<</dd_do>>
~~~~
Using the tract-level CES score as a covariate:

~~~~
<<dd_do:nocommands>>

regress PurchasePrice Eligible MaxCES CES20Score
<</dd_do>>
~~~~

Adding in Make/Model controlls
~~~~
<<dd_do:nocommands>>

regress PurchasePrice Eligible MaxCES CES20Score i.VehicleMake_code i.VehicleModel_code
<</dd_do>>
~~~~


These results are borderline statistically significant, and suggest a non-zero pass 
through, fully accounted for by choice of car make or model.  

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

