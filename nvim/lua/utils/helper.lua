local M = {}

M.mergeTables = function(t1, t2)
	for i = 1, #t2 do
		table.insert(t1, t2[i])
	end

	return t1
end

return M
