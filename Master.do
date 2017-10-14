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

//add ados
adopath + "$DisCommCode/CustomPrograms"

****************EXPERIAN DATA**********************************


if `Experian_New_Data' == 1 {
	do ${DisCommCode}/data_setup.do
	do ${ExperianCode}/exp_cvg_setup.do
	do $ExperianCode/ExpPriceDiagnostics.do
}



