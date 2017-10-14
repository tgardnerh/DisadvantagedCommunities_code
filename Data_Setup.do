***Script for data setup


//set locals
include "${DisCommCode}/DefineLocals.do"


//read in experian data
import delimited using "${Data}/Experian/July2017_Experian300k/UCDavis_Output_201601_201704.csv", case(preserve) clear


tostring PurchaseDate, replace
generate date = date(PurchaseDate, "YMD")
format date %td
drop PurchaseDate
rename date PurchaseDate


//append data sets, checking all variables are still there
tostring ReportingPeriod, replace
tostring  DealerZipCode, replace
tostring OwnerZipCode, replace
destring Age, force  replace //This is not kosher for anything but appending datasets to look and see how closely they match
destring Income, replace force // Same


rename ( Model Make Group) (  VehicleModel VehicleMake VehicleGroup)

generate Source = "New Data"

//format variables so append works: 
destring ReportingPeriod OwnerZipCode DealerZipCode , replace

tempfile newData
save `newData'

***Bring in used backfill
 
import delimited using "${Experian}/Sep2017_22kUsedBackfill/UCDavis_Output_20170929.csv", clear case(preserve)
replace Income = "" if Income == "NULL"
destring Income, replace

tostring PurchaseDate, replace
format_date PurchaseDate , format(YMD) replace

//fix varnames
rename (Make Model) (VehicleMake VehicleModel)
//generate backfill flag
generate Source = "Backfill"

**destring some vars

**Age=="U" implies unknown. It can be missing. 
replace Age = "" if Age == "NULL"
destring Age, replace ignore("U")


append using `newData'

**Generate flags
gen LeaseDum = LeaseIndicator=="L"
egen ever_leased = max(LeaseDum), by(VIN)
tab ever_leased

duplicates tag VIN, gen(times_sold)
replace times_sold = times_sold+1

gen byte CAdummy = DealerState=="CA"
gen byte Hispanic = strpos(Ethnicity,"Hisp")>0 & strpos(Ethnicity,"Non")==0  if Ethnicity~=""
gen byte AfrAmer = strpos(Ethnicity,"Afr")>0 if Ethnicity~=""
gen byte White = strpos(Ethnicity,"Non")>0 if Ethnicity~=""
gen byte Asian = strpos(Ethnicity,"Asi")>0 if Ethnicity~=""
gen byte Other = strpos(Ethnicity,"Oth")>0 if Ethnicity~=""

gen byte no_missing_demo = Ethnicity~="" & Age~=. & Income~=. & Gender~=""

gen byte Male = Gender=="M" if Gender~=""
gen byte Female = Gender=="F" if Gender~=""

gen byte New = NewUsedIndicator=="N"


compress

sort VIN PurchaseDate


****************************
** Fetch precise Vehicle Types
****************************

preserve

	import delimited using "$Data/DataOne/Data/Source/20170516/DataOne_IDP_are_ucb.csv", case(preserve) clear
	keep VIN_PATTERN FUEL_TYPE
	duplicates drop
	bysort VIN_PATTERN: keep if _N == 1
	tempfile VinToFuel
	save `VinToFuel'

	import delimited using "${DisCommCode}/VehicleType_Xwalk.csv", case(preserve) clear varnames(1)
	keep EFMP_Tech_clean FUEL_TYPE
	rename EFMP_Tech_clean Replacement_Vehicle_Tech
	duplicates drop
	tempfile TechXwalk
	save `TechXwalk'
	
restore

gen VIN_PATTERN = substr(VIN, 1, 8)
replace VIN_PATTERN = VIN_PATTERN + substr(VIN, 10, 2)

merge m:1 VIN_PATTERN using `VinToFuel', keep(master match) assert(master match using) nogen

merge m:1 FUEL_TYPE using `TechXwalk',  keep(match) nogen

tempfile experian
save `experian'


***Code starts here***
//read in model clean-up directory
import delimited using "${ExperianCode}/models_after.csv", clear case(preserve) stringcol(_all) varnames(1)

//merge in data
merge 1:m VehicleModel VehicleMake using `experian',  assert( match master) keep(match) nogen

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

save "${WorkingDir}/TransactionData", replace

