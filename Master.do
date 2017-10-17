clear all
set more off

***sub-part flags:


**Set Path and environment globals ***
if "`c(username)'" == "tylerhoppenfeld" {
	global Dropbox "/Users/tylerhoppenfeld/Dropbox (Personal)"
}
else if  "`c(username)'" == "Rapson_AirHD" {
	global Dropbox "/Users/Rapson_AirHD/Dropbox"

}
else if  "`c(username)'" == "dsrapson" {
	global Dropbox "C:/Users/dsrapson/Dropbox"

}
else {
	display in red "user `c(username)' is not in code!"
	STOP
}


global Experian 	"$Dropbox/Erich_Dave_Projects/Data/Experian"
global DisComm 		"$Dropbox/Erich_Dave_Projects/Project_DisadvantagedCommunities"
global Code 		"${DisComm}/Code"
global DisCommCode 	"${DisComm}/Code/CVRP_EFMP_EXP_repo"
global ExperianCode "${DisCommCode}/Experian_Dealers"
global Data			"${Dropbox}/Erich_Dave_Projects/Data"
global DisCommData 	"${DisComm}/Data"
global MapData 		"${Data}/mapfiles"
global MapFiles 	"${Data}/mapfiles"
global WorkingDir 	"${DisComm}/Data/UnstableWorking"

global DisStatus "${Dropbox}/Erich_Dave_Projects/Data/Disdvantaged Community designation in CA (related to EFMP)"
global CVRPData "${Dropbox}/Erich_Dave_Projects/Data/CVRP Incentives"
global CVRPDate 20170418

//add ados
adopath + "${DisCommCode}/CustomPrograms"

****************EXPERIAN DATA**********************************


do "${DisCommCode}/data_setup.do"
do "${ExperianCode}/ExpPriceDiagnostics2.do"




