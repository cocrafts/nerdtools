local M = {}

M.mergeTables = function(t1, t2)
	if t1 == nil then
		return t2
	end

	for k, v in pairs(t2) do
		t1[k] = v
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
