local METAS = setmetatable({}, { __mode = "kv" })

local PrivateObject = {}

function PrivateObject:GetMETA() end

local function new()
	local self = setmetatable({}, { __index = PrivateObject })

	self.METHODS = {}
	self.PRIVATEMETHODS = {}

	return self
end

return table.freeze({
	["new"] = new,
})
