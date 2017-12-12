hoistAssignments = (ast, assignments)->
	for assignment in assignments
		ast.body.unshift assignment
	return


module.exports = hoistAssignments