--!strict
local TypeFunctions = require(script.Parent.TypeFunctions)
local Methods = {}

local INTERNALS = setmetatable({} :: { [any]: any }, { __mode = "kv" })

local PRIVATES = {}

local dd: TypeFunctions.Subtract<"good", "kj">

function PRIVATES.new()
	local self = newproxy(true)
	local self_META = getmetatable(self)
	self_META.__metatable = "The metatable is locked"

	local internal = {}
	INTERNALS[self] = internal

	internal.Methods = {}

	self_META.__index = Methods

	return self, PRIVATES
end

function PRIVATES.AddMethod(self) end

function Methods.AddMethod() end

function Methods.AddMethods() end

table.freeze(PRIVATES)
return table.freeze({
	new = PRIVATES.new,
})
