local Newproxy = require("./Newproxy")
local NoYield = require("./NoYield")

local Utils = require("@self/Utils")

local XClass = {}
XClass.Metatable = {}

XClass.ProxyInternals = Utils.GetWeakKeyTable()

XClass.Selfs = Utils.GetWeakTable()

type NavigationInfo = {
	AncestorLevel: number,
	Name: any,
	Value: (...any) -> ...any,
}

function XClass.new(...)
	local len = select("#", ...) -- len of tuple
	local arguments = { ... }
	local superXClasses = {}

	for i = 1, len do
		local superXClass = arguments[i]

		if not XClass.IsXClass(superXClass) then
			error("xclass아님")
		end

		superXClasses[superXClass] = superXClass
	end

	local self = {}
	XClass.Selfs[self] = self

	self.SuperXClasses = superXClasses
	self.SubXClasses = {}

	self.Internal = {
		Components = {
			Properties = {
				Public = {},
				Private = {},
			},
			Methods = {
				Public = {},
				Private = {},
			},
		},
	}

	self.Internals = Utils.GetWeakKeyTable()

	self.Properties = Newproxy.new(function(metatable) end)

	self.Methods = Newproxy.new(function(metatable)
		function metatable:__newindex(index, value) end
	end)

	self.Private = {}

	self.Navigations = {
		Properties = {
			Public = {},
			Private = {},
		},
		Methods = {
			Public = {},
			Private = {},
		},
	}

	XClass.AddNavigationsPerComponents(self)
	XClass.AddNavigationsFromAncestor(self)

	return self
end

function XClass.GetSecurityName(isPrivate: boolean)
	return if isPrivate then "Private" else "Public"
end

function XClass.SetNavigation(at, componentName, component, level)
	if at[componentName].AncestorLevel < level then
		return
	end
	if component == nil then
		error("You cant set component to nil")
		--at[componentName] = nil
	else
		at[componentName] = {
			AncestorLevel = level,
			Name = componentName,
			Value = component,
		} :: NavigationInfo
	end
end

function XClass.AddNavigations(from, at, level)
	for componentName, component in from do
		XClass.SetNavigation(at, componentName, component, level)
	end
end

function XClass:IsXClass()
	return if XClass.Selfs[self] then true else false
end

function XClass:AddNavigationsPerComponents(level: number?)
	level = level or 0

	for componentName, publicAndPrivate in self.Internal.Components do
		for securityName, components in publicAndPrivate do
			XClass.AddNavigations(components, self.Navigations[componentName][securityName], level)
		end
	end
end

-- check
function XClass:AddNavigationsFromAncestor(ancestor, level: number?)
	ancestor = ancestor or self
	level = level or 0

	if ancestor ~= self then
		-- for componentName, publicAndPrivate in ancestor.Internal.Components do
		-- 	for securityName, components in publicAndPrivate do
		-- 		XClass.AddNavigations(components, self.Navigations[componentName][securityName], level)
		-- 	end
		-- end
		XClass.AddNavigationsPerComponents(ancestor, level)
	end

	--XClass.AddNavigations(self)

	for _, superXClass in ancestor.SuperXClasses do
		XClass.AddNavigationsFromAncestor(self, superXClass, level + 1)
	end
end

function XClass:AddNavigationOnDescendants(descendants, componentName, securityName, name, method, level)
	level = level or 0
end

-- function XClass:AddNavigationsOnDescendants(descendants, level: number?)
-- 	descendants = descendants or self
-- 	level = level or 0

-- 	if descendants ~= self then
-- 		XClass.AddNavigationsPerComponents(self, descendants, level)
-- 	end

-- 	for _, subXClass in self.SubXClasses do

-- 	end
-- end

function XClass.GetAddComponentFunction(componentName)
	return function(self, name, method, isPrivate: boolean)
		local securityName = XClass.GetSecurityName(isPrivate)

		self.Internal.Components[componentName][securityName][name] = method

		XClass.AddNavigationOnDescendants(self, componentName, securityName, name, method)
	end
end

XClass.AddProperty = XClass.GetAddComponentFunction("Properties")
XClass.AddMethod = XClass.GetAddComponentFunction("Methods")

-- function XClass:AddProperty(name, checker, isPrivate: boolean?)
-- 	-- local internal = self.Internal
-- 	-- local securityName = if isPrivate then "Private" else "Public"
-- 	-- local properties = internal.Components.Properties[securityName]

-- 	-- properties[name] = checker
-- end

-- function XClass:AddMethod(name, method, isPrivate: boolean?)
-- 	-- local internal = self.Internal
-- 	-- local methods = if isPrivate then internal.Private.Methods else internal.Methods

-- 	-- methods[name] = method

-- 	-- XClass.AddNavigationOnDescendants(self, name, method)

-- 	local securityName = XClass.GetSecurityName(isPrivate)

-- 	self.Internal.Components.Methods[securityName][name] = method

-- end

function XClass:AddSubXClass(subXClass)
	self.SubXClasses[subXClass] = subXClass
	XClass.AddNavigationsFromAncestor(subXClass)
end

return table.freeze({
	new = XClass.new,
})
