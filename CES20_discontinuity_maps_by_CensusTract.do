capture log close
***************************************
** CES20_discontinuity_maps.do
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

log using "${DisComm}/Log/CES20_discontinuity_maps.txt", text replace

***********************************
** The code here converts a Census TIGER file 
** for California census tracts into a Stata dataset.
** You only need to run this code once.
***********************************
/*shp2dta using "I:\Personal Files\Jim\Research\data\Geography\GIS Shapefiles\US Census Tracts\2010\CA\tl_2010_06_tract10", ///
	database("${DisComm}/Data/CA_CensusTract_db") coord("${DisComm}/Data/CA_CensusTract_coord") genid(ID) replace

shp2dta using "I:\Personal Files\Jim\Research\data\Geography\GIS Shapefiles\US Postal Zip Codes\ERSI Shapefiles\CA\CA_ZIP_Codes", ///
	database("${DisComm}/Data/CA_ZipCode_db") coord("${DisComm}/Data/CA_ZipCode_coord") genid(ID) replace
*/	

use "${DisComm}/Data/CensusTractsAdjacentDisadvantagedStatus.dta", clear
**Merge in geoIDs for mapping. The Tract FIPS were read in with the State FIPS
**at the start reading "6". We need to prepend a zero to match the "06" in the 
**geodata database
gen GEOID10 = "0" + CensusTract
merge 1:1 GEOID10 using "${DisComm}/Data/CA_CensusTract_db", ///
	keep(master match) assert(match using) keepusing(ID INTPTLAT10 INTPTLON10) nogen

**Keep the centroid lat/longs too. It will make it easy to filter 
**maps by location
rename (INTPTLAT10 INTPTLON10) (CensusTractCentroidLat CensusTractCentroidLon)
destring CensusTractCentroid*, replace

**Generate a variable that indicates the treatement typd of the census tract
label define BorderDiscontinuity 1 "Disdva." 2 "Not Disadv." 3 "Border/Disadv." 4 "Border/Not Disadv."
gen byte BorderDiscontinuity:BorderDiscontinuity = cond(CensusTractDisadvantaged==1,1,2) if CensusTractDisadvantaged < .
replace BorderDiscontinuity = 3 if AdjacentCensusTractNot == 1 & CensusTractDisadvantaged == 1
replace BorderDiscontinuity = 4 if AdjacentCensusTractDisadvantaged == 1 & CensusTractDisadvantaged == 0


************************
** Maps
************************
**Why do I graph export PNGs? 
**These maps have complicated geometries and vector graphics versions would be giant and will 
**load slowly in the resulting PDF/TeX files. Consider making PDFs for publication
**Or, better yet, load the final data into GIS software to make really pretty maps. 
**All CA
spmap BorderDiscontinuity using "${DisComm}/Data/CA_CensusTract_coord" ///
	, ///
	id(ID) clmethod(unique) clbreaks(1 2 3 4 ) ///
	fcolor(blue*.2 orange*.2 blue orange) ndfcolor(white)
graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/Border_Discontinuity/CensusTract_All_CA.png", replace
	
**Los Angeles
spmap BorderDiscontinuity using "${DisComm}/Data/CA_CensusTract_coord" ///
	if inrange(CensusTractCentroidLat,33.5,34.5) & ///
	   inrange(CensusTractCentroidLon,-119,-117) ///
	, ///
	id(ID) clmethod(unique) clbreaks(1 2 3 4 ) ///
	fcolor(blue*.2 orange*.2 blue orange) ndfcolor(white)
graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/Border_Discontinuity/CensusTract_Los_Angeles.png", replace
	
**SF/Bay Area
spmap BorderDiscontinuity using "${DisComm}/Data/CA_CensusTract_coord" ///
	if inrange(CensusTractCentroidLat,37,38.25) & ///
	   inrange(CensusTractCentroidLon,-123,-121.5) ///
	, ///
	id(ID) clmethod(unique) clbreaks(1 2 3 4 ) ///
	fcolor(blue*.2 orange*.2 blue orange) ndfcolor(white)
graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/Border_Discontinuity/CensusTract_SF_Bay_Area.png", replace	

**Sacramento
spmap BorderDiscontinuity using "${DisComm}/Data/CA_CensusTract_coord" ///
	if inrange(CensusTractCentroidLat,38.38,38.72) & ///
	   inrange(CensusTractCentroidLon,-121.6,-121.1) ///
	, ///
	id(ID) clmethod(unique) clbreaks(1 2 3 4 ) ///
	fcolor(blue*.2 orange*.2 blue orange) ndfcolor(white)
graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/Border_Discontinuity/CensusTract_Sacramento.png", replace	


/***********************************************
***********************************************
***********************************************
** Now do everything again for zip codes
***********************************************
***********************************************
***********************************************
merge 1:m CensusTract using "${DisComm}/Data/CensusTractsToZipCodes.dta", keep(master match) nogen

#delim ;
	collapse 
		(max) 
			AdjacentZipDisadvantaged AdjacentZipNot ZipDisadvantaged
			MaxLat = CensusTractCentroidLat 
			MaxLon = CensusTractCentroidLon
		(min)
			MinLat = CensusTractCentroidLat 
			MinLon = CensusTractCentroidLon
		, 
		by(ZipCode)
	;
#delim cr
drop if ZipCode == . | ZipCode < 1000


**Merge in geoIDs for mapping. The Tract FIPS were read in with the State FIPS
**at the start reading "6". We need to prepend a zero to match the "06" in the 
**geodata database
gen ZIP_CODE = string(ZipCode)
merge 1:1 ZIP_CODE using "${DisComm}/Data/CA_ZipCode_db", ///
	keep(master match) assert(match using) keepusing(ID) 


**Generate a variable that indicates the treatement typd of the census tract
*label define BorderDiscontinuity 1 "Disdva." 2 "Not Disadv." 3 "Border/Disadv." 4 "Border/Not Disadv."
gen byte BorderDiscontinuity:BorderDiscontinuity = cond(ZipDisadvantaged==1,1,2) if ZipDisadvantaged < .
replace BorderDiscontinuity = 3 if AdjacentZipNot == 1 & ZipDisadvantaged == 1
replace BorderDiscontinuity = 4 if AdjacentZipDisadvantaged == 1 & ZipDisadvantaged == 0

spmap BorderDiscontinuity using "${DisComm}/Data/CA_ZipCode_coord" ///
	, ///
	id(ID) clmethod(unique) clbreaks(1 2 3 4 ) ///
	fcolor(blue*.2 orange*.2 blue orange) ndfcolor(white)
graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/Border_Discontinuity/ZipCode_All_CA.png", replace


**Los Angeles
spmap BorderDiscontinuity using "${DisComm}/Data/CA_CensusTract_coord" ///
	if MinLat >= 33.5 & MaxLat <= 34.5 & ///
	   MinLon >= -119 & MaxLon <= -117 ///
	   & !missing(MinLat,MinLon,MaxLat,MaxLon) ///
	, ///
	id(ID) clmethod(unique) clbreaks(1 2 3 4 ) ///
	fcolor(blue*.2 orange*.2 blue orange) ndfcolor(white)
graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/Border_Discontinuity/ZipCode_Los_Angeles.png", replace
	
**SF/Bay Area
spmap BorderDiscontinuity using "${DisComm}/Data/CA_CensusTract_coord" ///
	if inrange(CensusTractCentroidLat,37,38.25) & ///
	   inrange(CensusTractCentroidLon,-123,-121.5) ///
	, ///
	id(ID) clmethod(unique) clbreaks(1 2 3 4 ) ///
	fcolor(blue*.2 orange*.2 blue orange) ndfcolor(white)
graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/Border_Discontinuity/ZipCode_SF_Bay_Area.png", replace	

**Sacramento
spmap BorderDiscontinuity using "${DisComm}/Data/CA_CensusTract_coord" ///
	if inrange(CensusTractCentroidLat,38.38,38.72) & ///
	   inrange(CensusTractCentroidLon,-121.6,-121.1) ///
	, ///
	id(ID) clmethod(unique) clbreaks(1 2 3 4 ) ///
	fcolor(blue*.2 orange*.2 blue orange) ndfcolor(white)
graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/Border_Discontinuity/ZipCode_Sacramento.png", replace
*/

******************************************
** Maps showing 70th-75th percentile and 76-80th percentile census tracts
******************************************
**Why are these "backwards"? (Below is 2) 
**So it matches the scheme used above where disadvantaged is 2 (and the second color)
label define AboveBelow 2 "Below Threshold (71st-75th Pctile)" 1 "Above Threshold (76th-80th Pctile)"
gen byte AboveBelowThreshold:AboveBelow = .
replace AboveBelowThreshold = 2 if CES20PercentileLB == 71
replace AboveBelowThreshold = 1 if CES20PercentileLB == 76

spmap AboveBelowThreshold using "${DisComm}/Data/CA_CensusTract_coord" ///
	, ///
	id(ID) clmethod(unique) clbreaks(1 2 3) ///
	fcolor(blue orange ) ndfcolor(white)
graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/CES20_Discontinuity/AboveBelow_CensusTract_All_CA.png", replace
	
**Los Angeles
spmap AboveBelowThreshold using "${DisComm}/Data/CA_CensusTract_coord" ///
	if inrange(CensusTractCentroidLat,33.5,34.5) & ///
	   inrange(CensusTractCentroidLon,-119,-117) ///
	, ///
	id(ID) clmethod(unique) clbreaks(1 2 3) ///
	fcolor(blue orange) ndfcolor(white)
graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/CES20_Discontinuity/AboveBelow_CensusTract_Los_Angeles.png", replace
	
**SF/Bay Area
spmap AboveBelowThreshold using "${DisComm}/Data/CA_CensusTract_coord" ///
	if inrange(CensusTractCentroidLat,37,38.25) & ///
	   inrange(CensusTractCentroidLon,-123,-121.5) ///
	, ///
	id(ID) clmethod(unique) clbreaks(1 2 3) ///
	fcolor(blue orange) ndfcolor(white)
graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/CES20_Discontinuity/AboveBelow_CensusTract_SF_Bay_Area.png", replace	

**Sacramento
spmap AboveBelowThreshold using "${DisComm}/Data/CA_CensusTract_coord" ///
	if inrange(CensusTractCentroidLat,38.38,38.72) & ///
	   inrange(CensusTractCentroidLon,-121.6,-121.1) ///
	, ///
	id(ID) clmethod(unique) clbreaks(1 2 3) ///
	fcolor(blue orange) ndfcolor(white)
graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/CES20_Discontinuity/AboveBelow_CensusTract_Sacramento.png", replace


log close



	
	
