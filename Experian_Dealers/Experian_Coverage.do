
<<dd_include: header.txt >>


<<dd_do: quietly >>
	//Set locals  
	local new_dealer_naics 441110

	//Prep Experian Data
	use "$WorkingDirs/Tyler/Experian", clear
	//summary statistics
	count 
	local total_experian_transactions = `r(N)'
	preserve
		keep DealerZipCode DealerName
		duplicates drop
		count 
		local total_experian_dealers = `r(N)'
	restore

	//Filter for genuine new car dealers.
	drop if DealerZipCode == ""
	drop if strpos(DealerName , "UNKNOWN")
	drop if strpos(DealerName , "NAME NOT IDENTIFIED")
	drop if DealerType == "UD"
	keep DealerZipCode DealerName
	duplicates drop

	//Summary statistic:
	count 
	local useable_new_dealers = `r(N)'


	gen flag = 1 
	collapse  (count) ExperienCount = flag , by(DealerZipCode )

	tempfile processedExperian
	save `processedExperian'


	//Process CBP data
	use "$WorkingDirs/Tyler/CBP", clear
	rename zipcode zcta5
	//keep only new car naics
	keep if strpos(naics ,"`new_dealer_naics'")
	//merge in Zipcodes
	joinby zcta5 using "$WorkingDirs/Tyler/zip_xwalk", unmatched(using)
	//restrict to only 50 states+DC
	keep if state <= 51

	rename   zcta5 DealerZipCode
	keep DealerZipCode CBP_establisment_count state
	collapse (first) CBP_establisment_count state , by(DealerZipCode)
	duplicates drop

	tempfile processedCBP
	save `processedCBP'
	
	//CBP Summary stat
	preserve
		collapse (sum) CBP_establisment_count
		local CBP_total_dealers = CBP_establisment_count[1]
	restore

	//Combine Datasets
	merge 1:m DealerZipCode using `processedExperian'

	//Interpert missing zip codes as having zero establishments
	replace CBP_establisment_count = 0 if missing(CBP_establisment_count )
	replace ExperienCount = 0 if missing(ExperienCount )

	destring DealerZipCode , replace

	//Save regression coefficients
	regress CBP E
	local C_E_Beta_zeros = _b[ExperienCount]
	local C_E_cons_zeros = _b[_cons]

	regress E CBP
	local E_C_Beta_zeros = _b[CBP_establisment_count]
	local E_C_cons_zeros = _b[_cons]

	regress CBP E if CBP_establisment_count + ExperienCount != 0
	local C_E_Beta = _b[ExperienCount]
	local C_E_cons = _b[_cons]

	regress E CBP if CBP_establisment_count + ExperienCount != 0
	local E_C_Beta = _b[CBP_establisment_count]
	local E_C_cons = _b[_cons]

	//Scatter plot
	preserve
		collapse (count) DealerZipCode, by(CBP_establisment_count ExperienCount)

		scatter ExperienCount CBP_establisment_count [weight = DealerZipCode] ///
		if CBP_establisment_count + ExperienCount != 0,  ///
		xtitle("CBP Establishment Count") ytitle("Experian Establishment Count") ///
		title("Establishment Counts") msymbol(oh) ///
		note("circle size indicates number of zip codes") name(EstCounts_no_zero, replace)

	restore


	***Summary Statistics****

	count if CBP_establisment_count > ExperienCount 
	local CBP_Greater = `r(N)'
	count if CBP_establisment_count == ExperienCount & ExperienCount != 0 
	local CBP_Equal = `r(N)'
	count if CBP_establisment_count < ExperienCount
	local CBP_less = `r(N)'

	local zip_count = `CBP_less' + `CBP_Equal' + `CBP_Greater'
<</dd_do>>

#Establishment coverage
Notes on the dealership coverage within Experian provided data, as compared to County Business Patterns data.

Prepared by Tyler Hoppenfeld

##Executive Summary
###Definition of "Establishment"
The definition of an establishment in the Experian and the County Business Patterns (CBP) data is consistant, as a single company doing business at a single location. 

###Summary statistics
The Experian provided data covers exactly <<dd_display: %12.0gc `total_experian_transactions'>> transcations, accounting for <<dd_display: %12.0gc `total_experian_dealers'>>  dealers, of which  <<dd_display: %12.0gc `useable_new_dealers'>> appear to be real new-car dealerships with a well-defined zipcode.

In the CBP data, there are  <<dd_display: %12.0gc `CBP_total_dealers'>> establishments with a naics code corresponding to a new car dealership.

###Analysis
At face value, it appears that the Experian data is quite incomplete.  It includes a fraction of the number of new car dealers that are included in the CBP data, dispite the fact that they use the same definition of an establishment. The experian data also includes only a fraction of the total new car sales in the United States. It appears that there are few dealers in the Experian data not found in the CBP data.  Only 10% of zip codes more dealers in the Experian data than in the CBP data, and a regression analysis suggests that each dealer in the Experian data has a counterpart in the CBP data.  A visual inspection of a weighted scatter plot of zipcodes confirms the impression that the Experian dealers are a strict subset of the CBP dealers.


##Detailed Analysis
### Definition of "Establishment"
The CBP data is drawn from a variety of government administered surveys:

>CBP data are extracted from the Business Register, the Census Bureau's file of all known single and multi-establishment companies. Data comes from a variety of sources, including the Economic Census, the Annual Survey of Manufactures, and Current Business Surveys, as well as from administrative records of the Internal Revenue Service (IRS)   [CBP Data User Guide](https//www2.census.gov/programs-surveys/cbp/resources/2015_CBP_DataUserGuide.pdf)

In the [Equal Opportuinty Survey](https://www1.eeoc.gov//employers/eeo1survey/faq.cfm?renderforprint=1#MECompanies), which I take to be representative of the surveys underlying the CBP data, an establishment is defined as a company conducting business in a place.  If a dealership has multiple addresses, each address counts as its own establishment.  Likewise, if two companies share an address, they are each a separate establishment.

In the Experian data, name variations are generally not misspellings or alternate names, but substatatively different.  For instance, if there is a dealership called "Elk Game Buick Pontiac GMC" we can expect to also find one named "Elk Game Dodge DBA Chrysler Jeep", but not also called "Elk Game Buick."  Furthermore, it appears that each unique dealer name is associated with a unique address. This rule is not strictly adhered to, but it appears that the general guideline is consistent with the "establishment" definition used by the CBP, and the deviations from this rule are few enough that I don't believe they drive the results discussed below.

###Summary Statistics

The Experian provided data covers exactly <<dd_display: %12.0gc `total_experian_transactions'>> transcations. There are <<dd_display: %12.0gc `total_experian_dealers'>> unique dealers, defined as a unique name-zip code pair.  As discussed above, in most cases  unique dealer name reflecta a unique establishment.
After excluding all used car dealers, as well as the dealers with no valid zipcode or with a name containing the string "UNKNOWN" or "NAME NOT IDENTIFIED" I identified  <<dd_display: %12.0gc `useable_new_dealers'>> establishments that appear to be real new-car dealerships with a well-defined zipcode.

In the CBP data,  there are  <<dd_display: %12.0gc `CBP_total_dealers'>> establishments with a naics code corresponding to a new car dealership.


The majority of zipcodes have as many or more dealers in the CBP data as in the Experian data:


|Category of Zip Code|Number |Fraction|Cumulative fraction|
|:----------------|----------------------------------------:|-------:|--------------:|
|More CBP Dealers|   <<dd_display: %12.0gc `CBP_Greater'>>  |    <<dd_display: %4.2f `CBP_Greater'/`zip_count'>> |    <<dd_display: %4.2f `CBP_Greater'/`zip_count'>>    | 
|CBP == Experian |<<dd_display: %12.0gc  `CBP_Equal'>> | <<dd_display: %4.2f ( `CBP_Equal')/`zip_count'>>| <<dd_display: %4.2f (`CBP_Greater' + `CBP_Equal')/`zip_count'>> |
|More Experian   |<<dd_display: %12.0gc `CBP_less'>>    			  |<<dd_display: %4.2f `CBP_less'/`zip_count'>>  | <<dd_display: %4.2f (`CBP_Greater' + `CBP_Equal'+`CBP_less')/`zip_count'>> |

### Visual Analysis

A bit more detail is visible in this plot of the relationship between the number of dealers recorded by CBP and the number of dealers recorded by Experian, at the zipcode level.

<<dd_graph: graphname(EstCounts_no_zero) saving(EstCounts_no_zero.png) replace>>

As you can see, zip codes mostly fall below the 1:1 line, indicating that generally speaking more dealerships appear in the CBP data than in the Experian data.



###Regression Analysis

To approach from a slightly different direction, I estimated:

(1) ExperienCount =   <<dd_display: %4.2f `E_C_Beta'>>  \\( \cdot \\)  CBP_establisment_count    <<dd_display: %4.2f `E_C_cons'>>  +  \\( \epsilon \\)  
(2) CBP_establisment_count =  <<dd_display: %4.2f `C_E_Beta'>>  \\( \cdot \\)  ExperienCount   +    <<dd_display: %4.2f `C_E_cons'>> +  \\( \epsilon \\)

 Note that this dataset excludes zip codes where neither Experian nor CBP observe a dealer. To account for these zero-zero zipcodes, I used the zipcode relationship file from the 2010 census.  Adding  these zipcodes, I estimate:

(3) ExperienCount =   <<dd_display: %4.2f `E_C_Beta_zeros'>> \\( \cdot \\)  CBP_establisment_count    <<dd_display: %4.2f `E_C_cons_zeros'>>  +  \\( \epsilon \\)  
(4) CBP_establisment_count =  <<dd_display: %4.2f `C_E_Beta_zeros'>>  \\( \cdot \\) ExperienCount   +    <<dd_display: %4.2f `C_E_cons_zeros'>> + \\( \epsilon \\)

######(Note, for all estimates, coefficients are +- .03 or less)

While we cannot know with certianty what is happening here, it would appear that each dealer in the Experian data has a counterpart in the CBP data (the coefficient of <<dd_display: %4.2f `C_E_Beta_zeros'>>  in equation 4 ), but each dealer in the CBP data has about a 50-50 chance of having a corresponding value in the Experian data (the coefficient of  <<dd_display: %4.2f `E_C_Beta_zeros'>> in equation 3).

The suspicion that the Experian data is a subsample of the CBP data is further bolstered by the small total number of transactions.  For comparison, [Ford alone sold](http://shareholder.ford.com/~/media/Files/F/Ford-IR/events-and-presentations/2017/07-03-17-June-Sales/ford-china-sales.pdf) aproximately 100,000 cars in June 2017, as compared the <<dd_display: %12.0gc `total_experian_transactions'>> used and new transactions reported in the Experian data over a period of several years.





