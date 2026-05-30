local Descriptor = require(script.Parent.Descriptor)
local InternalTypeTags = require(script.Parent.InternalTypeTags)
local Kind = require(script.Parent.Kind)
const Constants = require("Constants")
const Utils = require("Utils")
const XObject = require("XObject")

const XClass = {}

const defaultConfigurations = {

}

--[[
    -- 프로토타입에 실제로 입력되는 설정들
    Name = string | (T) -> (string), -- __name
    TypeOf = <T>(T) -> (string, ...any)?, -- __typeof
    Get = <T>(self, index, onValue) -> (T, ...any)?, -- __get
    Set = <T>(self, index, value) -> (T, ...any)?, -- __set
    IgnoreCase = boolean?, -- __ignorecase
    Strict = boolean?, -- __strict
    IgnoreCase = boolean?, -- __ignorecase
    StringKeysOnly = boolean?, -- __stringkeysonly
    Extends = 클래스 | {클래스}?, -- __extends
]]

const prototype = XObject.new()
const prototypeInternal = XObject.GetInternal(prototype, true)

do
    -- const function getSelf()
    --     -- XObject.new에서 getmetatable()로 메타테이블 구해야해서 메타테이블 따로 생성
    --     const self = setmetatable({}, {})

    --     table.freeze(self)

    --     return self
    -- end

    function XClass.new(constructor, properties, configurations)
        -- constructor는 그냥 말그대로 constructor
        -- ++수정된 constructor을 여러개로도 가능하게 할거
        -- 함수 외에도
        -- { new = 함수, fromExisting = 함수 } 이런식으로 여러개 딱 하는거지
        -- properties는 속성 { ["속성"] = Descriptor }
        -- properties에서 내부 처리할때 Descriptor 아니면 Descriptor.new(값)으로 재처리 하고 저장
        --[[
        configurations은 테이블(선택)
        내부구조 :
        {
            Extends(선택 nil): { 클래스 } | 클래스, -- 상속임 그게다임 (__extends)

            TypeTag(선택 nil): any, -- 타입 태그 -- Descriptor에서 구분용으로 사용할수있음 서로가 서로의 클래스를 참조해야 하는 경우 사용됨 (__typetag)

            -- 밑에 두 함수는 반환값의 길이가 1이상인 경우 첫번째 반환값이 값으로 수정됩니다
            Get(선택 nil): 함수, -- Get을 감지하거나 Get의 값을 수정 할 수 있는 함수 (__get)
            Set(선택 nil): 함수, -- Set을 감지하거나 Set의 값을 수정 할 수 있는 함수 (__set)

            Strict(선택 true): boolean, -- 엄격함 여부

            Name(선택 nil): string 또는 함수 (그외도 되긴 하는데 tostring하면 에러날거), -- 함수면 __tostring처럼 작동하고 아닌경우 그냥 Name을 반환함

            TypeOf(선택 nil): 함수, -- 기본 TypeOf 함수 대신 사용하는 함수

            IgnoreCase(선택 true): boolean, -- 단어 대소문자 구분 무시 여부

            StringKeysOnly(선택 false): boolean, -- 키에 문자열만 되는지 여부

            LockExtends(선택 false): boolean, -- 생성후 상속 막는지 여부 (이건 XClass의 Prototype에 영향이 안가는 유일한 설정)
        }(선택)
        ]]

        if configurations == nil then
            configurations = Constants.EmptyTable
        end

        const ignoreCase = rawget(configurations, "IgnoreCase")
        const stringKeysOnly = rawget(configurations, "StringKeysOnly")

        const newProperties = {}

        for i, v in pairs(properties) do
            
            if type(i) == "string" then
                if ignoreCase then
                    const loweredString = string.lower(i)

                    if newProperties[loweredString] then
                        error(`multiple properties detected at property "{loweredString}"`)
                    end

                    i = loweredString
                end
            elseif stringKeysOnly then
                error(`not string key property "{i}"`)
            end

            Utils.CheckBlacklist(i)

            if newProperties[i] then
                error(`duplicated index "{i}"`)
            end

            -- Descriptor가 아니면
            if not (XObject.IsXObject(v) and XObject.HasTypeTag(v, InternalTypeTags.Descriptor)) then
                -- Kind가 아니면
                if not (XObject.IsXObject(v) and XObject.HasTypeTag(v, InternalTypeTags.Kind)) then
                    v = Kind.new(v)
                end
                v = Descriptor.new(v)
            end

            newProperties[i] = v
        end
        
        -- 2번째 매개변수는 as라고 newproxy()에서 얻을수있는 userdata 대신 사용함
        -- self값 수정은 rawset으로
        const self = XObject.new(prototype, setmetatable({}, {}))
        const internal = XObject.GetInternal(self, true)

        -- Class에서 생성된 개체가 사용하는 오브젝트
        internal.Prototype = XObject.new()
        internal.PrototypeInternal = XObject.GetInternal(self)
        --const selfPrototypeInternal = XObject.GetInternal(internal.Prototype)

        for i, v in newProperties do
            internal.PrototypeInternal[i] = v
        end

        internal.PrototypeInternal.__ignorecase = ignoreCase
        internal.PrototypeInternal.__stringkeysonly = stringKeysOnly

        -- 이제 self 수정못하게 얼림
        table.freeze(self)
        return self

    end
end

return XClass
