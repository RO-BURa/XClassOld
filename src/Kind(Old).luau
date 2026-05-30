-- 패키지들
const TuplePacker = require("../TuplePacker")

-- 모듈들
const InternalTypeTags = require("InternalTypeTags")
const PrototypeNavigation = require("PrototypeNavigation")
const XObject = require("XObject")

const Kind = {}

const prototype = XObject.new()

const prototypeInternal = XObject.GetInternal(prototype, true)

const function insertToPack(pack, value)
    pack[pack.Len + 1] = value
    pack.Len += 1
end

prototypeInternal.__name = "Kind"
prototypeInternal.__typetag = InternalTypeTags.Kind
prototypeInternal.__strict = true
prototypeInternal.__stringkeysonly = true
prototypeInternal.__ignorecase = true

const function checkKind(value)
    if not (XObject.IsXObject(value) and XObject.HasTypeTag(value, InternalTypeTags.Kind)) then
        error("not descriptor")
    end
end

function prototypeInternal:unionof(...)
    checkKind(self)
    const stagedComponents = TuplePacker.pack(...)

    if stagedComponents.Len == 0 then
        return
    end

    const internal = XObject.GetInternal(self, true)

    const components = internal.components

    for i = 1, stagedComponents.Len do
        const stagedComponent = stagedComponents[i]
        
        insertToPack(components, stagedComponent)
    end

    return self
end

function prototypeInternal:negationof(...)
    checkKind(self)
    const stagedComponents = TuplePacker.pack(...)

    if stagedComponents.Len == 0 then
        return
    end

    const internal = XObject.GetInternal(self, true)

    const negations = internal.negations

    for i = 1, stagedComponents.Len do
        const stagedComponent = stagedComponents[i]
        
        insertToPack(negations, stagedComponent)
    end

    return self
end

function prototypeInternal:optional()
    checkKind(self)
    self:unionof(nil)
end

do
    --@TODO XClass에서 따로 막 해서 Name 분류하고 막 그런 함수로 바꿀 예정 (typeof는 임시)
    const defaultTypeOfFunction = typeof

    const function isContainsWith(component, value)
        -- "?"는 any라는 뜻이라서 true
        if component == "?" then -- any
            return true
        end

        local typeOfFunction = defaultTypeOfFunction

        -- 타입태그가 존재하는경우 타입 태그가 포함되면 true
        if XObject.IsXObject(value) then
            const hasTypeTag = XObject.HasTypeTag(value, component)

            if hasTypeTag then
                return true
            end

            const prototype = XObject.RawGet(value, "__prototype")

            -- component가 XObject이고 component의 자손들에 value의 프로토타입이 포함되는경우 true
            if XObject.IsXObject(component) then
                if prototype then
                    if (prototype == component) or XObject.IsDescendantOf(component, value) then
                        return true
                    end
                end
            end

            -- 나중에 클래스를 TypeTag처럼 쓰는 기능을 만들거여서
            -- 그 클래스가 PrototypeNavigation에 저장될거임
            -- 추가로 Kind.as()로 프로토토입에서 생성된 개체에서 프로토타입을 추출하여 Kind를 받는 그런 기능도 이 기능을 필요로함
            -- PrototypeNavigation: { [XClass]: Prototype }
            const asComponent = PrototypeNavigation[component]
            if XObject.IsXObject(asComponent) then
                if prototype then
                    if (prototype == asComponent) or XObject.IsDescendantOf(asComponent, value) then
                        return true
                    end
                end
            end

            -- 혹시나 component가 Kind면 component:contains(value)를 해볼것
            if XObject.HasTypeTag(component, InternalTypeTags.Kind) then
                --recordLoop[component] = true
                if component:contains(value) then
                    return true
                end
            end

            const stagedTypeOfFunction = XObject.Fetch(value, "__typeof")

            if stagedTypeOfFunction then
                typeOfFunction = stagedTypeOfFunction
            end
        end

        -- 콤포넌트와 typeOf에 value넣고 반환받은값이 같으면 true
        if component == typeOfFunction(value) then
            return true
        end

        -- 콤포넌트와 value 둘다 nil이면 true
        if (component == nil) and (value == nil) then
            return true
        end

        -- 다 아니면 다르다는거지
        return false
    end

    function prototypeInternal:contains(value)
        checkKind(self)
        -- 콤포넌트들에 nil이 있을수 있어서 for ~ in 안씀

        const negations = XObject.RawGet(self, "negations")
        for i=1, negations.Len do
            const component = negations[i]

           if isContainsWith(component, value) then
                return false
            end
        end

        const components = XObject.RawGet(self, "components")
        for i=1, components.Len do
            const component = components[i]

           if isContainsWith(component, value) then
                return true
            end
        end

        return false
    end
end

function Kind.new(...)

    const self = XObject.new(prototype)

    const internal = XObject.GetInternal(self, true)

    -- TuplePacker말고 딕셔너리로 바꾸고 nil은 따로 프록시 개체 만들면 좋을거같은데
    -- const NIL = newproxy() 처럼
    -- 아오 귀찮아 아오오오

    const components = TuplePacker.pack(...)
    -- new(A...)
    -- unionof(A...)
    internal.components = components -- { A..., Len: number }

    -- negationof(A...)
    internal.negations = TuplePacker.pack() -- { A..., Len: number }

    local optioned = false

    for i = 1, components.Len do
        const component = components[i]

        -- 임시.
        if (typeof(component) == "string") and (component ~= "?") and (string.sub(component, -1) == "?") then
            if not optioned then
                optioned = true
                self:optional()
            end

            components[i] = string.sub(component, 1, -2)
        end
    end

    XObject.SetTypeTags(self)

    return self
end

--@TODO templateXObject에서 prototype있으면 그 prototype에 대한 Kind를 받음
function Kind.as(templateXObject)
    
end

return Kind
