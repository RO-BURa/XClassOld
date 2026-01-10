local PrivateObject = {}

local METAS = setmetatable({}, { __mode = "kv" })

function PrivateObject.GetMETA(self)
	local META = METAS[self]

	if META then
		return META
	else
		error("No meta", 0)
	end
end

local function new()
	local self = setmetatable({}, { __index = PrivateObject })

	self.METHODS = {}
	self.PRIVATEMETHODS = {}

	return self
end

return table.freeze({
	["new"] = new,
})
