--!optimize 2

-- Luau에서 편리하게 사용할수있는 클래스 프레임 워크에서 오브젝트를 생성-관리 하는 모듈입니다
-- JS의 오브젝트 시스템을 일부 참고하였으나 내부적으로 살짝 다른 시스템을 가지고 있습니다

-- 패키지들
const TuplePacker = require("../TuplePacker")

const Constants = require("Constants")
const Utils = require("Utils")
const InternalTypeTags = require("InternalTypeTags")
const XObjectUtils = require("XObjectUtils")

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

do
	local idCount = 0

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

		-- const uniqueName = tostring(self)

		do
			idCount += 1

			const id = string.format("%x", idCount)

			internal.__id = id
		end

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
end

-- 내부 반환
function XObject:GetInternal(required: boolean?) 
	const internal = internals[self]
	if required and (internal == nil) then
		error("no internal")
	end
	return internal
end

function XObject:Lock()
	table.freeze(XObject.GetInternal(self, true))
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

function XObject:IsDescendantOf(descendant)
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

-- __id는 모든 오브젝트가 가지는 고유 아이디입니다
function XObject:RawName()
	return "XObject: " .. ( XObject.RawGet(self, "__id") or "unknown" )
end

function XObject:HasTypeTag(typeTag)
	const typeTags = XObject.Fetch(self, "__typetags")

	return if (typeTags and (typeTags[typeTag])) then true else false
end

-- prototype이 self에 접근할수 있는 권한에 대해 반환합니다
function XObject:GetAccessOfPrototype(prototype): number
	if prototype and XObject.IsXObject(self) and XObject.IsXObject(prototype) then
		if self == prototype then
			return 2 -- Private
		else
			const descendants = XObject.RawGet(self, "__descendants")
			if descendants and descendants[prototype] then
				return 1 -- Protected
			end
		end
	end

	return 0 -- Public
end

function XObject:GetAccessOfEnvironment(env)
	const pointedPrototype = pointedPrototypeNavigation[env]

	return XObject.GetAccessOfPrototype(self, pointedPrototype)
end

-- 현재 환경이 pointedPrototype에 접근할수있는 액세스를 구함
function XObject:GetAccess(): number
	const env = (getfenv :: any)(2)

	return XObject.GetAccessOfEnvironment(self, env)
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

	proxyEnvironmentMetatable.__metatable = "the metatable is locked"

	function XObject:CreateProxyEnvironment(env)
		const proxyEnv = table.freeze(
			setmetatable({}, proxyEnvironmentMetatable)
		) -- userdata를 못써서 대용으로 freeze를 사용

		enviromentOrigins[proxyEnv] = env

		return proxyEnv
	end

	-- 특정 환경에 포인트합니다
	function XObject:PointEnvironment(env)
		pointedPrototypeNavigation[env] = self
	end

	function XObject:CreatePointedProxyEnvironment(env)
		const proxyEnv = XObject:CreateProxyEnvironment(env)

		pointedPrototypeNavigation[proxyEnv] = self

		return proxyEnv
	end

	function XObjectUtils.ClearPointOnEnvironment(env)
		pointedPrototypeNavigation[env] = nil
	end

	function XObject:RunAs(callback, ...)
		-- 근데 debug로 RunAs뚫린다해도 어차피 실행할 Prototype 못구해서 괜찮을듯?

		const env = getfenv(callback)
		const proxyEnv = XObject.CreatePointedProxyEnvironment(self, env)

		setfenv(callback, proxyEnv)

		const protectedReturns = TuplePacker.pack( pcall(callback, ...) )

		setfenv(callback, env)
		XObjectUtils.ClearPointOnEnvironment(proxyEnv)

		if not protectedReturns[1] then
			error(protectedReturns[2])
		end

		return select(2, TuplePacker.unpack(protectedReturns))
	end
end

function XObject:GetName()
	const prototype = XObject.RawGet(self, "__prototype")
	if prototype then
		const name = XObject.Fetch(prototype, "__name")

		if name ~= nil then

			return if type(name) == "function" then XObject.RunAs(self, name, self) else name
		end
	end
	
	return XObject.RawName(self)
end

-- value가 Descriptor인지 boolean 반환
-- const function isDescriptor<T>(value: T): boolean
-- 	return XObject.IsXObject(value) and XObject.HasTypeTag(value, InternalTypeTags.Descriptor)
-- end

function XObject:ErrorIfStrict(...)
	const strict = XObject.Fetch(self, "__strict")
	if strict then
		error(...)
	end
end

function XObjectUtils.CheckAndHasTypeTag(value, typeTag, errorMessage)
	if XObject.IsXObject(value) and XObject.HasTypeTag(value, typeTag) then return true end
	error(errorMessage or `not has type tag {typeTag}`)
end

function XObjectUtils.ProtectedHasTypeTag(value, typeTag)
	return if XObject.IsXObject(value) and XObject.HasTypeTag(value, typeTag) then true else false
end

--[[
prototype이 있으면 descriptor을 찾고 막 다 해본다
]]
const function get(self, index, enviorment)
	Utils.CheckBlacklist(index)

	const internal = XObject.GetInternal(self, true)

	const prototype = internal.__prototype

	const rawValue = internal[index]

	if not prototype then
		return rawValue
	end

	-- const descriptor = XObject.Fetch(prototype, index)

	-- if not isDescriptor(descriptor) then
	-- 	errorIfStrict(prototype, `{index} is not a valid member of asdfdsfdsf "asdfdfsdsf"`)
	-- 	return nil
	-- end

	const descriptor = XObject.Fetch(prototype, index)

	
	-- if not isDescriptor(descriptor) then
	-- 	errorIfStrict(prototype, `{index} is not a valid member of asdfdsfdsf "asdfdfsdsf"`)
	-- 	return nil
	-- end

	-- Descriptor가 아니면
	if not XObjectUtils.ProtectedHasTypeTag(descriptor, InternalTypeTags.Descriptor) then
		-- nil이면 없는값이라고 에러
		-- 아니면 그 값을 반환 (Descriptor가 아니여도 값을 사용할수 있음 (public 처럼))
		if descriptor == nil then
			XObject.ErrorIfStrict(prototype, `{index} is not a valid member of asdfdsfdsf "asdfdfsdsf"`)
			return nil
		else
			return descriptor
		end
	end

	-- descriptor은 Descriptor임 (ㄷㄷㄷㄷ)

	const access = XObject.GetAccessOfEnvironment(prototype, enviorment)

	-- 엑세스 권한이 없으면
	if (XObject.RawGet(descriptor, "Access") or 0) > access then
		XObject.ErrorIfStrict(prototype, `{index} is not a valid member of asdfdsfdsf "asdfdfsdsf"`)
		return nil
	end

	const method = XObject.RawGet(descriptor, "Method")

	if method then
		return method
	end

	-- getter 확인
	const getter = XObject.RawGet(descriptor, "Getter")
	
	if getter then
		return XObject.RunAs(prototype, getter, self)
	end

	const defaultValue = XObject.RawGet(descriptor, "Value")

	if defaultValue ~= nil then
		return defaultValue
	end

	return rawValue
end

const function setErrorCheck(self, index, value, enviroment)
	Utils.CheckBlacklist(index)

    const internal = XObject.GetInternal(self, true)
    const prototype = internal.__prototype

    if not prototype then
        error("Use RawSet for no prototype xobject")
    end

    -- 1. Descriptor 탐색 (현재 프로토타입 + 조상) ㅋ
    local descriptor = XObject.Fetch(prototype, index)
    if not XObjectUtils.ProtectedHasTypeTag(descriptor, InternalTypeTags.Descriptor) then
    	XObject.ErrorIfStrict(prototype, `{index} is not a valid member of asdfdsfdsf "asdfdfsdsf"`)
		return
    end

    -- 2. Access 및 Readonly 체크 (strict 모드 대응) ㅋ
    const access = XObject.GetAccessOfEnvironment(prototype, enviroment)
    if (XObject.RawGet(descriptor, "Access") or 0) > access then
       	XObject.ErrorIfStrict(prototype, `{index} is not a valid member of asdfdsfdsf "asdfdfsdsf"`)
		return
    end

    if XObject.RawGet(descriptor, "Readonly") == true then
        XObject.ErrorIfStrict(prototype, `Cannot assign to read-only member '{index}'`)
        return
    end

    -- 3. Type 체크 ㅋ
    const kind = XObject.RawGet(descriptor, "Type")
    if kind and (not kind:contains(value)) then
        XObject.ErrorIfStrict(prototype, `expected asdf`)
        return
    end
end

const function set(self, index, value)
    
	const internal = XObject.GetInternal(self)
	const prototype = internal.__prototype
	const descriptor = XObject.Fetch(prototype, index)

    -- 4. Setter/Set 로직 ㅋ
    const setter = XObject.RawGet(descriptor, "Setter")
    if setter then
        -- setter있으면 setter실행
        XObject.RunAs(prototype, setter, self, value)
		return
    end

	-- 값 설정
	internal[index] = value
end

function XObject._metatable:__index(index): ...any
	const prototype = XObject.RawGet(self, "__prototype")

	if prototype then
		const stringKeysOnly = XObject.Fetch(prototype, "__stringkeysonly")

		if stringKeysOnly then
			index = tostring(index)
		end

		const ignoreCase = XObject.Fetch(prototype, "__ignorecase")

		if ignoreCase then
			if type(index) == "string" then
				index = string.lower(index)
			end
		end
	end

	-- 먼저 값을 구한다음 조상 대대로 __get을 구한뒤
	-- __get 있으면 __get을 실행해서 수정된 값을 구하고 그거로 대신 값을 받음
	local onValue = get(self, index, (getfenv :: any)(2))

	if prototype then


		XObject.PerAncestor(prototype, function(ancestorPrototype) -- (캡쳐때문에 함수 재활용 안함)
			const getFunction = XObject.RawGet(ancestorPrototype, "__get")

			if getFunction then
				const returns = TuplePacker.pack(XObject.RunAs(ancestorPrototype, getFunction, index, onValue))

				if returns.Len > 0 then
					onValue = returns[1]
				end
			end
		end)
	end

	return onValue
end

function XObject._metatable:__newindex(index, value)
	-- __index보다 복잡함
	-- 먼저 프로토타입에서 __set 조상 대대로 반복하면서 value를 더 최신값으로 바꾸고
	-- 그 최근에 수정된 그 값으로 set을 실행함



	const internal = XObject.GetInternal(self)
	const prototype = internal.__prototype

	if not prototype then
		error("Use RawSet for no prototype xobject")
	end

	const stringkeysonly = XObject.Fetch(prototype, "__stringkeysonly")

	if stringkeysonly then
		index = tostring(index)
	end

	const ignoreCase = XObject.Fetch(prototype, "__ignorecase")

	if ignoreCase then
		if type(index) == "string" then
			index = string.lower(index)
		end
	end
	
	setErrorCheck(self, index, value, (getfenv :: any)(2))

	XObject.PerAncestor(prototype, function(ancestorPrototype) -- (캡쳐때문에 함수 재활용 안함)
		const getFunction = XObject.RawGet(ancestorPrototype, "__set")

		if getFunction then
			const returns = TuplePacker.pack(XObject.RunAs(ancestorPrototype, getFunction, index, value))

			if returns.Len > 0 then
				value = returns[1]
			end
		end
	end)

	-- 이러면 setter에 (Set에 의한 변조된 값 말하는거 ignoreCase같은거 말고) 원본값이 안가는게 마음에 안든다 생각할수도 있는데
	-- 어차피 그 setter도 값 수정하려면 다른값 수정해야해서 ㄱㅊㄱㅊ
	set(self, index, value)
end

function XObject._metatable:__tostring()
	return XObject.GetName(self)
end

return XObject
