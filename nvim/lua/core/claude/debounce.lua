--- Debounce utility inspired by claudecode.nvim
--- Prevents rapid repeated calls
--- @module 'core.claude.debounce'

local M = {}

-- Create a debounced function
function M.create(fn, delay_ms)
	local timer = nil

	return function(...)
		local args = { ... }

		if timer then
			vim.loop.timer_stop(timer)
			timer = nil
		end

		timer = vim.defer_fn(function()
			fn(unpack(args))
			timer = nil
		end, delay_ms or 100)
	end
end

-- Create a throttled function (executes at most once per interval)
function M.throttle(fn, interval_ms)
	local last_call = 0
	local timer = nil

	return function(...)
		local now = vim.loop.now()
		local args = { ... }

		if now - last_call >= (interval_ms or 100) then
			last_call = now
			fn(unpack(args))
		else
			-- Schedule for next available slot
			if timer then
				vim.loop.timer_stop(timer)
			end

			local delay = interval_ms - (now - last_call)
			timer = vim.defer_fn(function()
				last_call = vim.loop.now()
				fn(unpack(args))
				timer = nil
			end, delay)
		end
	end
end

return M