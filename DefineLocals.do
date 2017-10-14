**Define Locals

//Set Locals

//set Bandwidth 
local bandwidth_s = 10
local bandwidth_m = 20
local bandwidth_w = 40
local RD_Cutoff = 36.6

local binNumber 20

//lowest price for new car that we call "Reasonable"
local min_purchase_price 8000
//Vehicle technologies
local tech_1 "Hybrid", "BEV", "PHEV"
local tech_2 "Conventional", "OTHER"
//Period of interest
local StartDate = date("March 1 2016", "MDY")

//characters to ignore in destring
local ignore_chars NA

//top ten models
#delimit ;
local topTenModels 
	 `""500"      
	 "C-Max"     
	 "Fusion"       
	 "Leaf"   
	 "Model S"    
	 "Model X"      
	 "Prius"    
	 "Prius C"
	 "Volt"         
	 "i3""' 
;
#delimit cr

