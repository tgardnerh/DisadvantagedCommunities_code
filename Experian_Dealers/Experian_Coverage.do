
<<dd_include: header.txt >>


<<dd_do:  quietly>>
	//Set locals  
	local DealerMakes FORD  TOYOTA
	local FORD_first_letters "A", "B", "C"
	local TOYOTA_first_letters "A", "B", "C"
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
		
			keep if inlist(substr(DealerCity, 1, 1), "``make'_first_letters'") & DealerState == "CA"

			tempfile before_manual_dedup
			save `before_manual_dedup', replace
		
			//Export for manual de-duplication
			generate duplicate = .
			sort DealerZipCode DealerName
			order duplicate
			export delimited using "${WorkingDirs}/Tyler/`make'_Experian_before.csv", replace
		
		
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
		merge 1:m DealerZipCode using ``make'DealersList'

		generate NameMatch = .
		order NameMatch DealerName*

		export delimited using "${WorkingDirs}/Tyler/`make'merge_list_before.csv", replace


		//Bring in hand-categorized dealer list
		import delimited using "${ExperianCode}/`make'merge_list_after.csv", clear case(preserve) stringcols(_all)
		destring NameMatch, replace
		//The number of rows here is  *almost* an exact count of the dealers, except for 
		// an edge-case that does not currently exist, but I want to catch it here, since it
		// will inevitably come up
		preserve
			bysort DealerZipCode: egen flag = min(NameMatch != 1 & _merge == "matched (3)")
			collapse flag, by(DealerZipCode)
			sum flag
			local dealer_count_correction = `r(sum)'
		restore

		//joined dealer counts
		local Joined`make'Count = `dealer_count_correction' + _N

		count if NameMatch == 1
		local `make'matched_dealers = `r(N)'

		count if NameMatch != 1 & _merge == "matched (3)"
		local `make'zip_match_only = `r(N)'

		count if _merge == "using only (2)"
		local `make'_exp_only = `r(N)' + `dealer_count_correction'

		count if _merge == "master only (1)"
		local `make'_man_only = `r(N)' + `dealer_count_correction'
	}
<</dd_do>>

#Establishment Coverage, V2.0
This document attempts to assess the extent to which the Experian data covers new car dealers. 

Prepared by Tyler Hoppenfeld
##Executie Summery
Outside data sources suggest that there are aproximately twice as many Ford and Toyota dealers as appear in the Experian Data, however a pseudo-random sample of Ford and Toyota dealerships drawn from their websites match very accurately with the Experian data. 

Transcribing a list of dealerships is labor intensive, and extending this effort to other makes will take aproximately 10 hours of additional effort, and extending this effort to a census of dealerships in California, rather than a sample, will take aproximately 20-30 additional hours of labor.

##Analysis
###Ford Dealers
####Summary Statistics
The Experian Data includes <<dd_display: %12.0gc `FORDDealers'>> new car dealerships with  "Ford" in the name. A data source, [aggdata.com](https://www.aggdata.com/aggdata/complete-list-ford-motor-company-dealer), reports 3,089 Ford dealers nationally.  They offer a complete list for purchase.

####Data Matchup
However, a convenience sample of <<dd_display: %12.0gc `FORDCount_man'>> Ford dealerships drawn from the Ford [website](http://content.dealerconnection.com/vfs/brands/us/ca_ford_en.html) (all dealers located in a California city starting with the letters A, B, or C), has a much better match with the Experian list.
I matched the zipcodes of those dealerships against the Experian dataset of Ford dealerships in California cities beginning with the letters A, B, or C (<<dd_display: %12.0gc `FilteredFORDDealers'>> dealers, after removing duplicates).  This yielded a combined list of <<dd_display: %12.0gc `JoinedFORDCount'>> dealers.  
  Of these dealerships, <<dd_display: %12.0gc `FORDmatched_dealers'>> had a clear name and zipcode match in the Experian data, <<dd_display: %12.0gc `FORDzip_match_only'>> had a corresponding Experian-recorded Ford dealership in the same zip-code, but with a different name, <<dd_display: %12.0gc `FORD_man_only'>> from the Ford website had no corresponding dealership in the Experian data, and <<dd_display: %12.0gc `FORD_exp_only'>> from the Experian data had no match on the Ford website.



###Toyota Dealers
####Summary Statistics
The Experian Data includes <<dd_display: %12.0gc `TOYOTADealers'>> new car dealerships with  "Toyota" in the name. Toyota claims  1,233 dealers nationally as of [December 2012](https://www.toyota.com/about/images/operations/numbers/TMOB0166_2013_LARGE_BROCHURE_WEB_USE_tiled2.pdf).

####Data Matchup
However, a convenience sample of <<dd_display: %12.0gc `TOYOTACount_man'>> Toyota dealerships drawn from the Toyota [website](https://www.toyota.com/dealers/California/all-city/) (all dealers located in a California city starting with the letters A, B, or C), has a much better match with the Experian list.
I matched the zipcodes of those dealerships against the Experian dataset of Toyota dealerships in California cities beginning with the letters A, B, or C (<<dd_display: %12.0gc `FilteredTOYOTADealers'>> dealers, after removing duplicates).  This yielded a combined list of <<dd_display: %12.0gc `JoinedTOYOTACount'>> dealers.  
  Of these dealerships, <<dd_display: %12.0gc `TOYOTAmatched_dealers'>> had a clear name and zipcode match in the Experian data, <<dd_display: %12.0gc `TOYOTAzip_match_only'>> had a corresponding Experian-recorded Toyota dealership in the same zip-code, but with a different name, <<dd_display: %12.0gc `TOYOTA_man_only'>> from the Toyota website had no corresponding dealership in the Experian data, and <<dd_display: %12.0gc `TOYOTA_exp_only'>> from the Experian data had no match on the Toyota website.
  
  It is notable that in two cases, a distinctive and similar name appears in both the "Experian Only" and the "Website Only" set of dealers, suggesting a zip-code entry error, or a dealership that has moved.  If this is the case, the Toyota sample would have near perfect coverage in the experian data.


##Discussion
It is strange that, at least in the case of Ford and Toyota, externally available dealership counts suggest that the Experian coverage is only about 50%, however a semi-random sample of dealerships in the state shows that the Experian coverage is quite complete for California. I do not quite know what to make of this, except to suggest that perhaps the dealership counts in the outside sources are inflated, or the dealership coverage in the Experian data is much weaker outside of California.

I have stopped here because listing dealers from their website is a time consuming process and I want to give you a chance to assess whether this is the right track, before I invest the hours to extend this to Chevorle, Nissan, and Honda dealerships.  Additionally, for a published paper, we would of course , compile a complete list of California Dealerships, as opposed to a list of those dealerships located in cities beginning with the letters A, B, or C.  

I estimate that extending to cover the remaining three makes that are heavily represented in the Experian data will take an additional 10 hours, and extending to cover all California dealers would then take an additional 20-30 hours of work.  