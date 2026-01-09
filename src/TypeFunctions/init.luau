export type function Subtract(T: type, U: type)
	local negationOfU = types.negationof(U)

	return types.intersectionof(T, negationOfU)
end

return nil
