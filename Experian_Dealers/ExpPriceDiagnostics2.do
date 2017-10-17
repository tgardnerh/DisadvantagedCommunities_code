**second round of Experian diagnostics

//Set Locals
include "$DisCommCode/DefineLocals.do"

use  "${DisComm}/Data/TransactionData", clear

keep if inlist(Replacement_Vehicle_Tech, "`tech_1'") & inrange(MaxCES , `RD_Cutoff'-`bandwidth_m',`RD_Cutoff'+`bandwidth_m')

foreach price_truncate in narrow medium wide {
	foreach new_used in New Used {
		preserve
			keep if strpos("`new_used'", NewUsedIndicator) & inrange(PurchasePrice, `min_price_`new_used'_`price_truncate'',`max_price_`new_used'_`price_truncate'')

			binscatter PurchasePrice MaxCES , ///
				rd(`RD_Cutoff')  n(`binNumber') ///
				title("Uncontrolled RD Plot, `new_used', `price_truncate' ") ///
				ytitle("Average Purchase Price") ///
				xtitle("Highest CES score in Zip") ///
				note("restricted to `new_used' Zero Emissions Vehicles, prices between `min_price_`new_used'_`price_truncate'' and `max_price_`new_used'_`price_truncate''") ///
				name("uncontRD`new_used'_truncate_`price_truncate'" , replace)


				graph export "${DisComm}/ResultsOut/20171015/uncontRD`new_used'_truncate_`price_truncate'.png", name("uncontRD`new_used'_truncate_`price_truncate'") replace


			binscatter PurchasePrice MaxCES , ///
				rd(`RD_Cutoff')  n(`binNumber') controls(CES20Score) ///
				title("Controlled RD Plot, `new_used', `price_truncate' ") ///
				ytitle("Average Purchase Price" "Controlling for tract-level CES") ///
				xtitle("Highest CES score in Zip") ///
				note("restricted to `new_used' Zero Emissions Vehicles, prices between `min_price_`new_used'_`price_truncate'' and `max_price_`new_used'_`price_truncate''") ///
				name("contRD`new_used'_truncate_`price_truncate'" , replace)
			
				graph export "${DisComm}/ResultsOut/20171015/contRD`new_used'_truncate_`price_truncate'.png", name("contRD`new_used'_truncate_`price_truncate'") replace
	

		restore
	}

}


**Composition of Models change at discontinuity:
use  "${DisComm}/Data/TransactionData", clear

//Density plots
foreach new_used in New Used {
	foreach model in `topTenModels' {
		preserve
			keep if strpos("`new_used'", NewUsedIndicator)
			local simplename = subinstr("`model'", "-", "",.)
			local simplename = subinstr("`simplename'", " ", "",.)
			gen MaxCES_rnd = round(MaxCES )
			generate flag = VehicleModel == "`model'"
			collapse FractionModel = flag , by(MaxCES_rnd )

			graph twoway bar FractionModel MaxCES_rnd , ///
				title("Fraction of `new_used' sales represented by `model'") ///
				xtitle("Highest CES score in Zip") ///
				ytitle("Transaction Fraction") ///
				xline(`RD_Cutoff') ///
				note("restricted to `new_used' Zero Emissions Vehicles`restriction'" "Vertical line at DAC Threshold") ///
				name("rd_composition_plot`new_used'`simplename'", replace)	


				graph export "${DisComm}/ResultsOut/20171015/rd_composition_plot`new_used'`simplename'.png", name("rd_composition_plot`new_used'`simplename'") replace
		
		restore
	}
}


**New/Used composition at discontinuity:
use  "${DisComm}/Data//TransactionData", clear

//Density plots
foreach model in `topTenModels' "All Cars" {
	preserve
		if "`model'" != "All Cars" {
			keep if VehicleModel == "`model'"
		}
		local simplename = subinstr("`model'", "-", "",.)
		local simplename = subinstr("`simplename'", " ", "",.)
		gen MaxCES_rnd = round(MaxCES )
		
		collapse FractionNew = New , by(MaxCES_rnd )

		graph twoway bar FractionNew MaxCES_rnd , ///
			title("Fraction `model' sales that are new") ///
			xtitle("Highest CES score in Zip") ///
			ytitle("Transaction Fraction") ///
			xline(`RD_Cutoff') ///
			note("restricted to `model' Zero Emissions Vehicles`restriction'" "Vertical line at DAC Threshold") ///
			name("rd_new_used_plot`simplename'", replace)	

			graph export "${DisComm}/ResultsOut/20171015/rd_new_used_plot`simplename'.png", name("rd_new_used_plot`simplename'") replace

	restore
}



***Volume across discontinuity, by model
use  "${DisComm}/Data//TransactionData", clear
//Density plots
foreach model in `topTenModels'  {
	preserve
		keep if VehicleModel == "`model'"
		local simplename = subinstr("`model'", "-", "",.)
		local simplename = subinstr("`simplename'", " ", "",.)
		gen MaxCES_rnd = round(MaxCES )

		collapse (count) Transaction_count = PurchasePrice , by(MaxCES_rnd )

		graph twoway bar Transaction_count MaxCES_rnd , ///
			title("Transaction Density of `model' cars by Forcing Variable") ///
			xtitle("Highest CES score in Zip") ///
			ytitle("Transaction Count") ///
			xline(`RD_Cutoff') ///
			note("restricted to `model' cars Zero Emissions Vehicles`restriction'" "Vertical line at DAC Threshold") ///
			name("rd_density_plot`simplename'", replace)	
			
			graph export "${DisComm}/ResultsOut/20171015/rd_density_plot`simplename'.png", name("rd_density_plot`simplename'") replace

	restore
}


***Transaction density (unadjusted and per capita)

***Volume across discontinuity, by model
use  "${DisComm}/Data//TransactionData", clear

//Density plots
foreach new_used in New Used {
	preserve
		keep if strpos("`new_used'", NewUsedIndicator)
		
		
		gen MaxCES_rnd = round(MaxCES )

		collapse (sum) population (count) Transaction_count = PurchasePrice , by(MaxCES_rnd )

		generate Transaction_percap = Transaction_count/population

		graph twoway bar Transaction_percap MaxCES_rnd if population > 3000000, ///
			title("Per Capita Transaction Density by Forcing Variable, `new_used'") ///
			xtitle("Highest CES score in Zip") ///
			ytitle("Transaction Count") ///
			xline(`RD_Cutoff') ///
			note("restricted to `new_used' Zero Emissions Vehicles" "gaps indicate CES bins with population < 3,000,000" "Vertical line at DAC Threshold") ///
			name("rd_density_percap`new_used'", replace)	
			
			graph export "${DisComm}/ResultsOut/20171015/rd_density_percap`new_used'.png", name("rd_density_percap`new_used'") replace

	restore
}

***Volume across discontinuity, by model
use  "${DisComm}/Data//TransactionData", clear

//Density plots
foreach new_used in New Used {
	preserve
		keep if strpos("`new_used'", NewUsedIndicator)
		
		
		gen MaxCES_rnd = round(MaxCES )

		collapse (sum) population (count) Transaction_count = PurchasePrice , by(MaxCES_rnd )

		generate Transaction_percap = Transaction_count/population

		graph twoway bar Transaction_count MaxCES_rnd , ///
			title("Transaction Count by Forcing Variable, `new_used'") ///
			xtitle("Highest CES score in Zip") ///
			ytitle("Transaction Count") ///
			xline(`RD_Cutoff') ///
			note("restricted to `new_used' Zero Emissions Vehicles"  "Vertical line at DAC Threshold") ///
			name("rd_density_gross`new_used'", replace)	
			
			graph export "${DisComm}/ResultsOut/20171015/rd_density_gross`new_used'.png", name("rd_density_gross`new_used'") replace

	restore
}


***Subsidy per transaction
use  "${DisComm}/Data//TransactionData", clear

//Density plots

gen MaxCES_rnd = round(MaxCES )
gen CVRP_EFMP_total = EFMPTotalIncentive + CVRP_Rebate
collapse (max) MaxCES_rnd (first) EFMPTotalIncentive EFMPBaseIncentiveTOTAL EFMPPlusUpIncentiveTOTAL CVRP_Rebate CVRP_EFMP_total (count) Transaction_count = PurchasePrice , by(OwnerZipCode )
collapse (sum) EFMPTotalIncentive EFMPBaseIncentiveTOTAL EFMPPlusUpIncentiveTOTAL CVRP_Rebate CVRP_EFMP_total Transaction_count  , by(MaxCES_rnd )

foreach incentive in EFMPTotalIncentive EFMPBase EFMPPlusUp CVRP_Rebate CVRP_EFMP_total {
	preserve
		generate incentive_per_transaction = `incentive'/Transaction_count
	
		graph twoway bar incentive_per_transaction MaxCES_rnd if Transaction_count >= 500 , ///
			title("`incentive' per Transaction by Forcing Variable") ///
			xtitle("Highest CES score in Zip") ///
			ytitle("Subsidy per Transaction") ///
			xline(`RD_Cutoff') ///
			note("restricted to `new_used' Zero Emissions Vehicles" "gaps indicate CES bins with fewer than 500 transactions" "Vertical line at DAC Threshold") ///
			name("`incentive'_per_trans", replace)	
			
			graph export "${DisComm}/ResultsOut/20171015/`incentive'_per_trans.png", name("`incentive'_per_trans") replace
	restore
}

//Price statistics for each model
use  "${DisComm}/Data//TransactionData", clear

matrix mstats = J(1,7,.)
matrix colnames mstats = p10 p25 p50 p75 p90 mean count
foreach model in `topTenModels'  {
	matrix row = J(1,7,.)
	sum PurchasePrice if VehicleModel == "`model'", d
	matrix row[1,1] = `r(p10)'
	matrix row[1,2] = `r(p25)'
	matrix row[1,3] = `r(p50)'
	matrix row[1,4] = `r(p75)'
	matrix row[1,5] = `r(p90)'
	matrix row[1,6] = `r(mean)'
	matrix row[1,7] = `r(N)'
	matrix mstats = mstats \ row		
}

clear

svmat mstats, names(col)
drop in 1/1
generate ModelName = ""
order ModelName

local n = 1
foreach model in `topTenModels'  {
	replace ModelName = "`model'" if _n == `n'
	local ++n
}

export delimited using "${DisComm}/ResultsOut/20171015/PriceStats.csv", replace



