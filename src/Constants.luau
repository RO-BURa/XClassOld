--!optimize 2

local Constants = {}

Constants.EmptyTable = table.freeze({})

Constants.MetamethodNames = table.freeze({
	__index = true,
	__newindex = true,
	__call = true,
	__concat = true,

	__unm = true,
	__add = true,
	__sub = true,
	__mul = true,
	__div = true,
	__idiv = true,
	__mod = true,
	__pow = true,

	__tostring = true,
	__metatable = true,

	__eq = true,
	__lt = true,
	__le = true,

	__len = true,
	__iter = true,

	__gc = true,
})

do
	const objectIndexBlacklist = table.clone(Constants.MetamethodNames)

	objectIndexBlacklist.__prototype = true
	objectIndexBlacklist.__id = true

	objectIndexBlacklist.__descendants = true
	objectIndexBlacklist.__extends = true

	-- objectIndexBlacklist.__environment = true
	
	objectIndexBlacklist.__typetag = true
	objectIndexBlacklist.__typetags = true

	objectIndexBlacklist.__get = true
	objectIndexBlacklist.__set = true
	objectIndexBlacklist.__afterset = true

	objectIndexBlacklist.__strict = true

	objectIndexBlacklist.__name = true
	objectIndexBlacklist.__typeof = true
	objectIndexBlacklist.__ignorecase = true
	objectIndexBlacklist.__stringkeysonly = true

	Constants.ObjectBlacklistIndex = table.freeze(objectIndexBlacklist)
end

table.freeze(Constants)
return Constants
