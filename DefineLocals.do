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

//various "reasonable" specifications:
//New:
local min_price_New_narrow  	12000
local min_price_New_medium		8000
local min_price_New_wide		0

local max_price_New_narrow		75000
local max_price_New_medium		95000
local max_price_New_wide		120000

//used:
local min_price_Used_narrow 	6000
local min_price_Used_medium		2000
local min_price_Used_wide		0


local max_price_Used_narrow		40000
local max_price_Used_medium		70000
local max_price_Used_wide		90000

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

