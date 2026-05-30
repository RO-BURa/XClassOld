local Utils = {
	GetErrorFunction = require("@self/GetErrorFunction"),
}

local weakKeyMetatable: { read __mode: "k" } = table.freeze({ __mode = "k" })
local weakMetatable: { read __mode: "kv" } = table.freeze({ __mode = "kv" })

function Utils.GetWeakKeyTable(): setmetatable<{}, typeof(weakKeyMetatable)>
	return setmetatable({}, weakKeyMetatable)
end

function Utils.GetWeakTable(): setmetatable<{}, typeof(weakMetatable)>
	return setmetatable({}, weakMetatable)
end

return Utils
