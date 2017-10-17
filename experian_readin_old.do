capture log close
********************************************
** experian_readin.do
**
** Load Experian Data from text files
**
**	REVISION HISTORY
**	20160815 - Copied from code in Project_Experian/Code
**		Modified code to repair records flagged as "readin_error"
**		Read in additional characters at the end of each row to collect full ethnicity information
**		Converted PurchaseDate to %td format
**		Added additional error checking during cleaning
**		Data output to Experian folder
**	20170316 - Modified to use replacement Experian data
*********************************************
clear all
version 14.1
set more off

global Dropbox "I:\Personal Files\Jim\Dropbox"
global Experian "$Dropbox/Erich_Dave_Projects/Data/Experian"

log using "$Experian/Log/experian_readin.txt", text replace


#delim ;

infix
	str VIN 1-17
	str PurchasePrice 18-37
	str PurchaseDate 38-45
	str TitleState 46-47
	str ReportingPeriod 48-53
	str VehicleGroup 54-93
	str DealerName 94-193
	str DealerType 194-195
	str DealerAddress 196-295
	str DealerCity 296-345
	str DealerState 346-347
	str DealerZipCode 348-352
	str DealerCounty 353-382
	str VehicleMake 383-422
	str VehicleModel 423-462
	str VehicleBody 463-463
	str VehicleSegment 464-503
	str VehicleYear 504-507
	str OdometerReading 508-517
	str NewUsedIndicator 518-518
	str LeaseIndicator 519-519
	str FleetIndicator 520-520
	str OwnerCity 521-560
	str OwnerZipCode 561-565
	str OwnerLessorCounty 566-605
	str OwnerState 606-607
	str LienholderNameCorrected 608-707
	str Age 708-710
	str Gender 711-711
	str Income 712-719
	str Ethnicity 720-780
	using "$Experian\CARB_FINAL_OUTPUT_HHIncome_V2.txt", clear;

#delim cr


**Destring dates and validate
gen int year = real(substr(PurchaseDate,1,4))
assert year < . if PurchaseDate != ""

gen byte month = real(substr(PurchaseDate,5,2))
assert month < . if PurchaseDate != ""
assert inrange(month, 1, 12)

gen byte day = real(substr(PurchaseDate,7,2))
assert day < . if PurchaseDate != ""
assert inrange(day, 1, 31)

**check that the year-month-day combination is valid
gen int date = mdy(month, day, year), after(PurchaseDate)
assert date < . if !missing(year,month,day)
format date %td
drop PurchaseDate
rename date PurchaseDate


***********************************
** repair records that were read in incorrectly
** For some reason some of the input rows are misaligned and their values cross 
** field boundaries.  The following section flags those records and then repairs
** them.
***********************************
gen byte readin_error = (DealerState == "")
**You can parse out the state and zip code from DealerCounty
replace DealerState = regexs(1) if regexm(DealerCounty, "([A-Z][A-Z])([0-9][0-9][0-9][0-9][0-9])(.+)") & readin_error
replace DealerZipCode = regexs(2) if regexm(DealerCounty, "([A-Z][A-Z])([0-9][0-9][0-9][0-9][0-9])(.+)") & readin_error
replace DealerCounty = regexs(3) if regexm(DealerCounty, "([A-Z][A-Z])([0-9][0-9][0-9][0-9][0-9])(.+)") & readin_error
**Now, part of DealerCounty is over in VehicleMake. Fix that too
**I rely on the fact that all vehicle makes are one word.
**I checked that by hand
replace DealerCounty = DealerCounty + regexs(1) if regexm(VehicleMake, "(.+)  ([A-Z]+)") & readin_error
replace VehicleMake = regexs(2) if regexm(VehicleMake, "(.+)  ([A-Z]+)") & readin_error
replace DealerCounty = trim(DealerCounty)


**Vehicle segement overflows
replace VehicleSegment = VehicleSegment + VehicleYear + OdometerReading if readin_error
replace VehicleBody = substr(VehicleSegment,1,1) if readin_error
replace VehicleSegment = substr(VehicleSegment,2,.) if readin_error

**VehicleYear, OdometerReading, NewUsedIndicator, LeaseIndicator, and FleetIndicator all overflow into Owner City
replace VehicleYear = substr(OwnerCity, 1, 4) if readin_error
replace OdometerReading = substr(OwnerCity, 5, 10) if readin_error
replace NewUsedIndicator = substr(OwnerCity, 15, 1) if readin_error
replace LeaseIndicator = substr(OwnerCity, 16, 1) if readin_error
replace FleetIndicator = substr(OwnerCity, 17, 1) if readin_error
replace OwnerCity = substr(OwnerCity, 18,.) if readin_error

**OwnerLessorCounty also botched on the readin
replace OwnerZipCode = regexs(1) if regexm(OwnerLessorCounty, "([0-9][0-9][0-9][0-9][0-9])(.+)") & readin_error
replace OwnerLessorCounty = regexs(2) if regexm(OwnerLessorCounty, "([0-9][0-9][0-9][0-9][0-9])(.+)") & readin_error
replace OwnerLessorCounty = trim(OwnerLessorCounty + OwnerState) if readin_error
replace OwnerState = substr(LienholderNameCorrected,1,2) if readin_error
replace LienholderNameCorrected = substr(LienholderNameCorrected,3,.) if readin_error

**And finally parse out demos for the readin_error records
gen Overflow = Ethnicity if readin_error
levelsof Ethnicity if !readin_error, local(EthnicityList)
foreach v of local EthnicityList {
	replace Ethnicity = "`v'" if substr(Overflow, -1*length("`v'"), .) == "`v'"
	replace Overflow = subinstr(Overflow, "`v'", "", 1) if substr(Overflow, -1*length("`v'"), .) == "`v'"
}

**Now left-pad Overflow with spaces out to 12 characters
replace Overflow = " " * (12-length(Overflow)) + Overflow if readin_error

**Age is the first three characters
replace Age = substr(Overflow,1,3) if readin_error
**Gender is the next one char
replace Gender = substr(Overflow,4,1) if readin_error
**Then Income contains the following 8 characters
replace Income = substr(Overflow, 5,8) if readin_error


**We've fixed all the mis-read records. Drop the flag
drop readin_error Overflow

*****************************
** Done fixing misread records
*****************************


**destring some vars
destring PurchasePrice VehicleYear OdometerReading Income, replace
**Age=="U" implies unknown. It can be missing. 
destring Age, replace ignore("U")

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

gen byte Fleet = FleetIndicator=="F"
gen byte New = NewUsedIndicator=="N"


compress

sort VIN PurchaseDate
save "$Experian/DataOut/Experian_Data.dta", replace



log close

