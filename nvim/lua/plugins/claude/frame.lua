---@brief WebSocket frame encoding/decoding (RFC 6455)
---@module 'plugins.claude.frame'

local M = {}

local utils = require("plugins.claude.utils")
local bit = utils.bit

-- WebSocket opcodes
M.OPCODE = {
	CONTINUATION = 0x0,
	TEXT = 0x1,
	BINARY = 0x2,
	CLOSE = 0x8,
	PING = 0x9,
	PONG = 0xA,
}

--- Convert number to bytes
---@param num number
---@param bytes number
---@return string
local function num_to_bytes(num, bytes)
	local result = ""
	for i = bytes - 1, 0, -1 do
		local byte = bit.band(bit.rshift(num, i * 8), 0xFF)
		result = result .. string.char(byte)
	end
	return result
end

--- Convert bytes to number
---@param str string
---@return number
local function bytes_to_num(str)
	local num = 0
	for i = 1, #str do
		num = bit.lshift(num, 8)
		num = bit.bor(num, string.byte(str, i))
	end
	return num
end

--- Encode WebSocket frame
---@param opts table
---@return string
function M.encode(opts)
	local fin = opts.fin and 0x80 or 0x00
	local opcode = opts.opcode or M.OPCODE.TEXT
	local payload = opts.payload or ""
	local masked = opts.masked or false

	-- First byte: FIN + RSV + Opcode
	local frame = string.char(bit.bor(fin, opcode))

	-- Payload length
	local payload_len = #payload
	local mask_bit = masked and 0x80 or 0x00

	if payload_len < 126 then
		frame = frame .. string.char(bit.bor(mask_bit, payload_len))
	elseif payload_len < 65536 then
		frame = frame .. string.char(bit.bor(mask_bit, 126))
		frame = frame .. num_to_bytes(payload_len, 2)
	else
		frame = frame .. string.char(bit.bor(mask_bit, 127))
		frame = frame .. num_to_bytes(payload_len, 8)
	end

	-- Masking (client to server only)
	if masked then
		local mask_key = ""
		for i = 1, 4 do
			mask_key = mask_key .. string.char(math.random(0, 255))
		end
		frame = frame .. mask_key

		-- Apply mask to payload
		local masked_payload = ""
		for i = 1, #payload do
			local byte = string.byte(payload, i)
			local mask_byte = string.byte(mask_key, ((i - 1) % 4) + 1)
			masked_payload = masked_payload .. string.char(bit.bxor(byte, mask_byte))
		end
		frame = frame .. masked_payload
	else
		frame = frame .. payload
	end

	return frame
end

--- Decode WebSocket frame
---@param buffer string
---@return table|nil frame_data
---@return string remaining
function M.decode(buffer)
	if #buffer < 2 then
		return nil, buffer
	end

	local pos = 1

	-- First byte: FIN + RSV + Opcode
	local byte1 = string.byte(buffer, pos)
	pos = pos + 1

	local fin = bit.band(byte1, 0x80) == 0x80
	local opcode = bit.band(byte1, 0x0F)

	-- Second byte: Mask + Payload length
	local byte2 = string.byte(buffer, pos)
	pos = pos + 1

	local masked = bit.band(byte2, 0x80) == 0x80
	local payload_len = bit.band(byte2, 0x7F)

	-- Extended payload length
	if payload_len == 126 then
		if #buffer < pos + 1 then
			return nil, buffer
		end
		payload_len = bytes_to_num(buffer:sub(pos, pos + 1))
		pos = pos + 2
	elseif payload_len == 127 then
		if #buffer < pos + 7 then
			return nil, buffer
		end
		payload_len = bytes_to_num(buffer:sub(pos, pos + 7))
		pos = pos + 8
	end

	-- Masking key
	local mask_key = nil
	if masked then
		if #buffer < pos + 3 then
			return nil, buffer
		end
		mask_key = buffer:sub(pos, pos + 3)
		pos = pos + 4
	end

	-- Check if we have complete payload
	if #buffer < pos + payload_len - 1 then
		return nil, buffer
	end

	-- Extract payload
	local payload = buffer:sub(pos, pos + payload_len - 1)
	pos = pos + payload_len

	-- Unmask payload if needed
	if masked and mask_key then
		local unmasked = ""
		for i = 1, #payload do
			local byte = string.byte(payload, i)
			local mask_byte = string.byte(mask_key, ((i - 1) % 4) + 1)
			unmasked = unmasked .. string.char(bit.bxor(byte, mask_byte))
		end
		payload = unmasked
	end

	local frame_data = {
		fin = fin,
		opcode = opcode,
		masked = masked,
		payload = payload,
	}

	local remaining = buffer:sub(pos)

	return frame_data, remaining
end

--- Create close frame
---@param code number|nil
---@param reason string|nil
---@return string
function M.create_close_frame(code, reason)
	local payload = ""

	if code then
		payload = num_to_bytes(code, 2)
		if reason then
			payload = payload .. reason
		end
	end

	return M.encode({
		fin = true,
		opcode = M.OPCODE.CLOSE,
		payload = payload,
	})
end

--- Parse close frame payload
---@param payload string
---@return number|nil code
---@return string|nil reason
function M.parse_close_payload(payload)
	if #payload < 2 then
		return nil, nil
	end

	local code = bytes_to_num(payload:sub(1, 2))
	local reason = nil

	if #payload > 2 then
		reason = payload:sub(3)
	end

	return code, reason
end

return M
