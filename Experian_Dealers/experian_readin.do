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
 
import delimited using "$Experian/Sep2017_22kUsedBackfill/UCDavis_Output_20170929.csv", clear case(preserve)
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
	save "$scratch/VinToFuel", replace

	import delimited using "$scratch/VehicleType_Xwalk.csv", case(preserve) clear varnames(1)
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




save "$WorkingDirs/Tyler/Experian", replace
