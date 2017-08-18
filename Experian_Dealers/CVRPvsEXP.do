<<dd_do: qui>>

local year_start 	2011
local year_end		2017
local makes		Volkswagen BMW Chevrolet Fiat Ford Honda Nissan Tesla Toyota

local count_cap  500
//Experian vs CVRP vehicle coverage assessment

//read in model clean-up directory
import delimited using "${ExperianCode}/models_after.csv", clear case(preserve) stringcol(_all) varnames(1)

merge 1:m VehicleModel VehicleMake using  "$WorkingDirs/Tyler/Experian_merged",  assert( match) nogen
replace VehicleMake = ConsolidatedMake 
keep if VehicleGroup == "GROUP 1 - ZEV"
gen flag = 1
generate Year = yofd(PurchaseDate)
collapse (count) car_count_EXP = flag, by(Year OwnerZipCode VehicleMake)
tempfile exp
save `exp'

//read in CVRP
import excel using "${Data}/CVRP Incentives/Data/Source/CVRPStats_20170418/CVRPStats.xlsx", clear firstrow
tostring CensusTract , format(%12.0f) generate(tract)
tostring ZIP, generate(OwnerZipCode)

replace VehicleMake = "Fiat" if VehicleMake == "FIAT"

generate Year = yofd(ApplicationDate)

gen flag = 1

collapse (count) car_count_CVRP = flag, by(Year OwnerZipCode VehicleMake)

merge 1:1 Year OwnerZipCode VehicleMake using `exp'

gen flag = inlist(_merge, 1, 3)
bysort OwnerZipCode: egen flag2 = max(flag)
bysort VehicleMake: egen flag3 = max(flag)
keep if flag2 & flag3
drop flag flag2 flag3

foreach source in EXP CVRP {
	replace  car_count_`source' = 0 if missing( car_count_`source')
}

gen flag = 1
collapse (count) cell_size = flag , by(car_count_EXP car_count_CVRP Year VehicleMake)

label variable car_count_EXP "EXP"

gen identity_line = car_count_EXP



//generate graphs
local year_start 	2012
local year_end		2017

forvalues y = `year_start'/`year_end' {
	foreach make of local makes {
		count if VehicleMake == "`make'" & Year == `y'
		if r(N) > 0 {
			graph twoway ///
				(scatter car_count_CVRP car_count_EXP [w= cell_size ] ///
					if VehicleMake == "`make'" & Year == `y' & car_count_CVRP < `count_cap' & car_count_EXP < `count_cap', msymbol(circle_hollow)) ///
				(line identity_line car_count_EXP if VehicleMake == "`make'" & Year == `y' & car_count_CVRP < `count_cap' & car_count_EXP < `count_cap') , ///
				xtitle("Number of Experian Records in" "Make/Zip/Year Cell") ///
				ytitle("Number of CVRP Records in" "Make/Zip/Year Cell") ///
				title("California `make' sales/registrations in `y'") ///
				name(`make'_`y', replace)  ///
				legend(off) note("circle size denotes number of zip codes with that number of Experian and CVRP records")
		}
	}
}

drop identity_line
collapse(sum) cell_size, by(car_count_EXP car_count_CVRP VehicleMake)

local makes		Volkswagen BMW Chevrolet Fiat Ford Nissan Tesla Toyota


gen identity_line = car_count_EXP

foreach make of local makes {
	graph twoway ///
		(scatter car_count_CVRP car_count_EXP [w= cell_size ] ///
			if VehicleMake == "`make'" & car_count_CVRP < `count_cap' & car_count_EXP < `count_cap', msymbol(circle_hollow)) ///
		(line identity_line car_count_EXP if VehicleMake == "`make'"  & car_count_CVRP < `count_cap' & car_count_EXP < `count_cap') , ///
		xtitle("Number of Experian Records in" "Make/Zip/Year Cell") ///
		ytitle("Number of CVRP Records in" "Make/Zip/Year Cell") ///
		title("California `make' sales/registrations in all years") ///
		name(`make', replace) ///
		legend(off) note("circle size denotes number of zip codes with that number of Experian and CVRP records")
}




<</dd_do>>

##CVRP Data Limitations

I confirmed looking at the website [https://cleanvehiclerebate.org/eng/rebate-statistics](https://cleanvehiclerebate.org/eng/rebate-statistics)
that the CVRP data includes the Make and PHEV/FCEV/BEV category, but not VIN or specific model.

The Experian data has VIN and model name, but does not always distinguish between the
plug-in and hybred versions of a model. Further, the date of sale is not reported in the
CVRP data.  This makes it difficult to assess exactly what fraction of eligible vehicles 
are recorded in the CVRP data.  

To get insight into the matching of the two data-sets, I counted the number Experian records 
for a ZEV car in each purchase-year/make/zip-code cell, and the number of CVRP
records in each application-year/make/zip-code cell. For some makes, this mapping 
exercise suggests a good match between purchase records and CVRP registrations.  For example:  

 <<dd_graph: graphname(Nissan) saving(Nissan.png) replace height(400) width(500) >>
 <<dd_graph: graphname(Fiat) saving(Fiat.png) replace height(400) width(500) >>
 <<dd_graph: graphname(Volkswagen) saving(Volkswagen.png) replace height(400) width(500) >>


More up-market vehicles show what appears to be solid data, but with a lower rebate application rate:  

 <<dd_graph: graphname(BMW) saving(BMW.png) replace height(400) width(500) >>

or:

 <<dd_graph: graphname(Tesla) saving(Tesla.png) replace height(400) width(500) >>


Finally, makes that sell many hybreds, only some of which are eligible for the CVRP, 
show a low or midling match rate in the data, but I suspect that is because the Experian data
does not distinguish easily between plug-in and non-plug-in hybreds.  
 <<dd_graph: graphname(Toyota_2014) saving(Toyota_2014.png) replace height(400) width(500) >>
 <<dd_graph: graphname(Ford) saving(Ford.png) replace height(400) width(500) >>


Note that some of these graphs cover a single year only because other years appear to be
gross gaps in the data, consistent with us simply not yet having that coverage, or a limit of the CVRP program, rather than 
a long-run data limitation.  For instance:

 <<dd_graph: graphname(Toyota_2016) saving(Toyota_2016.png) replace height(400) width(500) >>











