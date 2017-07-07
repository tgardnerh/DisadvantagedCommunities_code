capture log close
***************************************
** load_disadvantaged_status.do
**
** Load data that flags census tracts which:
** 1 - Are flagged as disadvantaged status (blue)
** 2 - Are in a zip code with another census tract flagged disadvantaged (yellow)
** 3 - Neither of the above (white)
**
**
**	REVISION HISTORY - 
**		20170418 - File created
**		20170502 - Updated disadvantaged community list to include CalEnviroScore 2.0 values for all
**			Census tracts (disadvantaged or not). Added CES20Score and CES20PercentileLB to 
**			output files.
**		20170522 - Compute highest CES2.0 score for each zip code and assign to containing census tracts
**			Save a file of largest CES2.0 scores by zip code
***************************************
clear all
version 14.2
set more off

global Dropbox "I:\Personal Files\Jim\Dropbox"
global DisComm "$Dropbox/Erich_Dave_Projects/Project_DisadvantagedCommunities"
global MapData "$Dropbox/Erich_Dave_Projects/Data/mapfiles"
global DisStatus "$Dropbox/Erich_Dave_Projects/Data/Disdvantaged Community designation in CA (related to EFMP)"

log using "${DisComm}/Log/load_disadvantaged_status.txt", text replace

**Load the list of census tracts in zip codes
import delim CensusTract ZipCode OverlapArea ///
	using "${MapData}/OverlapMatrix/CA_Census_Tracts_to_ZIP_codes_2010.txt", delim(tab)
	
**You need to convert CensusTract to a string for reliable merges
**Since it will overflow long integers
format %15.0f CensusTract
tostring CensusTract, replace

**Compute portion of each tracts area in each zip code
egen TotalArea = total(OverlapArea), by(CensusTract)
gen AreaPortion = OverlapArea/TotalArea
sum AreaPortion, det

**Drop any overlap that comprises less than 0.5 percent of the area of a tract
drop if AreaPortion < 0.005

**Flag all tracts overlapping multiple zip codes
egen ZipCodeCount = count(ZipCode), by(CensusTract)
gen byte CensusTractHasMultipleZips = ZipCodeCount > 1

egen CensusTractTag = tag(CensusTract)
tab CensusTractHasMultipleZips if CensusTractTag

keep CensusTract ZipCode CensusTractHasMultipleZips CensusTractTag
save "${DisComm}/Data/CensusTractsToZipCodes.dta", replace


**Read in disadvantaged status by census tract
/**These census tracts are all in the top 25 percent of CalEnviroScreen scores
import excel using "${DisStatus}/SB535List.xls", sheet("SB535 All Data") ///
	firstrow clear
***/
**Import CalEnviroScore data. Why allstring? Census tracts IDs will overflow floats
**and lose precision. We want to read them in as strings
import excel using "${DisStatus}/CalEnviroScreen2_Scores_Full_Oct_2014.xlsx", ///
	sheet(CES2.0FinalResults) firstrow allstring clear case(preserve)
	
keep CensusTract CES20Score ZIP CES20PercentileRange
isid CensusTract
rename ZIP ZipCode
destring ZipCode, replace

**Replace NA scores with zero then destring
replace CES20Score = "." if CES20Score == "NA"
destring CES20Score, replace

*************************
** Max CES Score by Zip Code
************************
**Determine the max CES2.0 score in each zip code
**Then map that back to each census tract in that zip
preserve
	drop if missing(ZipCode)
	collapse (max) ZipMaxCES20Score = CES20Score, by(ZipCode)
	label var ZipMaxCES20Score "Largest CES 2.0 score in the zip code containing this geography"
	**Save the file for postarity
	save "${DisComm}/Data/MaxCES20Score_byZIP.dta", replace
restore
merge m:1 ZipCode using "${DisComm}/Data/MaxCES20Score_byZIP.dta", keep(master match) assert(match) nogen

*replace CES20PercentileRange = regexs(1) if regexm(CES20PercentileRange, "([0-9]+-[0-9]+\%)")
**extract the lower part of the percentile range. Each bin covers 5 percentage points
gen CES20PercentileLB = real(regexs(1)) if regexm(CES20PercentileRange, "([0-9]+)-[0-9]+\%")
assert CES20PercentileLB < . if CES20PercentileRange != "NA"
gen CensusTractDisadvantaged = CES20PercentileLB >= 75 if CES20PercentileLB < .

drop CES20PercentileRange

**Create a dataset of zip codes with disadvantaged census tracts
preserve
	keep if CensusTractDisadvantaged == 1
	contract ZipCode
	drop _freq
	gen byte ZIPCodeHasDisadvantaged = 1
	save "${DisComm}/Data/ZipCodesWithDisadvantaged.dta", replace
restore

**Add in any census tracts that were left out of the CES spreadsheet
merge 1:m CensusTract using  "${DisComm}/Data/CensusTractsToZipCodes.dta", nogen
*replace CensusTractDisadvantaged = 0 if CensusTractDisadvantaged == .
tab CensusTractDisadvantaged, mis

**Merge in zip code disadvantaged status
merge m:1 ZipCode using "${DisComm}/Data/ZipCodesWithDisadvantaged.dta", keep(master match) nogen
replace ZIPCodeHasDisadvantaged = 0 if ZIPCodeHasDisadvantaged == .

**As a result of the above merges, we may have multiple entries for a census tract
**We want data unique on CensusTract
#delim ;
	collapse 
		(max) 
			ZIPCodeHasDisadvantaged 
			CensusTractDisadvantaged 
			CensusTractHasMultipleZips
			ZipMaxCES20Score
		(firstnm)
			CES20Score
			CES20PercentileLB
			ZipCode
		, 
		by(CensusTract)
	;
#delim cr

**Load the AQMD associated with each census tract
**You need to prepend a zero to the CensusTract to make it a valid FIPS
**I just zero left pad to 12 characters to be safe
replace CensusTract = substr("0"*11,1,11-length(CensusTract)) + CensusTract
merge 1:1 CensusTract using "${MapData}/Air Quality Districts/CensusTract_to_AQMD_map.dta", ///
	keep(master match) nogen

label var CensusTract "Census 2010 Census Tract FIPS"
label var ZIPCodeHasDisadvantaged "True if a ZIP code overlapping tract contains a disadvantaged tract"
label var CensusTractDisadvantaged "True if census tract is disadvantaged"
label var CensusTractHasMultipleZips "True if census tract overlaps multiple ZIP codes"
label var CES20Score "CalEnviroScore 2.0 value, October 2014"
label var CES20PercentileLB "CalEnviroScore 2.0 Percentile range lower bound (+4 for upper bound)"
compress

save "${DisComm}/Data/DisadvantagedCensusTracts.dta", replace
	
	
	
log close

	
