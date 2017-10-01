clear all
set more off

***sub-part flags:

local Disadvantaged_Communities			0
local Experian_Old_Data					0
local Experian_New_Data					0




**Set Pathand environment Globals ***
if "`c(username)'" == "tylerhoppenfeld" {
	global Dropbox "/Users/tylerhoppenfeld/Dropbox (Personal)"
	global DisCommCode "/Users/tylerhoppenfeld/Documents/DisadvantagedCommunities_code"
	global Experian "$Dropbox/Erich_Dave_Projects/Data/Experian"
	global ExperianCode "/Users/tylerhoppenfeld/Documents/DisadvantagedCommunities_code/Experian_Dealers"

}
else {
	display in red "user `c(username)' is not in code!"
	STOP
}
global WorkingDirs 	"${Dropbox}/Erich_Dave_Projects/WorkingDirectories"
global DisComm 		"$Dropbox/Erich_Dave_Projects/Project_DisadvantagedCommunities"
global Data			"$Dropbox/Erich_Dave_Projects/Data"
global MapData 		"$Data/mapfiles"
global MapFiles 	"$Data/mapfiles"
global scratch 		"${Dropbox}/Erich_Dave_Projects/WorkingDirectories/Tyler/scratch"

global DisStatus "$Dropbox/Erich_Dave_Projects/Data/Disdvantaged Community designation in CA (related to EFMP)"
global CVRPData "${Dropbox}/Erich_Dave_Projects/Data/CVRP Incentives"
global CVRPDate 20170418


**Version setting
global ResultsVersion 20170710


************DISADVANTAGED COMMUNTIIES************************
if `Disadvantaged_Communities' == 1 {

	**Data Prep**
	do ${DisCommCode}/DataPrep/1_load_disadvantaged_communities
	do ${DisCommCode}/DataPrep/2_adjacent_disadvantaged_status
	do ${DisCommCode}/DataPrep/3_combine_cvrp_disadvantaged_status
	do ${DisCommCode}/DataPrep/4_CensusTract_demographics
	do ${DisCommCode}/DataPrep/5_ZipCode_demographics



	**Power Calcs
	do ${DisCommCode}/PowerCalcs/CES20_disadvantaged_threshold_power_calcs_graphs

	do ${DisCommCode}/PowerCalcs/CES20_disadvantaged_threshold_power_calcs
	**Summary stats
	do ${DisCommCode}/cvrp_summary_stats.do
	do ${DisCommCode}/Border_discontinuity_summstats.do


	**Discontinutity stats
	do ${DisCommCode}/cvrp_CES20_discontinuity_stats.do
	do ${DisCommCode}/cvrp_CES20_discontinuity_stats_by_zip.do
	**Disc. maps
	do ${DisCommCode}/CES20_discontinuity_maps_by_Zip.do
	do ${DisCommCode}/CES20_discontinuity_maps_by_CensusTract.do
}
****************EXPERIAN DATA**********************************
if `Experian_Old_Data' == 1 {
	do ${ExperianCode}/experian_readin
	do ${ExperianCode}/CBP_readin
	dyndoc ${ExperianCode}/Experian_Coverage.do, saving("$WorkingDirs/Tyler/Experian_Coverage_restrictedv2.html") replace
}


if `Experian_New_Data' == 1 {
//	do ${ExperianCode}/exp_cvg_setup.do
	dyndoc ${ExperianCode}/Experian_Coverage_New.do, saving("$WorkingDirs/Tyler/New_Experian_analysis2.html") replace
}

	dyndoc ${ExperianCode}/CVRPvsEXP.do, saving("$WorkingDirs/Tyler/CVRPvsEXP.html") replace
