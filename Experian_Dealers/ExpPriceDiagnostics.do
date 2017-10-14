****Experian price diagnostics.

//Set Locals
include "$DisCommCode/DefineLocals.do"

use  "${WorkingDir}/TransactionData", clear

//save a version before restricting bandwidth
tempfile full_bandwidth
save `full_bandwidth'
//restrict to "medium" bandwidth
keep if inrange(MaxCES , `RD_Cutoff'-`bandwidth_m',`RD_Cutoff'+`bandwidth_m')

//look to see about pricing data
hist PurchasePrice if New , ///
	title("New Sales") ///
	xtitle("Reported Purchase Price") ///
	ytitle("Density") ///
	name("PriceNew", replace)
	
	
hist PurchasePrice if !New , ///
	title("Used Sales") ///
	xtitle("Reported Purchase Price") ///
	ytitle("Density") ///
	name("PriceUsed", replace)
	
hist PurchasePrice if New & PurchasePrice < 50000, ///
	title("New Sales") ///
	xtitle("Reported Purchase Price") ///
	ytitle("Density") ///
	note("new sales with a reported purchase price below $50,000") ///
	name("PriceNewtrim", replace)
	
	
hist PurchasePrice if !New  & PurchasePrice < 50000, ///
	title("Used Sales") ///
	xtitle("Reported Purchase Price") ///
	ytitle("Density") ///
	note("used sales with a reported purchase price below $50,000") ///
	name("PriceUsedtrim", replace)
	


//graphs for top-10 model sales
foreach model in `topTenModels' {
	di "`model'"
	//sales numbers
	preserve
		keep if VehicleModel == "`model'"
		local simplename = subinstr("`model'", "-", "",.)
		local simplename = subinstr("`simplename'", " ", "",.)
		gen PurchaseMonth = mofd(PurchaseDate)
		format PurchaseMonth %tm
		gen flag = 1
		collapse (count) flag , by(PurchaseMonth VehicleYear)
		graph twoway ///
			(line flag PurchaseMonth if VehicleYear == 2014) ///
			(line flag PurchaseMonth if VehicleYear == 2015) ///
			(line flag PurchaseMonth if VehicleYear == 2016) ///
			, title("new and used `model' sales by month") ///
			ytitle("Number Sold") ///
			xtitle("Month") ///
			legend(order(1 "2014 Model Year" 2 "2015 Model Year" 3 "2016 Model Year")) ///
			name("month_`simplename'_sales", replace)
	restore
	//sales prices
	preserve
		keep if VehicleModel == "`model'"	
		count if New
		local transaction_count_new = r(N)
		
		count if !New
		local transaction_count_used = r(N)
		
		
		hist PurchasePrice if New , ///
			title("New Sales of `model'") ///
			xtitle("Reported Purchase Price") ///
			ytitle("Density") ///
			note("`transaction_count_new' new sales") ///
			name("PriceNew`simplename'", replace)
	
	
		hist PurchasePrice if !New , ///
			title("Used Sales of `model'") ///
			xtitle("Reported Purchase Price") ///
			ytitle("Density") ///
			note("`transaction_count_used' used sales") ///
			name("PriceUsed`simplename'", replace)
			
		hist PurchasePrice if New & PurchasePrice < 100000, ///
			title("New Sales of `model' (trimmed)") ///
			xtitle("Reported Purchase Price") ///
			ytitle("Density") ///
			note(" sales with a reported purchase price below $100,000") ///
			name("PriceNew`simplename'trim", replace)
	
	
		hist PurchasePrice if !New & PurchasePrice < 50000, ///
			title("Used Sales of `model' (trimmed)") ///
			xtitle("Reported Purchase Price") ///
			ytitle("Density") ///
			note(" sales with a reported purchase price below $100,000") ///
			name("PriceUsed`simplename'trim", replace)
	restore
	
}


//Density plots
foreach new_used in New Used {
	preserve
		keep if strpos("`new_used'", NewUsedIndicator)
		
		if "`new_used'" == "New" {
			local restriction " with reported sales prices over $10,000"
		}
		else {
			local restriction
		}
		
		gen MaxCES_rnd = round(MaxCES )

		collapse (count) Transaction_count = PurchasePrice , by(MaxCES_rnd )

		graph twoway bar Transaction_count MaxCES_rnd , ///
			title("Transaction Density by Forcing Variable") ///
			xtitle("Highest CES score in Zip") ///
			ytitle("Transaction Count") ///
			xline(`RD_Cutoff') ///
			note("restricted to `new_used' Zero Emissions Vehicles`restriction'" "Vertical line at DAC Threshold") ///
			name("rd_density_plot`new_used'", replace)	
	restore
}

//zip-code count in each CES bin

preserve
	gen MaxCES_rnd = round(MaxCES )
	keep MaxCES_rnd OwnerZipCode
	duplicates drop
	gen flag = 1
	collapse (count) flag, by(MaxCES_rnd)
	
	graph twoway bar flag MaxCES_rnd , ///
			title("Zip Code Count by Forcing Variable") ///
			xtitle("Highest CES score in Zip") ///
			ytitle("Zip Code Count") ///
			xline(`RD_Cutoff') ///
			name("ZipCountbyCES", replace)		
restore




foreach bandwidth_spec in s m w {
	use `full_bandwidth', clear
	local bw_H = `RD_Cutoff'+`bandwidth_`bandwidth_spec''
	local bw_L = `RD_Cutoff'-`bandwidth_`bandwidth_spec''
	keep if inlist(Replacement_Vehicle_Tech, "`tech_1'") & inrange(MaxCES , `bw_L',`bw_H') & (PurchasePrice > `min_purchase_price' | NewUsedIndicator == "U")
di `"	keep if inlist(Replacement_Vehicle_Tech, "`tech_1'") & inrange(MaxCES , `bw_L',`bw_H') & (PurchasePrice > `min_purchase_price' | NewUsedIndicator == "U")"'
	foreach new_used in New Used {
		preserve
			keep if strpos("`new_used'", NewUsedIndicator)
			di "`new_used'"
			if "`new_used'" == "New" {
				local restriction " with reported sales prices over $8000"
			}
			else {
				local restriction
			}
			binscatter PurchasePrice MaxCES , ///
				rd(`RD_Cutoff')  n(`binNumber') ///
				title("Uncontrolled RD Plot") ///
				ytitle("Average Purchase Price") ///
				xtitle("Highest CES score in Zip") ///
				note("restricted to `new_used' Zero Emissions Vehicles`restriction'") ///
				name("uncontRD`new_used'_bw_`bandwidth_spec'", replace)
			binscatter PurchasePrice MaxCES , ///
				rd(`RD_Cutoff')  n(`binNumber') controls(CES20Score) ///
				title("Controlled RD Plot") ///
				ytitle("Average Purchase Price" "Controlling for tract-level CES") ///
				xtitle("Highest CES score in Zip") ///
				note("restricted to `new_used' Zero Emissions Vehicles`restriction'") ///
				name("contRD`new_used'_bw_`bandwidth_spec'" , replace)
			
	

		restore
	}

}

