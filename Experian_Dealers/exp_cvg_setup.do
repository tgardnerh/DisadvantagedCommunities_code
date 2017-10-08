
//read in experian data
import delimited using "${Data}/Experian/July2017_Experian300k/UCDavis_Output_201601_201704.csv", case(preserve) clear


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


rename ( Model Make Group) (  VehicleModel VehicleMake VehicleGroup)

generate Source = "New Data"

//format variables so append works: 
destring ReportingPeriod OwnerZipCode DealerZipCode , replace

 
append using "$WorkingDirs/Tyler/Experian"
replace Source = "Old Data" if missing(Source)
replace Source = "Backfill" if backfill_flag == 1
bysort VIN : egen ever_old_data = max(Source == "Old Data")
bysort VIN : egen ever_new_data = max(Source == "New Data")

bysort VIN : egen new_car_in_new_data = max(NewUsedIndicator == "N" & Source == "New Data")
bysort VIN : egen new_car_in_old_data = max(NewUsedIndicator == "N" & Source == "Old Data")


bysort VIN : egen used_car_in_new_data = max(NewUsedIndicator == "U" & Source == "New Data")
bysort VIN : egen used_car_in_old_data = max(NewUsedIndicator == "U" & Source == "Old Data")

save "$WorkingDirs/Tyler/Experian_merged", replace

