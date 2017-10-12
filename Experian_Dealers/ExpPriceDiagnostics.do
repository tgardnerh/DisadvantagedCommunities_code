****Experian price diagnostics.

//Set Locals

//set Bandwidth 
local bandwidth_s = 10
local bandwidth_m = 20
local bandwidth_w = 40
local RD_Cutoff = 36.6

local binNumber 20

//lowest price for new car that we call "Reasonable"
local min_purchase_price 8000
//Vehicle technologies
local tech_1 "Hybrid", "BEV", "PHEV"
local tech_2 "Conventional", "OTHER"
//Period of interest
local StartDate = date("March 1 2016", "MDY")

//characters to ignore in destring
local ignore_chars NA

//top ten models
#delimit ;
local topTenModels 
	 `""500"      
	 "C-Max"     
	 "Fusion"       
	 "Leaf"   
	 "Model S"    
	 "Model X"      
	 "Prius"    
	 "Prius C"
	 "Volt"         
	 "i3""' 
;
#delimit cr


***Code starts here***
//read in model clean-up directory
import delimited using "${ExperianCode}/models_after.csv", clear case(preserve) stringcol(_all) varnames(1)

//merge in data
merge 1:m VehicleModel VehicleMake using  "$WorkingDirs/Tyler/Experian",  assert( match master) keep(match) nogen

****Data Restrictions********

//restrict to period of interest
keep if PurchaseDate > `StartDate'

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

//format census block group into tract
tostring OwnerCensusBlockGroup , format(%12.0f) gen(tract)
replace tract = substr(tract, 1, 10)

merge m:1 tract using `eligible_AQMD', keep(matched) nogen


//Fetch CES score data and zip level data
preserve
	import delimited "${Data}/mapfiles/overlapMatrix/CA_Census_Tracts_to_ZIP_codes_2010.txt", clear
	tostring v1 , format(%12.0f) generate(tract)
	tostring v2, generate(OwnerZipCode)
	drop v1 v2 v3
	tempfile zipmap
	save `zipmap'


	import excel using "${Data}/CVRP Incentives/Data/Source/CVRPStats_20170418/CVRPStats.xlsx", clear firstrow
	tostring CensusTract , format(%12.0f) generate(tract)
	tostring ZIP, generate(OwnerZipCode)
	keep tract DACCensusTractFlag DACZIPCodeFlag OwnerZipCode 
	duplicates drop

	merge 1:1 OwnerZipCode tract using `zipmap' , nogen
	

	//fill in the DAC flags for zip codes that we know
	tempvar zipflag
	bysort OwnerZipCode : egen `zipflag' = mean(DACZIPCodeFlag )
	replace DACZIPCodeFlag = `zipflag' if missing(DACZIPCodeFlag)
	assert inlist( DACZIPCodeFlag, 1 , 0, .)

	//fill in the DAC flags for tracts that we know
	tempvar tractflag
	bysort tract : egen `tractflag' = mean(DACCensusTractFlag )
	replace DACCensusTractFlag = `tractflag' if missing(DACCensusTractFlag)
	assert inlist( DACCensusTractFlag, 1 , 0, .)

	tempfile preCES
	save `preCES'
	
	import excel using "${Data}/Disdvantaged Community designation in CA (related to EFMP)/CalEnviroScreen2_Scores_Full_Oct_2014.xlsx", clear firstrow
	rename ZIP CESZip
	tostring CensusTract , format(%12.0f) generate(tract)
	keep CESZip tract CES20Score 

	merge 1:m tract using `preCES'
	
	tempfile CES_data
	save `CES_data'
	//Cut to zip-code level max CES
	destring CES20Score , replace ignore("`ignore_chars'")
	keep if !missing(CES20Score )
	collapse (max) MaxCES = CES20Score , by(OwnerZipCode )
	tempfile CES_ZIP
	save `CES_ZIP'

	
	//cut to tract level CES 
	use `CES_data', clear
	destring CES20Score , replace ignore("`ignore_chars'")
	keep if !missing(CES20Score )
	collapse CES20Score , by(tract )
	tempfile CES_tract
	save `CES_tract'
	
restore

//tostring zip code for merge
tostring OwnerZipCode, replace

//merge in CES score at zip level
merge m:1 OwnerZipCode using `CES_ZIP', keep(match) nogen
//merge in CES score at tract level
merge m:1 tract using `CES_tract', keep(match) nogen


//rename model vars to avoid confusion
rename (VehicleModel VehicleMake )(RawModel RawMake )
rename (ConsolidatedModel ConsolidatedMake )(VehicleModel VehicleMake )

//save a version before restricting bandwidth
tempfile full_bandwidth
save `full_bandwidth'
//restrict to "medium" bandwidth
keep if inrange(MaxCES , `RD_Cutoff'-`bandwidth_m',`RD_Cutoff'+`bandwidth_m')

//look to see about pricing data
hist PurchasePrice if New , ///
	title("New Sales") ///
	xtitle("Reported Purchase Price") ///
	ytitle("Density") ///
	name("PriceNew", replace)
	
	
hist PurchasePrice if !New , ///
	title("Used Sales") ///
	xtitle("Reported Purchase Price") ///
	ytitle("Density") ///
	name("PriceUsed", replace)
	
hist PurchasePrice if New & PurchasePrice < 50000, ///
	title("New Sales") ///
	xtitle("Reported Purchase Price") ///
	ytitle("Density") ///
	note("new sales with a reported purchase price below $50,000") ///
	name("PriceNewtrim", replace)
	
	
hist PurchasePrice if !New  & PurchasePrice < 50000, ///
	title("Used Sales") ///
	xtitle("Reported Purchase Price") ///
	ytitle("Density") ///
	note("used sales with a reported purchase price below $50,000") ///
	name("PriceUsedtrim", replace)
	


//graphs for top-10 model sales
foreach model in `topTenModels' {
	di "`model'"
	//sales numbers
	preserve
		keep if VehicleModel == "`model'"
		local simplename = subinstr("`model'", "-", "",.)
		local simplename = subinstr("`simplename'", " ", "",.)
		gen PurchaseMonth = mofd(PurchaseDate)
		format PurchaseMonth %tm
		gen flag = 1
		collapse (count) flag , by(PurchaseMonth VehicleYear)
		graph twoway ///
			(line flag PurchaseMonth if VehicleYear == 2014) ///
			(line flag PurchaseMonth if VehicleYear == 2015) ///
			(line flag PurchaseMonth if VehicleYear == 2016) ///
			, title("new and used `model' sales by month") ///
			ytitle("Number Sold") ///
			xtitle("Month") ///
			legend(order(1 "2014 Model Year" 2 "2015 Model Year" 3 "2016 Model Year")) ///
			name("month_`simplename'_sales", replace)
	restore
	//sales prices
	preserve
		keep if VehicleModel == "`model'"	
		hist PurchasePrice if New , ///
			title("New Sales of `model'") ///
			xtitle("Reported Purchase Price") ///
			ytitle("Density") ///
			name("PriceNew`simplename'", replace)
	
	
		hist PurchasePrice if !New , ///
			title("Used Sales of `model'") ///
			xtitle("Reported Purchase Price") ///
			ytitle("Density") ///
			name("PriceUsed`simplename'", replace)
			
		hist PurchasePrice if New & PurchasePrice < 100000, ///
			title("New Sales of `model' (trimmed)") ///
			xtitle("Reported Purchase Price") ///
			ytitle("Density") ///
			note(" sales with a reported purchase price below $100,000") ///
			name("PriceNew`simplename'trim", replace)
	
	
		hist PurchasePrice if !New & PurchasePrice < 50000, ///
			title("Used Sales of `model' (trimmed)") ///
			xtitle("Reported Purchase Price") ///
			ytitle("Density") ///
			note(" sales with a reported purchase price below $100,000") ///
			name("PriceUsed`simplename'trim", replace)
	restore
	
}


//Density plots
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
			xline(`RD_Cutoff') ///
			note("restricted to `new_used' Zero Emissions Vehicles`restriction'" "Vertical line at DAC Threshold") ///
			name("rd_density_plot`new_used'", replace)	
	restore
}

//zip-code count in each CES bin

preserve
	gen MaxCES_rnd = round(MaxCES )
	keep MaxCES_rnd OwnerZipCode
	duplicates drop
	gen flag = 1
	collapse (count) flag, by(MaxCES_rnd)
	
	graph twoway bar flag MaxCES_rnd , ///
			title("Zip Code Count by Forcing Variable") ///
			xtitle("Highest CES score in Zip") ///
			ytitle("Zip Code Count") ///
			xline(`RD_Cutoff') ///
			name("ZipCountbyCES", replace)		
restore




foreach bandwidth_spec in s m w {
	use `full_bandwidth', clear
	local bw_H = `RD_Cutoff'+`bandwidth_`bandwidth_spec''
	local bw_L = `RD_Cutoff'-`bandwidth_`bandwidth_spec''
	keep if inlist(Replacement_Vehicle_Tech, "`tech_1'") & inrange(MaxCES , `bw_L',`bw_H') & (PurchasePrice > `min_purchase_price' | NewUsedIndicator == "U")
di `"	keep if inlist(Replacement_Vehicle_Tech, "`tech_1'") & inrange(MaxCES , `bw_L',`bw_H') & (PurchasePrice > `min_purchase_price' | NewUsedIndicator == "U")"'
	foreach new_used in New Used {
		preserve
			keep if strpos("`new_used'", NewUsedIndicator)
			di "`new_used'"
			if "`new_used'" == "New" {
				local restriction " with reported sales prices over $8000"
			}
			else {
				local restriction
			}
			binscatter PurchasePrice MaxCES , ///
				rd(`RD_Cutoff')  n(`binNumber') ///
				title("Uncontrolled RD Plot") ///
				ytitle("Average Purchase Price") ///
				xtitle("Highest CES score in Zip") ///
				note("restricted to `new_used' Zero Emissions Vehicles`restriction'") ///
				name("uncontRD`new_used'_bw_`bandwidth_spec'", replace)
			binscatter PurchasePrice MaxCES , ///
				rd(`RD_Cutoff')  n(`binNumber') controls(CES20Score) ///
				title("Controlled RD Plot") ///
				ytitle("Average Purchase Price" "Controlling for tract-level CES") ///
				xtitle("Highest CES score in Zip") ///
				note("restricted to `new_used' Zero Emissions Vehicles`restriction'") ///
				name("contRD`new_used'_bw_`bandwidth_spec'" , replace)
			
	

		restore
	}

}