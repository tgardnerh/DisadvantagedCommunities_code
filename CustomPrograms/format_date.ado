capture program drop format_date
program format_date

	syntax varlist (max = 1), format(string) [GENerate(string)] [replace] 
	
	local syntax_error_code 198
	
	//confirm proper specifications
	if !("`replace'" == "replace" & "`generate'" == "" ) & !("`replace'" == "" & "`generate'" != "" ) {
		display as error "specify either generate or replace.  Not both, not neither."
		exit `syntax_error_code'
	}
	
	capture confirm string variable `varlist' 
	if _rc {
		display as error "`varlist' is not in string format"
		exit `syntax_error_code'
	}
	foreach fmt of local format {
		tempvar tempdate
		generate `tempdate' = date(`varlist', "`fmt'")
		format  `tempdate' %td
		capture assert missing(`varlist')  if missing(`tempdate')
		if _rc {
			local success = 0
			continue
		}
		else {
			local success = 1
			continue, break
		}
	}
	
	if `success' == 1 {
		if "`replace'" == "replace" & "`generate'" == "" {
			drop `varlist' 
			rename `tempdate' `varlist'  
		}
		else if "`replace'" == "" & "`generate'" != "" {
			rename `tempdate' `generate'
		}
		else {
			display as error "Woah buddy.  Something's wrong with the code.  you should never-ever get this error message!"
			exit `syntax_error_code'
		}
	}
	else {
		display as error "some `varlist' data could not be converted into standard stata format"
		tab `varlist' if missing(`tempdate') & !missing(`varlist')
		exit `syntax_error_code'
	}

	
end


