
function! gtd#formula#OperatorPrecedenceHelper(formula)
	let l:formula = substitute(a:formula, '^\s*\(.\{-}\)\s*$', '\1', '')
	let l:formula = substitute(l:formula, '\([()]\)', '\1\1\1', 'g')
	let l:formula = substitute(l:formula, '\s*+\s*', '))+((', 'g')
	let l:formula = substitute(l:formula, '\s\+', ') (', 'g')
	return '(('.l:formula.'))'
endfunction

function! gtd#formula#Parser(formula)

	let [ l:c_idx, l:br_match, l:brackets ] = [ 0, 0, 0 ]
	let l:formula_len = len(a:formula)
	while l:c_idx < l:formula_len
		if a:formula[l:c_idx] == '('
			let l:br_match += 1
		elseif a:formula[l:c_idx] == ')'
			let l:br_match -= 1
		endif

		if l:br_match == 0
			break
		else
			let l:brackets = 1
		endif

		let l:c_idx += 1
	endwhile

	if l:brackets == 1
		if l:c_idx == l:formula_len-1
			return gtd#formula#Parser(
				\ a:formula[1:l:c_idx-1]
				\ )
		else
			let l:operator = get(a:formula, l:c_idx+1)
			if l:operator == '+' || l:operator == ' '
				return [
					\ l:operator,
					\ gtd#formula#Parser(
						\ a:formula[0:l:c_idx]
						\ ),
					\ gtd#formula#Parser(
						\ a:formula[l:c_idx+2:]
						\ )
					\ ]
			endif
		endif
	else
		return get(a:formula, 0)
	endif

endfunction

function! gtd#formula#Simplify(formula)
	let l:formula = s:GtdFormulaEltSimplify(
		\ gtd#formula#ListConvert(a:formula)
		\ )
	let l:elt_idx = 0
	while l:elt_idx < len(l:formula)
		if l:formula[l:elt_idx] == '+'
			let l:formula[l:elt_idx] = ' + '
		endif
		let l:elt_idx += 1
	endwhile
	return join(l:formula, '')
endfunction

function! gtd#formula#ListConvert(formula)
	let l:formula = substitute(a:formula, '\s*+\s*', '+', 'g')
	let [ l:formula_list, l:c_idx, l:atom_pending ] = [ [], 0, '' ]

	while l:c_idx < strlen(l:formula)
		if index([ '(', ')', '+', ' ' ], l:formula[l:c_idx]) >= 0
			if !empty(l:atom_pending)
				let l:formula_list += [ l:atom_pending ]
				let l:atom_pending = ''
			endif
			let l:formula_list += [ l:formula[l:c_idx] ]
		else
			let l:atom_pending .= l:formula[l:c_idx]
		endif
		let l:c_idx += 1
	endwhile

	if !empty(l:atom_pending)
		let l:formula_list += [ l:atom_pending ]
	endif

	return l:formula_list
endfunction

function! s:GtdFormulaEltSimplify(formula_list)

	let l:formula_clean = []	" Result
	let l:c_idx = 0				" Current index in the list
	let l:op_last = 'N'			" Last seen operator before opening bracket
	let l:br_start = -1			" Opening bracket position
	let l:br_end = -1			" Closing bracket position
	let l:br_match = 0			" Marker to know if we have a bracket match
	let l:op_out = []			" Operators immediately outside the brackets
	let l:op_in = []			" Operators inside the current brackets
	let l:wait_for_eob = 0		" Wait for end of current bracket block

	while l:c_idx < len(a:formula_list)

		let l:c_elt = a:formula_list[l:c_idx]

		if l:c_elt == '('
			if l:br_start == -1
				let l:br_start = l:c_idx
				let l:op_in = []
			else
				let l:wait_for_eob = 1
			endif
			let l:br_match += 1
			if empty(l:op_out)
				let l:op_out += [ l:op_last ]
			endif
		elseif l:c_elt == ')'
			let l:br_match -= 1
			if l:br_start != -1 && l:br_match == 0
				let l:br_end = l:c_idx
				if l:c_idx < len(a:formula_list)-1
					let l:c_idx += 1
					continue
				endif
			elseif l:br_match == 1
				let l:wait_for_eob = 0
			endif
		elseif l:wait_for_eob == 0 && (l:c_elt == '+' || l:c_elt == ' ')
			if l:br_start != -1 && l:br_end == -1
				" Inside some brackets
				let l:op_in += [ l:c_elt ]
			else
				" Outside of any brackets
				if l:br_start == -1
					" Before opening bracket
					let l:op_last = l:c_elt
				else
					" After closing bracket
					let l:op_out += [ l:c_elt ]
				endif
			endif
		endif

		if l:br_match == 0 && l:br_start != -1 && l:br_end != -1
			if s:GtdFormulaKeepBrackets(l:op_in, l:op_out)
				return l:formula_clean
					\ + [ '(' ]
					\ + s:GtdFormulaEltSimplify(
						\ a:formula_list[l:br_start+1:l:br_end-1]
						\ )
					\ + [ ')' ]
					\ + s:GtdFormulaEltSimplify(
						\ a:formula_list[l:br_end+1:]
						\ )
			else
				return l:formula_clean
					\ + s:GtdFormulaEltSimplify(
						\ a:formula_list[l:br_start+1:l:br_end-1]
							\ + a:formula_list[l:br_end+1:]
						\ )
			endif
		else
			if l:br_match == 0 && l:br_start == -1
				let l:formula_clean += [ l:c_elt ]
			endif
			let l:c_idx += 1
		endif

	endwhile

	return l:formula_clean
endfunction

function! s:GtdFormulaKeepBrackets(op_in, op_out)
	" Brackets are usefull if there is at least one operator inside them whose
	" precedence is weaker than those outside.
	return !empty(a:op_in)
		\ && index(a:op_out, ' ') >= 0
		\ && index(a:op_in, '+') >= 0
endfunction

