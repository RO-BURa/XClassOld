-- 패키지들
const TuplePacker = require("../TuplePacker")
const noYield = require("../NoYield")

-- 모듈들
const InternalTypeTags = require("InternalTypeTags")
const PrototypeNavigation = require("PrototypeNavigation")
const XObject = require("XObject")
const Utils = require("Utils")
const XObjectUtils = require("XObjectUtils")

-- 테이블에 nil을 Key로 사용할수 없으니 nil에 경우 따로 만들어둔 개체로 대체
const NIL_PROXY = newproxy()

const validTargets = {
    components = true,
    negations = true,
}

-- 값을 테이블에 사용할 키로 변환
const function toKey(value)
    return if value == nil then NIL_PROXY else value
end

-- 테이블의 키를 사용할 값으로 변환
const function toValue(key)
    return if key == NIL_PROXY then nil else key
end

const Kind = {}
const prototype = XObject.new()
const prototypeInternal = XObject.GetInternal(prototype, true)

prototypeInternal.__name = "Kind"
prototypeInternal.__typetag = InternalTypeTags.Kind
prototypeInternal.__typetags = {
    [InternalTypeTags.Kind] = true
}
prototypeInternal.__strict = true
prototypeInternal.__stringkeysonly = true
prototypeInternal.__ignorecase = true

const function checkKind(value)
    if not (XObjectUtils.ProtectedHasTypeTag(value, InternalTypeTags.Kind)) then
        error("not kind")
    end
end

function Kind.new(...)
    const self = XObject.new(prototype)
    const internal = XObject.GetInternal(self, true)

    internal.components = {}
    internal.negations = {}
    internal.parents = Utils.GetWeakKeyTable()

    self:unionof(...)
    -- const stagedComponents = TuplePacker.pack(...)

    -- for i = 1, stagedComponents.Len do
    --     const stagedComponent = stagedComponents[i]
    --     Kind.union(self, stagedComponent, "components")
    -- end
    return self
end

--[[
d
]]
function Kind.as(...)

    const newStagedComponents = TuplePacker.pack()
    const stagedComponents = TuplePacker.pack(...)

    TuplePacker.foreach(stagedComponents, function(i, stagedComponent)
        if XObject.IsXObject(stagedComponent) then
            const stagedComponentPrototype = XObject.RawGet(stagedComponent, "__prototype")

            if stagedComponentPrototype then
                TuplePacker.insert(newStagedComponents, stagedComponentPrototype)
                return
            end
        end

        TuplePacker.insert(newStagedComponents, typeof(stagedComponent))
    end)

    const self = Kind.new(TuplePacker.unpack(newStagedComponents))

    return self
end

-- any를 뜻하는 타입 태그
do
    const ANY = newproxy(true)

    const anyMetatable = getmetatable(ANY)
    anyMetatable.__tostring = "Kind.any"
    anyMetatable.__metatable = "the metatable is locked"

    Kind.any = ANY
end

-- 콤포넌트를 부모(또는 하위 타입)로 등록하고 관계를 전파 ㅋ
function Kind:registerParentAndPropagate(component)
    -- 콤포넌트가 Kind가 아니면 연산 불필요 ㅋ
    if not (XObject.IsXObject(component) and XObject.HasTypeTag(component, InternalTypeTags.Kind)) then
        return
    end

    const internal = XObject.GetInternal(self, true)
    const componentInternal = XObject.GetInternal(component, true)

    -- 네 말대로 component의 조상 중에 self가 이미 있다면 순환이다! ㅋ
    if componentInternal.parents[self] or (self == component) then
        error("Cyclic Kind dependency detected! Union denied.")
    end

    -- self(부모)의 조상 목록에 component(자식)를 등록 ㅋ
    internal.parents[component] = true

    -- component(자식)가 이미 가지고 있던 모든 조상들(자손의 자손들)도 self(부모)에게 상향 전파 ㅋ
    for childAncestor in pairs(componentInternal.parents) do
        internal.parents[childAncestor] = true
    end

    -- self를 조상으로 두고 있는 다른 상위 Kind들이 있다면, 그들에게도 이 새로운 관계를 싹 전파해줌 ㅋ
    for upperKind in pairs(internal.parents) do
        if XObject.IsXObject(upperKind) and XObject.HasTypeTag(upperKind, InternalTypeTags.Kind) then
            const upperInternal = XObject.GetInternal(upperKind, true)
            upperInternal.parents[component] = true
            for childAncestor in pairs(componentInternal.parents) do
                upperInternal.parents[childAncestor] = true
            end
        end
    end
end

-- [Private Method] 단 하나의 개체만 union하는 메소드 (internal 격리 ㅋ)
function Kind:union(component, target)
    if (typeof(component) == "string") and (component ~= "?") and (string.sub(component :: string, -1) == "?") then
        self:optional(target) -- nil은 이 조건문을 통과 못하기때문에 재귀 걱정은 안할듯
        component = string.sub(component :: string, 1, -2)
    end

    -- 중복 코드 걷어내고 위에서 만든 프라이빗 메소드 호출! ㅋ
    Kind.registerParentAndPropagate(self, component)

    const internal = XObject.GetInternal(self, true)
    internal[target][toKey(component)] = true
end

-- [Public Method] unionof
function prototypeInternal:unionof(...)
    checkKind(self)
    const stagedComponents = TuplePacker.pack(...)

    if stagedComponents.Len == 0 then
        return self
    end

    TuplePacker.foreach(stagedComponents, function(_, stagedComponent)
        Kind.union(self, stagedComponent, "components")
    end)

    return self
end

-- [Public Method] negationof
function prototypeInternal:negationof(...)
    checkKind(self)
    const stagedComponents = TuplePacker.pack(...)

    if stagedComponents.Len == 0 then
        return self
    end

    TuplePacker.foreach(stagedComponents, function(_, stagedComponent)
        Kind.union(self, stagedComponent, "negations")
    end)

    return self
end

-- :unionof(nil)
function prototypeInternal:optional(target)
    checkKind(self)
    -- optional은 Public함수이기 때문에 target을 "parents"같은거로 해서 막 악용할수도 있어서
    -- 미리 허용할 target을 미리 정해둬야함
    
    -- Fill(a, b)함수는 a가 nil이면 b 아니면 a라는 간단한 로직을 가진 함수
    target = Utils.Fill(target, "components")

    if not validTargets[target] then
        error("invalid target")
    end
    
    Kind.union(self, nil, target)
end

do
    const defaultTypeOfFunction = typeof

    const function isContainsWith(component, value)
        if component == Kind.any then
            return true
        end

        local typeOfFunction = defaultTypeOfFunction

        if XObject.IsXObject(value) then
            const hasTypeTag = XObject.HasTypeTag(value, component)
            if hasTypeTag then
                return true
            end

            const prototype = XObject.RawGet(value, "__prototype")

            if XObject.IsXObject(component) then
                if prototype then
                    if (prototype == component) or XObject.IsDescendantOf(component, value) then
                        return true
                    end
                end
            end

            -- asComponent를 왜 또 구해서 확인하냐면
            -- 이제 클래스 같은게 들어오면 그 클래스가
            -- PrototypeNavigation에 [클래스]: 그 클래스의 프로토타입
            -- 이런식으로 저장되어있고 그 프로토타입으로 대신 확인을 해보는 기능이 있어야 하기 때문임
            const asComponent = PrototypeNavigation[component]
            if XObject.IsXObject(asComponent) then
                if prototype then
                    if (prototype == asComponent) or XObject.IsDescendantOf(asComponent, value) then
                        return true
                    end
                end
            end

            if XObject.IsXObject(component) then
                if XObject.HasTypeTag(component, InternalTypeTags.Kind) then
                    if component:contains(value) then
                        return true
                    end
                end
                
                const stagedTypeOfFunction = XObject.Fetch(value, "__typeof")
                if stagedTypeOfFunction then
                    typeOfFunction = stagedTypeOfFunction
                end
            end

        end

        if component == typeOfFunction(value) then
            return true
        end

        if type(component) == "function" then
            -- debug로 isContainsWith함수 빼올수있는데 빼와도 뭐 할게 없어서 ㄱㅊ
            const result = noYield(component, value)
            
            if result then
                return true
            end
        end

        if (component == nil) and (value == nil) then
            return true
        end

        return false
    end

    function prototypeInternal:contains(value)
        checkKind(self)
        const internal = XObject.GetInternal(self, true)

        -- 1. 부정(Negations) 확인
        for component in pairs(internal.negations) do
            const rawComponent = toValue(component)
            if isContainsWith(rawComponent, value) then
                return false
            end
        end

        -- 2. 긍정(Components) 확인
        for component in pairs(internal.components) do
            const rawComponent = toValue(component)
            if isContainsWith(rawComponent, value) then
                return true
            end
        end

        return false
    end
end

return Kind