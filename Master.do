clear all
set more off


if "`c(username)'" == "tylerhoppenfeld" {
	global Dropbox "/Users/tylerhoppenfeld/Dropbox (Personal)"
	global DisCommCode "/Users/tylerhoppenfeld/Documents/DisadvantagedCommunities_code"
}
else {
	display in red "user `c(username)' is not in code!"
	STOP
}
global DisComm "$Dropbox/Erich_Dave_Projects/Project_DisadvantagedCommunities"
global MapData "$Dropbox/Erich_Dave_Projects/Data/mapfiles"
global MapFiles "${Dropbox}/Erich_Dave_Projects/Data/mapfiles"

global DisStatus "$Dropbox/Erich_Dave_Projects/Data/Disdvantaged Community designation in CA (related to EFMP)"
global CVRPData "${Dropbox}/Erich_Dave_Projects/Data/CVRP Incentives"
global CVRPDate 20170418


**Version setting
global ResultsVersion 20170418



**Data Prep**
do ${DisCommCode}/DataPrep/1_load_disadvantaged_communities
do ${DisCommCode}/DataPrep/2_adjacent_disadvantaged_status
do ${DisCommCode}/DataPrep/3_combine_cvrp_disadvantaged_status
do ${DisCommCode}/DataPrep/4_CensusTract_demographics
do ${DisCommCode}/DataPrep/5_ZipCode_demographics



**Power Calcs
do ${DisCommCode}/PowerCalcs/CES20_disadvantaged_threshold_power_calcs_graphs

do ${DisCommCode}/PowerCalcs/CES20_disadvantaged_threshold_power_calcs