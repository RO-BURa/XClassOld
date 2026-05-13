--!optimize 2

-- Luau에서 편리하게 사용할수있는 클래스 프레임 워크에서 오브젝트를 생성-관리 하는 모듈입니다
-- JS의 오브젝트 시스템을 일부 참고하였으나 내부적으로 살짝 다른 시스템을 가지고 있습니다

-- 패키지들
local TuplePacker = require("../TuplePacker")

-- 유틸들
const Utils = require("Utils")

-- 상수들
const Constants = require("Constants")

-- 내부 TypeTag들
const InternalTypeTags = require("InternalTypeTags")

-- 모듈
const XObject = {}

-- 내부 저장소
const internals = Utils.GetWeakKeyTable() :: { [any]: any }

-- 특정 환경이 어떤 프로토타입에서 시작됬는지 포인트를 일려주는 저장소
const pointedPrototypeNavigation = Utils.GetWeakKeyTable() :: { [any]: any } -- { [environments]: pointedPrototype }

--[=[
[[Access Modifier]]
	Public 0
	Protected 1
	Private 2
]=]


-- XObject가 사용하는 메타테이블
XObject._metatable = {
	__metatable = "The metatable is locked",
}

-- 실제 오브젝트 구현


--[=[
prototype은 Prototype이고 as는 newproxy(true)대신 as를 사용함
as가 존재하는 이유는 XClass에서 클래스 생성할때 그 클래스를 테이블로 사용해야하기 때문임 (freeze된 테이블 { new = 생성자 })
(*참고 XObject는 Internal을 메타테이블로 사용합니다)
]=]
function XObject.new(prototype, as)
	const self = as or newproxy(true)
	-- newproxy(true)로 userdata를 만들수있으나 메타테이블을 지정할수없음
	-- 그렇기에 메타테이블을 internal로도 써서 재활용 할수있음
	const internal = getmetatable(self)

	const uniqueName = tostring(self)

	internal.__id = Utils.GetAdressFromId(uniqueName) or uniqueName

	-- for metamethodName in Constants.MetamethodNames do
	-- 	local value = XObject._metatable[metamethodName]
	-- 	if value ~= nil then
	-- 		internal[metamethodName] = value
	-- 	end
	-- end
	if not table.isfrozen(XObject._metatable) then
		for i in XObject._metatable do
			if not Constants.MetamethodNames[i] then
				error(`{i} is not in the metamethod names`)
			end
		end
		table.freeze(XObject._metatable)
	end

	for i, v in XObject._metatable do
		internal[i] = v
	end

	if prototype then
		internal.__prototype = prototype
	end

	return self
end

-- 내부 반환
function XObject:GetInternal(required: boolean?) 
	const internal = internals[self]
	if required and (internal == nil) then
		error("no internal")
	end
	return internal
end

-- XObject인지 여부
function XObject:IsXObject(): boolean
	return if XObject.GetInternal(self) then true else false
end

-- 오브젝트의 속성을 설정합니다
function XObject:DefineProperty(name, valueOrDescriptor)
	-- check blacklist
	if Constants.ObjectBlacklistIndex[name] then
		error(`{name} is in the blacklist index`)
	end

	const internal = XObject.GetInternal(self, true)

	internal[name] = valueOrDescriptor
end

-- XObject에서 값 구함
function XObject:RawGet(i)
	const internal = XObject.GetInternal(self, true)

	return internal[i]
end

-- XObject에 값 설정함
function XObject:RawSet(i, v)
	const internal = XObject.GetInternal(self, true)

	internal[i] = v
end

-- XObject의 __extends에 대해서 반복
function XObject:PerParent<A..., R...>(callback: (parentPrototype: any, A...) -> R..., ...: A...): ...any
    local extends = XObject.RawGet(self, "__extends")
    if not extends then return nil end

    if type(extends) == "table" then
		if (#(extends)) == 1 then
			extends = extends[1]
		else
			for _, parent in ipairs(extends) do
				local returns = TuplePacker.pack(callback(parent, ...))

				if returns.Len > 0 then
					return TuplePacker.unpack(returns)
				end
			end
			return
		end
    end

	return callback(extends, ...)
end

do
	const function addToQueue(value, queue)
		table.insert(queue, value)
	end

	--[=[
		__extends에 대해서 BFS로 조상들 다 구함
	]=]
	function XObject:PerAncestor<A..., R...>(callback: (ancestorPrototype: any, A...) -> R..., ...: A...): ...any
		const queue = {}
		const visited = {
			[self] = true
		}

		XObject.PerParent(self, addToQueue, queue)

		local head = 1
		while head <= #queue do
			const current = queue[head]
			head += 1

			if not current or visited[current] then continue end
			visited[current] = true

			local returns = TuplePacker.pack(callback(current, ...))

			if returns.Len > 0 then
				return TuplePacker.unpack(returns)
			end

			XObject.PerParent(current, addToQueue, queue)
		end

		return
	end
end

do
	const function collectTypeTags(fromPrototype, typeTags)
		const fromTypeTags = XObject.RawGet(fromPrototype, "__typetags")
		if fromTypeTags then
			for fromTypeTag in fromTypeTags do
				typeTags[fromTypeTag] = true
			end
		end
	end

	function XObject:SetTypeTags()
		const internal = XObject.GetInternal(self, true)

		const typeTags = {
			[internal.__typetag] = true
		}

		XObject.PerParent(self, collectTypeTags, typeTags)

		if next(typeTags) == nil then
			return
		end

		internal.__typetags = typeTags
	end
end

do
	const function addDescendantOnAncestor(ancestorPrototype, descendant)
		local ancestorInternal = XObject.GetInternal(ancestorPrototype)

		const descendants = ancestorInternal.__descendants or {}

		ancestorInternal.__descendants = descendants


		descendants[descendant] = true
	end

	function XObject:AddDescendantOnAncestors()
		XObject.PerAncestor(self, addDescendantOnAncestor, self)
	end
end

function XObject:IsDescendants(descendant)
	const descendants = XObject.RawGet(self, "__descendants")

	if descendants then
		return if descendants[descendant] then true else false
	end
	return false
end

do
	const function finder(ancestorPrototype, index)
		local value = XObject.RawGet(ancestorPrototype, index)

		if value == nil then
			return
		else
			return XObject.RawGet(ancestorPrototype, index)
		end
	end

	function XObject:Fetch(index): any
		const got = XObject.RawGet(self, index)
		if got ~= nil then return got end

		return XObject.PerAncestor(self, finder, index) or nil
	end
end

function XObject:RawName()
	return "XObject: " .. ( XObject.RawGet(self, "__id") or "unknown" )
end

function XObject:GetName()
	const name = XObject.Fetch(self, "__name", true)
	return if type(name) == "function" then name(self) else name or XObject.RawName(self)
end

function XObject:HasTypeTag(typeTag)
	const typeTags = XObject.Fetch(self, "__typetags")

	return if (typeTags and (typeTags[typeTag])) then true else false
end

-- 현재 환경이 pointedPrototype에 접근할수있는 액세스를 구함
function XObject:GetAccess(): number
	const env = (getfenv :: any)(2)

	const pointedPrototype = pointedPrototypeNavigation[env]

	if pointedPrototype then
		if self == pointedPrototype then
			return 2 -- Private
		else
			const descendants = XObject.RawGet(self, "__descendants")
			if descendants and descendants[pointedPrototype] then
				return 1 -- Protected
			end
		end
	end

	return 0 -- Public
end

do
	const enviromentOrigins = Utils.GetWeakKeyTable() -- [ProxyEnv] = OriginalEnv
	const proxyEnvironmentMetatable = {}

	--__index, __newindex, __iter, __len만 구현할 예정

	function proxyEnvironmentMetatable:__index(i)
		const originalEnv = enviromentOrigins[self]

		return originalEnv[i]
	end

	function proxyEnvironmentMetatable:__newindex(i, v)
		const originalEnv = enviromentOrigins[self]

		originalEnv[i] = v
	end

	function proxyEnvironmentMetatable:__iter()
		const originalEnv = enviromentOrigins[self]

		return next, originalEnv, nil
	end

	function proxyEnvironmentMetatable:__len()
		const originalEnv = enviromentOrigins[self]

		return #originalEnv
	end

	const function createProxyEnvironment(env)
		const proxyEnv = table.freeze(
			setmetatable({}, proxyEnvironmentMetatable)
		) -- userdata를 못써서 대용으로 freeze를 사용

		enviromentOrigins[proxyEnv] = env

		return proxyEnv
	end

	function XObject:RunAs(callback, ...)
		const env = getfenv(callback)
		const proxyEnv = createProxyEnvironment(env)

		pointedPrototypeNavigation[proxyEnv] = self

		setfenv(callback, proxyEnv)

		const protectedReturns = TuplePacker.pack( pcall(callback, ...) )

		setfenv(callback, env)
		pointedPrototypeNavigation[proxyEnv] = nil

		if not protectedReturns[1] then
			error(protectedReturns[2])
		end

		return select(2, TuplePacker.unpack(protectedReturns))
	end
end

-- 인덱스가 블랙리스트에 있으면 에러
const function checkBlacklist(index)
	if Constants.ObjectBlacklistIndex[index] then
		error(`{index} in the blacklist`)
	end
end

-- value가 Descriptor인지 boolean 반환
const function isDescriptor<T>(value: T): boolean
	return XObject.IsXObject(value) and XObject.HasTypeTag(value, InternalTypeTags.Descriptor)
end

const function errorIfStrict(xobject, ...)
	const strict = XObject.Fetch(xobject, "__strict")
	if strict then
		error(...)
	end
end

--[[
prototype이 있으면 descriptor을 찾고 막 다 해본다
]]
const function get(self, index)
	checkBlacklist(index)

	const internal = XObject.GetInternal(self, true)

	const prototype = internal.__prototype

	-- 값을 읽을때 AccessModifier정보가 필요합니다
	-- AccessModifier정보는 Descriptor에 포함되어있으며
	-- 어느 방법으로든 AccessModifier정보를 얻을수 없다면 0 (Puiblic)으로 간주합니다

	-- 실제 속성 값은 Prototype에 있지 않고 개체에 존재합니다
	-- Prototype에서 값을 가져오는경우는 Method만 가능합니다

	-- Descriptor는 Prototype에 존재해야 합니다

	-- Prototype에서 Fetch해서 받을수있는 Descriptor의 Value는 단순히 초기값 저장의 목적입니다
	
	-- 메소드의 경우엔 Value엔 원본 함수가, Method에 프록시 함수가 존재합니다

	-- Prototype이 없는 경우엔 Public으로 간주합니다 (애초에 prototype이 없는 개체는 내부적으로만 사용됨)

	const rawValue = internal[index]

	if not prototype then
		return rawValue
	end

	const descriptor = XObject.Fetch(prototype, index)

	if not isDescriptor(descriptor) then
		-- const strict = XObject.Fetch(prototype, "__strict")
		-- if strict then
		-- 	error(`{index} is not a valid member of asdfdsfdsf "asdfdfsdsf"`)
		-- end
		-- return nil
		errorIfStrict(prototype, `{index} is not a valid member of asdfdsfdsf "asdfdfsdsf"`)
		return nil
	end

	-- descriptor은 Descriptor임 (ㄷㄷㄷㄷ)

	const access = XObject.GetAccess(self)

	if XObject.RawGet(descriptor, "Access") <= access then
		-- 접근권한 OK		

		-- 메소드면 Method 반환

		const method = XObject.RawGet(descriptor, "Method")

		if method then
			return method
		end

		-- getter 확인
		const getter = XObject.RawGet(self, "Getter")
		
		if getter then
			return XObject.RunAs(self, getter, self)
		end

		const defaultValue = XObject.RawGet(descriptor, "Value")

		if defaultValue.Value ~= nil then
			return defaultValue
		end

		return rawValue
	else
		errorIfStrict(prototype, `{index} is not a valid member of asdfdsfdsf "asdfdfsdsf"`)
		return nil
	end
end


function XObject._metatable:__index(index): ...any
	const prototype = XObject.RawGet(index, "__prototype")

	local onValue = get(index)
	
	XObject.PerAncestor(prototype, function(ancestorPrototype)
		const getFunction = XObject.RawGet(ancestorPrototype, "__get")

		if getFunction then
			const returns = TuplePacker.pack(XObject.RunAs(ancestorPrototype, getFunction, onValue))

			if returns.Len > 0 then
				onValue = returns[1]
			end
		end
	end)

	return onValue
end

return XObject
