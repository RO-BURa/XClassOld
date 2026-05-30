local errorFunctions = {}

local function getErrorFunction<T>(message: T, level: number?)
	if level == nil then
		level = 1
	end

	if not errorFunctions[message] then
		errorFunctions[message] = {}
	end

	if not errorFunctions[message][level] then
		errorFunctions[message][level] = function()
			error(message, level)
		end
	end

	return errorFunctions[message][level]
end

return getErrorFunction
