clear all
set more off

***sub-part flags:






**Set Pathand environment Globals ***
if "`c(username)'" == "tylerhoppenfeld" {
	global Dropbox "/Users/tylerhoppenfeld/Dropbox (Personal)"
	global DisCommCode "/Users/tylerhoppenfeld/Documents/DisadvantagedCommunities_code"
	global ExperianCode "/Users/tylerhoppenfeld/Documents/DisadvantagedCommunities_code/Experian_Dealers"

}
else {
	display in red "user `c(username)' is not in code!"
	STOP
}

global Experian "$Dropbox/Erich_Dave_Projects/Data/Experian"
global DisComm 		"$Dropbox/Erich_Dave_Projects/Project_DisadvantagedCommunities"
global Data			"$Dropbox/Erich_Dave_Projects/Data"
global MapData 		"$Data/mapfiles"
global MapFiles 	"$Data/mapfiles"
global WorkingDir 	"${DisComm}/Data/UnstableWorking"

global DisStatus "$Dropbox/Erich_Dave_Projects/Data/Disdvantaged Community designation in CA (related to EFMP)"
global CVRPData "${Dropbox}/Erich_Dave_Projects/Data/CVRP Incentives"
global CVRPDate 20170418

//add ados
adopath + "$DisCommCode/CustomPrograms"

****************EXPERIAN DATA**********************************


do ${DisCommCode}/data_setup.do
do ${ExperianCode}/ExpPriceDiagnostics.do




