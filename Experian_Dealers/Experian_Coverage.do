
<<dd_include: header.txt >>


<<dd_do: qui >>
	pause on
	//Set locals  
	local DealerMakes CHEVROLET NISSAN FORD  TOYOTA HONDA 
	local FORD_first_letters "A", "B", "C"
	local TOYOTA_first_letters "A", "B", "C"
	local HONDA_first_letters "A", "B", "C"
	local NISSAN_first_letters  "A", "B", "C"
	local CHEVROLET_first_letters  "A", "B", "C"
	local fake_FORD_dealers "WEATHERFORD BMW"
	local fake_TOYOTA_dealers

	//Loop over Makes:
	foreach make in `DealerMakes' {
		//Prep Experian Data
		use "$WorkingDirs/Tyler/Experian", clear

		//Filter for genuine new car dealers.
		drop if DealerZipCode == ""
		drop if strpos(DealerName , "UNKNOWN")
		drop if strpos(DealerName , "NAME NOT IDENTIFIED")
		drop if DealerType == "UD"
	
		preserve
			//summary statistics
			keep DealerZipCode DealerName DealerCity DealerState 
			duplicates drop
			keep if strpos(DealerName, "`make'") 	& !inlist(DealerName, "`fake_`make'_dealers'")
			count
			local `make'Dealers = `r(N)'
			bysort DealerZipCode: gen flag = (_n == 1)
			count if flag == 1
			local `make'DealerZips = `r(N)'
		
			keep if inlist(substr(DealerCity, 1, 1), "``make'_first_letters'") & DealerState == "CA"

			tempfile before_manual_dedup
			save `before_manual_dedup', replace
		
			//Export for manual de-duplication
			generate duplicate = .
			sort DealerZipCode DealerName
			order duplicate
			export delimited using "${WorkingDirs}/Tyler/`make'_Experian_before.csv", replace		
			save "$WorkingDirs/Tyler/temp", replace
			//merge in de-duplicated work
			import delimited using "${ExperianCode}/`make'_Experian_after.csv", clear case(preserve) stringcol(_all)
			destring duplicate, replace
			merge 1:1 DealerName DealerZipCode using `before_manual_dedup', assert(match) nogen
			keep if duplicate != 1
			drop duplicate
		
		
			count 
			local Filtered`make'Dealers = `r(N)'
			//save Ford dealerships
			tempfile `make'DealersList
			save ``make'DealersList'
		restore


		//Bring in Dealer List 

		import delimited using "${ExperianCode}/DealerList.csv", clear case(preserve) stringcols(_all)
		rename DealerName DealerName_man 
		keep if DealerMake == strproper("`make'")
		keep DealerName DealerZipCode

		//Summary Stat
		count
		local `make'Count_man = `r(N)'
		joinby DealerZipCode using ``make'DealersList', unmatched(both)
		assert inlist(_merge, "only in master data":__MERGE, "only in using data":__MERGE, "both in master and using data":__MERGE)
		

		generate NameMatch = .
		order NameMatch DealerName*

		export delimited using "${WorkingDirs}/Tyler/`make'merge_list_before.csv", replace


		//Bring in hand-categorized dealer list
		import delimited using "${ExperianCode}/`make'merge_list_after.csv", clear case(preserve) stringcols(_all)
		destring NameMatch, replace
		replace NameMatch = 0 if NameMatch != 1
		
		//Check to make sure that there is no zip code with >1 dealer name in BOTH data sets
		// Conceptually this isn't an important restriction, but it makes the code a lot 
		// more straightforward
		bysort DealerZipCode DealerName : gen EXPNameN = _N
		bysort DealerZipCode DealerName_man  : gen manNameN = _N
		assert !(manNameN > 1 & EXPNameN > 1)
		drop manNameN EXPNameN

		//The number of rows here is  *almost* an exact count of the dealers, except for 
		// an edge-case that does not currently exist, but I want to catch it here, since it
		// will inevitably come up
		preserve
			bysort DealerZipCode: egen flag = min(NameMatch != 1 & _merge == "both in master and using data)")
			collapse flag, by(DealerZipCode)
			sum flag
			local dealer_count_correction = `r(sum)'
			di `dealer_count_correction'
		restore

		//joined dealer counts
		local Joined`make'Count = `dealer_count_correction' + _N

		count if NameMatch == 1
		local `make'matched_dealers = `r(N)'

		count if NameMatch != 1 & inlist(_merge , "both in master and using data" , "matched (3)")
		local `make'zip_match_only = `r(N)'

		count if inlist(_merge , "only in using data" ,"using only (2)")
		local `make'_exp_only = `r(N)' + `dealer_count_correction'

		count if inlist(_merge , "only in master data", "master only (1)")
		local `make'_man_only = `r(N)' + `dealer_count_correction'
	}
<</dd_do>>

#Establishment Coverage, V2.1
This document attempts to assess the extent to which the Experian data covers new car dealers. 

Prepared by Tyler Hoppenfeld
##Executive Summery
Outside data sources suggest that there are aproximately twice as many Ford, Toyota, Honda, and Chevrolet dealers as appear in the Experian Data, however a pseudo-random sample of Ford, Toyota, Honda, and Chevrolet dealerships drawn from their websites match very accurately with the Experian data. 

There are an unexpectedly high number of Nissan dealerships in the Experian data, but they also have a good match with the external dealership list.

Transcribing a list of dealerships is labor intensive, and extending this effort to a census of dealerships in California, rather than a sample, will take aproximately 20 additional hours of labor.

##Analysis
###Ford Dealers
####Summary Statistics
The Experian Data includes <<dd_display: %12.0gc `FORDDealers'>> new car dealerships with  "Ford" in the name. A data source, [aggdata.com](https://www.aggdata.com/aggdata/complete-list-ford-motor-company-dealer), reports 3,089 Ford dealers nationally.  They offer a complete list for purchase.

####Data Matchup
However, a convenience sample of <<dd_display: %12.0gc `FORDCount_man'>> Ford dealerships drawn from the Ford [website](http://content.dealerconnection.com/vfs/brands/us/ca_ford_en.html) (all dealers located in a California city starting with the letters A, B, or C), has a much better match with the Experian list.
I matched the zipcodes of those dealerships against the Experian dataset of Ford dealerships in California cities beginning with the letters A, B, or C (<<dd_display: %12.0gc `FilteredFORDDealers'>> dealers, after removing duplicates).  This yielded a combined list of <<dd_display: %12.0gc `JoinedFORDCount'>> dealers.  
  Of these dealerships, <<dd_display: %12.0gc `FORDmatched_dealers'>> had a clear name and zipcode between the two data sets, <<dd_display: %12.0gc `FORDzip_match_only'>> had a corresponding Experian-recorded Ford dealership in the same zip-code, but with a different name, <<dd_display: %12.0gc `FORD_man_only'>> from the Ford website had no corresponding dealership in the Experian data, and <<dd_display: %12.0gc `FORD_exp_only'>> from the Experian data had no match on the Ford website.


###Table Form
Following this pattern, I report a table with the same information for each make where we hope to see most or all dealerships represented in the sample:
  

 Make         |Chevrolet     |Ford| Toyota | Honda| Nissan|
:--------------|-----:|----------:|--------:|------:|-------:|
Experian USA Count |<<dd_display: %12.0gc `CHEVROLETDealers'>>|<<dd_display: %12.0gc `FORDDealers'>>|<<dd_display: %12.0gc `TOYOTADealers'>>|<<dd_display: %12.0gc `HONDADealers'>>|<<dd_display: %12.0gc `NISSANDealers'>>|
USA Count (external)|3,000|3,089|1,233|805|187|
*Subsamples*:||||||
**True Count** |<<dd_display: %12.0gc `CHEVROLETCount_man'>>|<<dd_display: %12.0gc `FORDCount_man'>>|<<dd_display: %12.0gc `TOYOTACount_man'>>|<<dd_display: %12.0gc `HONDACount_man'>>|<<dd_display: %12.0gc `NISSANCount_man'>>|
**Matched**|<<dd_display: %12.0gc `CHEVROLETmatched_dealers'>>|<<dd_display: %12.0gc `FORDmatched_dealers'>>|<<dd_display: %12.0gc `TOYOTAmatched_dealers'>>|<<dd_display: %12.0gc `HONDAmatched_dealers'>>|<<dd_display: %12.0gc `NISSANmatched_dealers'>>|
Experian Count|<<dd_display: %12.0gc `FilteredCHEVROLETDealers'>>|<<dd_display: %12.0gc `FilteredFORDDealers'>>|<<dd_display: %12.0gc `FilteredTOYOTADealers'>>|<<dd_display: %12.0gc `FilteredHONDADealers'>>|<<dd_display: %12.0gc `FilteredNISSANDealers'>>|
Joined Count|<<dd_display: %12.0gc `JoinedCHEVROLETCount'>>|<<dd_display: %12.0gc `JoinedFORDCount'>>|<<dd_display: %12.0gc `JoinedTOYOTACount'>>|<<dd_display: %12.0gc `JoinedHONDACount'>>|<<dd_display: %12.0gc `JoinedNISSANCount'>>|
Zip Match|<<dd_display: %12.0gc `CHEVROLETzip_match_only'>>|<<dd_display: %12.0gc `FORDzip_match_only'>>|<<dd_display: %12.0gc `TOYOTAzip_match_only'>>|<<dd_display: %12.0gc `HONDAzip_match_only'>>|<<dd_display: %12.0gc `NISSANzip_match_only'>>|
Experian Only|<<dd_display: %12.0gc `CHEVROLET_exp_only'>>|<<dd_display: %12.0gc `FORD_exp_only'>>|<<dd_display: %12.0gc `TOYOTA_exp_only'>>|<<dd_display: %12.0gc `HONDA_exp_only'>>|<<dd_display: %12.0gc `NISSAN_exp_only'>>|
Outside List Only|<<dd_display: %12.0gc `CHEVROLET_man_only'>> |<<dd_display: %12.0gc `FORD_man_only'>>|<<dd_display: %12.0gc `TOYOTA_man_only'>>|<<dd_display: %12.0gc `HONDA_man_only'>>|<<dd_display: %12.0gc `NISSAN_man_only'>>|
Outside Dealer List |[Autospies.com](http://www.autospies.com/dealers/Chevrolet/California/)|[Ford website](http://content.dealerconnection.com/vfs/brands/us/ca_ford_en.html)|[Toyota website](https://www.toyota.com/dealers/California/all-city/)|[Autospies.com](http://www.autospies.com/dealers/Honda/California/)|[Autospies.com](http://www.autospies.com/dealers/Nissan/California/)|
External count source| [CNN](http://money.cnn.com/2009/05/15/news/companies/gm_dealers/?postversion=2009051509)|[aggdata](https://www.aggdata.com/aggdata/complete-list-ford-motor-company-dealer)|[Toyota](https://www.toyota.com/about/images/operations/numbers/TMOB0166_2013_LARGE_BROCHURE_WEB_USE_tiled2.pdf)|[Wikipedia](https://en.wikipedia.org/wiki/American_Honda_Motor_Company)|[Nissan](https://en.wikipedia.org/wiki/American_Nissan_Motor_Company)|

 Note that for Toytoa, a distinctive and similar name appears in both the "Experian Only" and the "Website Only" set of dealers, suggesting a zip-code entry error, or a dealership that has moved.  If this is the case, the Toyota sample would 24 of 25 dealers matched.
 
##Discussion
It is strange that, with the exception of Nissan, externally available dealership counts suggest that the Experian coverage is only about 50%, however a semi-random sample of dealerships in the state shows that the Experian coverage is quite complete for California. I do not quite know what to make of this, except to suggest that perhaps the dealership counts in the outside sources are inflated, or the dealership coverage in the Experian data is much weaker outside of California.

The situation is odd with Nissan--there are many dealerships of different names in the same zip code, and often at similar address.  In many cases this is clearly slopy record keeping (eg. "Lynn's Nissan" vs "Lynns Nissan"), but in many cases the names are distinct.  

I have stopped here because listing dealers from their website is a time consuming process and I want to give you a chance to assess whether this is the right track. For a published paper we would compile a complete list of California Dealerships, as opposed to a list of those dealerships located in cities beginning with the letters A, B, or C.  

I estimate that extending to cover all California dealers would then take an additional 20 hours of work.  