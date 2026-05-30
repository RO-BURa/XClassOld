const XObject = require("XObject")
const XObjectUtils = require("XObjectUtils")
const InternalTypeTags = require("InternalTypeTags")

const Descriptor = {}

const prototype = XObject.new()
const prototypeInternal = XObject.GetInternal(prototype, true) -- internal 바인딩 ㅋ

prototypeInternal.__name = "Descriptor"
prototypeInternal.__typetag = InternalTypeTags.Kind
prototypeInternal.__strict = true
prototypeInternal.__stringkeysonly = true
prototypeInternal.__ignorecase = true

-- 컨셉이라는 개념을 만들어야할듯
-- 이제 기본적으로 Descriptor을 생성하면 컨셉이 없음
-- 컨셉이 없는경우엔 Public에 일반 속성이 되는거고
-- :method나 :static이나 getter setter 이 4개의 메소드는 컨셉이란걸 부여하고
-- 컨셉 값이 true가 됨
-- 이제 또 컨셉을 지정하려하면 에러나는거지


-- public protected private readonly static는 모디파이어라서 상관없음
-- 단 특수한점이 static에 경우 항상 readonly에 스타일이 기본속성이여야함 (Roblox 스타일을 지키기 위해선 어쩔수없음 ㅠ (Vector3.zero 처럼...))

-- Descriptor 생성후 "type"에 Kind저장, self 반환
function Descriptor.new(kind)
    const self = XObject.new(prototype)
    const internal = XObject.GetInternal(self, true)
    
    internal.type = kind
    
    return self
end

-- Descriptor 생성후 "type"에 Kind저장, "value"에 value 저장, self 반환
function Descriptor.use(kind, value)
    const self = XObject.new(prototype)
    const internal = XObject.GetInternal(self, true)
    
    internal.type = kind
    internal.value = value
    
    return self
end

-- Descriptor 생성후 "method"에 method 저장, self 반환
function Descriptor.method(method)
    const self = XObject.new(prototype)
    const internal = XObject.GetInternal(self, true)
    
    internal.method = method
    
    return self
end

const function checkDescriptor(value)
    if not XObjectUtils.ProtectedHasTypeTag(value, InternalTypeTags.Descriptor) then
        error("not descriptor")
    end
end

-- self의 "Value"에 value저장, self 반환
function prototypeInternal:value(value) -- 원본 주석엔 Descriptor:value였지만 prototypeInternal이 맞는 맥락이라 수정 ㅋ
    checkDescriptor(self)
    const internal = XObject.GetInternal(self, true)

    if internal.Method then
        error("Cannot set value on Method Descriptor")
    end

    internal.value = value
    return self
end

-- self의 "Static"에 true, self반환
function prototypeInternal:static()
    checkDescriptor(self)
    const internal = XObject.GetInternal(self, true)
    if internal.Method then
        error("Static is unabled to method")
    end
    internal.static = true
    return self
end

-- self의 "Readonly"에 true, self 반환
function prototypeInternal:readonly()
    checkDescriptor(self)
    const internal = XObject.GetInternal(self, true)
    internal.readonly = true
    return self
end

-- self의 "Access"에 0, self 반환
function prototypeInternal:public()
    checkDescriptor(self)
    const internal = XObject.GetInternal(self, true)
    internal.access = 0
    return self
end

-- self의 "Access"의 1, self 반환
function prototypeInternal:protected()
    checkDescriptor(self)
    const internal = XObject.GetInternal(self, true)
    internal.access = 1
    return self
end

-- self의 "Access"에 2, self 반환
function prototypeInternal:private()
    checkDescriptor(self)
    const internal = XObject.GetInternal(self, true)
    internal.access = 2
    return self
end

-- self의 "Value"값을 "Getter"로 스왑, self 반환
function prototypeInternal:getter()
    checkDescriptor(self)
    const internal = XObject.GetInternal(self, true)
    internal.getter = internal.Value
    internal.value = nil -- 스왑이니까 기존 Value는 날려줌 ㅋ
    return self
end

-- self의 "Value"값을 "Setter"로 스왑, self 반환
function prototypeInternal:setter()
    checkDescriptor(self)
    const internal = XObject.GetInternal(self, true)
    internal.setter = internal.Value
    internal.value = nil -- 스왑이니까 기존 Value는 날려줌 ㅋ
    return self
end

-- self의 "Method"에 Value의 프록시 함수를 만듬 ("Value"는 유지, 원본 함수가 있음)
function prototypeInternal:method()
    checkDescriptor(self)
    const internal = XObject.GetInternal(self, true)

     if internal.Static then
        error("Static is unabled to method")
    end

    -- "Method" 함수에 첫번째 매개변수를 따로 딱 딱 해야할듯

    if not internal.Method then
        internal.Method = function(...)
            -- 먼저 XClass에서 Descriptor의 특수 속성을 조절해서 해당 Descriptor가 어떤 개체의 Descriptor인지 저장해둘거임
            -- 그 속성 이름은 뭐로하지
            -- Master로 해야겠다
            const master = internal.master

            if not master then
                error("no master")
            end

            do
                -- 암튼 Master에 대한 실행한 환경에 대한 접근 권한
                const access = XObject.GetAccessOfEnvironment(master, (getfenv :: any)(2))

                if (internal.access or 0) > access then
                    XObject.ErrorIfStrict(master, "Cannot access member method due to insufficient protection level")
                    return
                end
            end

            -- 이제 우리가 만들건 ...에서 첫번째 매개변수가 Master의 자손개체인지 뭔지 확인할거

            -- 길이 안구해도됨 왜냐면 길이 0이면 어차피 nil인데 nil이면 당연히 안됨
            -- if numberOfArguments == 0 then
            --     XObject.ErrorIfStrict(master, "Expected ':' not '.' calling member function")
            --     return
            -- end

            -- 첫번째 매개변수는 self일텐데
            -- Public이면 첫번째 매개변수가 자신 클래스의 개체 또는 자손 클래스의 개체
            const firstArgument = ...

            if XObject.IsXObject(firstArgument) then
                const prototype = XObject.RawGet(firstArgument, "__prototype")

                if prototype then
                    const access = XObject.GetAccessOfPrototype(master, prototype)

                    -- 아 생각해보니 이건 개체 확인하는거니깐 Public이여도 Protected처럼 써야함 메소드는 (Descriptor의 필요한 엑세스가 Public이여도 Protected개체여야함)
                    if math.max(internal.access or 0, 1) <= access then
                        -- OK 이 첫번째 argument 개체는 권한이있다 판단

                        -- 잠만 이거 실행할때 RunAs써야할듯
                        -- 근데 RunAs 쓰면 debug에서 그 보안그거 뚫릴텐데 음
                        -- 어차피 RunAs 쓸때 프로토 타입 아니면 의미없긴해

                        return XObject.RunAs(master, internal.Value, ...)
                        -- return internal.Value(...)
                    end
                end

            end

            XObject.ErrorIfStrict(master, "Expected ':' not '.' calling member function")
            return

        end
    end

    return self
end

function prototypeInternal:isreadonly()
    checkDescriptor(self)
    return if XObject.RawGet(self, "readonly") then true else false
end

function prototypeInternal:getaccess()
    checkDescriptor(self)
    return XObject.RawGet(self, "access") or 0
end

function prototypeInternal:canaccess(access)
    -- if (XObject.RawGet(descriptor, "Access") or 0) > access then
	-- 	XObject.ErrorIfStrict(prototype, `{index} is not a valid member of asdfdsfdsf "asdfdfsdsf"`)
	-- 	return nil
	-- end

    return if self:getaccess() > access then false else true
end

-- 앤 Private 메소드
function Descriptor:lock()
    checkDescriptor(self)
    XObject.Lock(self)
end

table.freeze(Descriptor)
return Descriptor