capture log close
***************************************
** CES20_discontinuity_maps.do
**
** Create some summary stats of rebates across the CES20 percentile discontinuity
**
***************************************
clear 
version 14.2


log using "${DisComm}/Log/CES20_discontinuity_maps_by_Zip.txt", text replace

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
**Merge in geoIDs for mapping. 
gen GEOID10 = CensusTract
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

******************************************
** Maps showing 70th-75th percentile and 76-80th percentile census tracts
******************************************
**Why are these "backwards"? (Below is 2) 
**So it matches the scheme used above where disadvantaged is 2 (and the second color)
label define AboveBelow 2 "Below Threshold (71st-75th Pctile)" 1 "Above Threshold (76th-80th Pctile)"
gen byte AboveBelowThreshold:AboveBelow = .

qui sum CES20Score if CES20PercentileLB == 71
replace AboveBelowThreshold = 2 if inrange(ZipMaxCES20Score,r(min),r(max))

qui sum CES20Score if CES20PercentileLB == 76
replace AboveBelowThreshold = 1 if inrange(ZipMaxCES20Score,r(min),r(max))

spmap AboveBelowThreshold using "${DisComm}/Data/CA_CensusTract_coord" ///
	, ///
	id(ID) clmethod(unique) clbreaks(1 2 3) ///
	fcolor(blue orange ) ndfcolor(white)
graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/CES20_Discontinuity_by_Zip/AboveBelow_CensusTract_All_CA.png", replace
	
**San Joaquin Valley
spmap AboveBelowThreshold using "${DisComm}/Data/CA_CensusTract_coord" ///
	if AQMD_ID == 24 /*inrange(CensusTractCentroidLat,33.5,34.5) & ///
	   inrange(CensusTractCentroidLon,-119,-117) */ ///
	, ///
	id(ID) clmethod(unique) clbreaks(1 2 3) ///
	fcolor(blue orange) ndfcolor(white)
graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/CES20_Discontinuity_by_Zip/AboveBelow_Zip_Code_SanJoaqinValley.png", replace
	
**SCAQMD
spmap AboveBelowThreshold using "${DisComm}/Data/CA_CensusTract_coord" ///
	if AQMD_ID == 38 /*inrange(CensusTractCentroidLat,33.5,34.5) & ///
	   inrange(CensusTractCentroidLon,-119,-117) */ ///
	, ///
	id(ID) clmethod(unique) clbreaks(1 2 3) ///
	fcolor(blue orange) ndfcolor(white)
graph export "${DisComm}/ResultsOut/${ResultsVersion}/Graphs/CES20_Discontinuity_by_Zip/AboveBelow_Zip_Code_SCAQMD.png", replace	



log close



	
	
