-- const XClass = 1 :: any
const XClass, Descriptor, Kind = ...

-- 대충 시그널 모듈
const XSignal = XClass.new()

-- Roblox 스타일의 오브젝트 (상속해서 사용)
const RobloxStyleObject = XClass.new(nil, {
    Signals = Kind.use(Kind.table, {}):readonly():private(),
    GetPropertyChangedSignal = Kind.value(function(self, property)
        if not self.Signals[property] then
            self.Signals[property] = XSignal.new()
        end
        return self.Signals[property]
    end):method(),
}, {
    AfterSet = function(self, index, value)
        const signal = self.Signals[index]
        if signal then
            signal:Fire(value)
        end
    end,

    LockExtends = true,
})