capture log close
***************************************
** adjacent_disadvantaged_status.do
**
** Flag census tracts bordring other tracts with various properties
**
**	REVISION HISTORY:
**	20170522 - Read text file in as strings instead of doubles+tostring
***************************************
clear all
version 14.2
set more off

global Dropbox "I:\Personal Files\Jim\Dropbox"
global DisComm "$Dropbox/Erich_Dave_Projects/Project_DisadvantagedCommunities"
global MapData "$Dropbox/Erich_Dave_Projects/Data/mapfiles"
global DisStatus "$Dropbox/Erich_Dave_Projects/Data/Disdvantaged Community designation in CA (related to EFMP)"

log using "${DisComm}/Log/adjacent_disadvantaged_status.txt", text replace

**Load the list of census tract adjacency
import delim CensusTractA CensusTractB ///
	using "${MapData}/adjacencyMatrix/CA_census_tracts_2010.txt", ///
	delim(tab) stringcols(1 2)
	

**The associations in this file are reflexive
**So I will just choose CensusTractA as the "source" tract FIPS
rename CensusTractB CensusTract
merge m:1 CensusTract using "${DisComm}/Data/DisadvantagedCensusTracts.dta", ///
	keep(master match) assert(master match) nogen

#delim ;
	collapse 
		(max)
			AdjacentZipDisadvantaged = ZIPCodeHasDisadvantaged
			AdjacentCensusTractDisadvantaged = CensusTractDisadvantaged
		(min)
			AdjacentZipNot = ZIPCodeHasDisadvantaged
			AdjacentCensusTractNot = CensusTractDisadvantaged
		, 
		by(CensusTractA)
	;
#delim cr
rename CensusTractA CensusTract

**The "not" indicators are currently 0 when true. Switch them around
foreach f of varlist AdjacentZipNot AdjacentCensusTractNot {
	replace `f' = !`f' if `f' < .
}

merge 1:1 CensusTract using "${DisComm}/Data/DisadvantagedCensusTracts.dta", ///
	keep(master match) assert(master match) nogen
	
compress

rename ZIPCodeHasDisadvantaged ZipDisadvantaged

label var CensusTract "Census 2010 Census Tract FIPS"
label var AdjacentZipDisadvantaged "True if an adjacent census tract is in a zip code with disdvantaged status"
label var AdjacentCensusTractDisadvantaged "True if an adjacent census tract is disadvantaged status"
label var AdjacentZipNot "True if an adjacent census tract is in a zip code with no disdvantaged status"
label var AdjacentCensusTractNot "True if an adjacent census tract is not disadvantaged status"

**Sort on the likely merge key
sort CensusTract

save "${DisComm}/Data/CensusTractsAdjacentDisadvantagedStatus.dta", replace


	
log close

