local Bob = {}

function Bob.new(name)
	local self = setmetatable({}, { __index = Bob })

	self.ClassName = "Bob"
	self.Name = name

	return self
end

function Bob:AHH()
	print(`{self.Name}: AHHHHHHHHHHH`)
end

return Bob
