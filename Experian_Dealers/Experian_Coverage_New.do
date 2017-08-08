<<dd_include: header.txt >>


<<dd_do:  >>

//read in experian data
use "$WorkingDirs/Tyler/Experian_merged", clear
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
local min_purchase_price 10000 //Prices are bimodal, I suspect that the lower bunching is misreported prices.

bys VIN: gen flag =  (new_car_in_new_data & new_car_in_old_data) & _n == 1
count if flag
local NewCarOverlap = `r(N)'
drop flag


bys VIN: gen flag =  (used_car_in_new_data & used_car_in_old_data) & _n == 1
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
		//add to stack the bars
		bysort VehicleYear : egen New_Data_stack = sum(NewCarsSold)
		graph twoway ///
			(bar  New_Data_stack VehicleYear if  Source == "New Data") ///
			(bar  NewCarsSold VehicleYear if  Source == "Old Data") ///
			,  ///
			xtitle("Model Year") ytitle("New Vehicle Sales") ///
			legend( label(1 "New Data") label( 2 "Old Data")) ///
			title("CA `car' Sales") name("`car'_sales")


	restore
}
preserve
	clear
	foreach car of local carlist {
		append using "${WorkingDirs}/Tyler/`car'_counts"
	}
restore




//Time series of prices, by model 
foreach car of local carlist {
	preserve
		keep if PurchasePrice > `min_purchase_price'
		keep if strpos(lower(VehicleModel) , lower("`car'")) & DealerState == "CA"
		collapse (p50) PurchasePrice, by(VehicleYear Source)
		generate Car = "`car'"
		save "${WorkingDirs}/Tyler/`car'_Prices", replace
		//add to stack the bars
		bysort VehicleYear : egen New_Data_stack = sum(PurchasePrice)
		graph twoway ///
			(bar  New_Data_stack VehicleYear if  Source == "New Data") ///
			(bar  PurchasePrice VehicleYear if  Source == "Old Data") ///
			,  ///
			xtitle("Model Year") ytitle("Median Purchase Price") ///
			legend( label(1 "New Data") label( 2 "Old Data")) ///
			title("CA `car' Prices") name("`car'_prices")


	restore
}
preserve
	clear
	foreach car of local carlist {
		append using "${WorkingDirs}/Tyler/`car'_prices"
	}
restore


//figure out change in comparison cars



// saving(leaf_sales.png)

**********CVRP DATA MERGE
//Merge in CVRP data


<</dd_do>>


##General Data Quality:
###Repeats between datasets
<<dd_display: %12.0gc `NewCarOverlap'>> cars appear as being sold new in both data sets, and the records are non-identical (eg. different price, different sales date).  
<<dd_display: %12.0gc `UsedCarOverlap'>> cars appear as being sold used in both data sets, however the differing prices, sales dates, and milages make it plausible that these are the same car being sold again, as is common in the used car market.

<<dd_graph: graphname(leaf_sales) saving(leaf_sales.png) replace height(400) width(500) >>
<<dd_graph: graphname(prius_sales) saving(prius_sales.png) replace height(400) width(500) >>
<<dd_graph: graphname(volt_sales) saving(volt_sales.png) replace height(400) width(500) >>
<<dd_graph: graphname(model_sales) saving(model_sales.png) replace height(400) width(500) >>


<<dd_graph:  graphname(leaf_prices)  saving(leaf_prices.png) replace height(400) width(500) >>
<<dd_graph: graphname(prius_prices) saving(prius_prices.png) replace height(400) width(500) >>
<<dd_graph:  graphname(volt_prices)  saving(volt_prices.png) replace height(400) width(500) >>
<<dd_graph: graphname(model_prices) saving(model_prices.png) replace height(400) width(500) >>

##Census Block Group
Owner's census Block Group is populated for all observations, and the values are distributed as we would expect:  
90% of transactions are associated with a block group that has 50 or fewer transactions associated with it.

