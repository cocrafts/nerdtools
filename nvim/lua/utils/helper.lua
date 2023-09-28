local M = {}

M.mergeTables = function(t1, t2)
	for i = 1, #t2 do
		table.insert(t1, t2[i])
	end

	return t1
end

M.valueExists = function(item, items)
	for _, value in ipairs(items) do
		if item == value then
			return true
		end
	end

	return false
end

return M
