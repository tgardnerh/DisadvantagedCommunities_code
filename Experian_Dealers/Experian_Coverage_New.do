<<dd_include: header.txt >>


<<dd_do:  >>
//read in experian data
import delimited using "${Data}/Experian/July2017_Experian300k/UCDavis_Output_201601_201704.csv", case(preserve)
/*
//look to see about pricing data
encode model, generate(model_code)
tostring purchasedate, replace
generate date = date(purchasedate, "YMD")
format date %td
drop purchasedate
rename date purchasedate
reg purchaseprice model_code##i.vehicleyear##c.purchasedate if newusedindicator == "U"
*/


local carlist leaf prius volt model

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


rename ( Model) (  VehicleModel)

generate Source = "New Data"
append using "$WorkingDirs/Tyler/Experian"
replace Source = "Old Data" if missing(Source)

bysort VIN : egen ever_old_data = max(Source == "Old Data")
bysort VIN : egen ever_new_data = max(Source == "New Data")

bysort VIN : egen new_car_in_new_data = max(NewUsedIndicator == "N" & Source == "New Data")
bysort VIN : egen new_car_in_old_data = max(NewUsedIndicator == "N" & Source == "Old Data")


bysort VIN : egen used_car_in_new_data = max(NewUsedIndicator == "U" & Source == "New Data")
bysort VIN : egen used_car_in_old_data = max(NewUsedIndicator == "U" & Source == "Old Data")

by VIN: gen flag =  (new_car_in_new_data & new_car_in_old_data) & _n == 1
count if flag
local NewCarOverlap = `r(N)'
drop flag


by VIN: gen flag =  (used_car_in_new_data & used_car_in_old_data) & _n == 1
count if flag
local UsedCarOverlap = `r(N)'
drop flag

tab Source VehicleYear if (strpos(VehicleModel , "LEAF")|strpos(VehicleModel , "Leaf")) & DealerState == "CA"
local carlist leaf prius volt model

foreach car of local carlist {
	preserve
		gen flag = 1
		keep if strpos(lower(VehicleModel) , lower("`car'")) & DealerState == "CA"
		collapse (count) NewCarsSold = flag, by(VehicleYear Source)
		generate Car = "`car'"
		save "${WorkingDirs}/Tyler/`car'_counts", replace
		graph twoway ///
			(bar  NewCarsSold VehicleYear if  Source == "Old Data") ///
			(bar  NewCarsSold VehicleYear if  Source == "New Data") , ///
			xtitle("Model Year") ytitle("New Vehicle Sales") ///
			legend(label( 1 "Old Data") label(2 "New Data")) ///
			title("CA `car' Sales") name("`car'_sales")


	restore
}
preserve
	clear
	foreach car of local carlist {
		append using "${WorkingDirs}/Tyler/`car'_counts"
	}
restore


//Restrict to CA only

//Vehicle counts, percents, by class, before and after--save table in temporary dataset
//Leaf should be the same, prius went from subsample to full sample

//Time series of prices, by model 

//figure out change in comparison cars





**********CVRP DATA MERGE
//Merge in CVRP data


<</dd_do>>


##General Data Quality:
###Repeats between datasets
<<dd_display: %12.0gc `NewCarOverlap'>> cars appear as being sold new in both data sets, and the records are non-identical (eg. different price, different sales date).  
<<dd_display: %12.0gc `UsedCarOverlap'>> cars appear as being sold used in both data sets, however the differing prices, sales dates, and milages make it plausible that these are the same car being sold again, as is common in the used car market.

<<dd_graph: sav(leaf_sales.png) graphname("leaf_sales")>>

##Census Block Group
Owner's census Block Group is populated for all observations, and the values are distributed as we would expect:  
90% of transactions are associated with a block group that has 50 or fewer transactions associated with it.

