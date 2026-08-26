local Format = {}

function Format.gold(amount: number): string
	local n = math.floor(amount + 0.5)
	local s = tostring(n)
	local result = ""
	while #s > 3 do
		result = "," .. string.sub(s, -3) .. result
		s = string.sub(s, 1, #s - 3)
	end
	return "$" .. s .. result
end

return Format
