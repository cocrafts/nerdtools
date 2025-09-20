--- Smart mention queue system inspired by claudecode.nvim
--- Queues mentions when Claude isn't connected and sends them when it is
--- @module 'core.claude.mention'

local M = {}
local utils = require("core.claude.utils")

-- Queue for pending mentions
local mention_queue = {}

-- Add a mention to the queue
function M.queue(filepath, text, line_start, line_end)
	table.insert(mention_queue, {
		filepath = filepath,
		text = text,
		line_start = line_start,
		line_end = line_end,
		timestamp = os.time(),
	})
end

-- Process all queued mentions
function M.process_queue(send_func)
	if #mention_queue == 0 then
		return 0
	end

	local sent = 0
	local temp_queue = mention_queue
	mention_queue = {}

	for _, mention in ipairs(temp_queue) do
		if send_func(mention.filepath, mention.text, mention.line_start, mention.line_end) then
			sent = sent + 1
		else
			-- Re-queue if failed
			table.insert(mention_queue, mention)
		end
	end

	return sent
end

-- Clear the queue
function M.clear()
	local count = #mention_queue
	mention_queue = {}
	return count
end

-- Get queue size
function M.size()
	return #mention_queue
end

-- Check if queue has items
function M.has_pending()
	return #mention_queue > 0
end

return M