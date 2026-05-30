--!optimize 2

const Constants = require("Constants")

const Utils = {}

function Utils.Fill(a, b)
	return if a == nil then b else a
end

do
	const weakKeyMetatable: { read __mode: "k" } = table.freeze({ __mode = "k" :: "k" })
	const weakMetatable: { read __mode: "kv" } = table.freeze({ __mode = "kv" :: "kv" })

	function Utils.GetWeakKeyTable(): setmetatable<{ [any]: any }, typeof(weakKeyMetatable)>
		return setmetatable({}, weakKeyMetatable)
	end

	function Utils.GetWeakTable(): setmetatable<{ [any]: any }, typeof(weakMetatable)>
		return setmetatable({}, weakMetatable)
	end
end

-- function Utils.GetAdressFromId(id: string): string?
-- 	-- "[A...]0x[B...]" -> "[B...]"
-- 	return string.match(id, "0x%x+")
-- end

function Utils.CheckBlacklist(index)
	if Constants.ObjectBlacklistIndex[index] then
		error(`{index} in the blacklist`)
	end
end

function Utils.InsertToTuplePack(tuplePack, value)
	
end

return Utils
