--!strict
local TypeFunctions = require(script.Parent.TypeFunctions)

local Methods = {}

local METAS = setmetatable({} :: { [any]: any }, { __mode = "kv" })

local function getMETA(self)
	return METAS[self]
end

local PRIVATES = {}

function PRIVATES.new()
	local internal = {}

	local self = newproxy(true)
	local self_META = getmetatable(self)

	self_META.Self = self
	self_META.Internal = internal

	self_META.__metatable = "The metatable is locked"

	METAS[self] = self_META

	internal.Methods = {}

	self_META.__index = Methods

	return self, PRIVATES
end

function PRIVATES.AddMethod(self) end

table.freeze(PRIVATES)
return table.freeze({
	new = PRIVATES.new,
})
