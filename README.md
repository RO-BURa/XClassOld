이거 XClass 예전버전인데 열심히 만든건데 버리게 됬는데 그냥 버리기엔 넘 아까워서 박제합니다.
밑에 텍스트들은 과거 제가 어케 만들지 설게한것들 입니다.

# XClass

XClass는 클래스 프레임워크입니다.
XClass는 속도보단 편리함을 중점으로 만들어졌습니다.

## 사용방법

```luau
const XClass = require(path.to.XClass)
```
저 XClass 모듈은 라이브러리로도 사용함

이렇게 XClass모듈로 XClass개체를 생성할수있음
```luau
XClass.new(생성자, 속성, 설정)
```

생성자는 함수 또는 테이블을 넣을수있음
함수를 넣으면 생성함수가 기본적으로 new로 처리됨
테이블을 넣으면 그 테이블에 따라서 생성 함수를 처리함
nil로 하면 생성 할 수 없는 상속전용 클래스가 되겠지

예시 생성자 테이블
```luau
{ new = function(...) end, fromExisting = function(...) end }
```

속성에는 테이블을 넣을수있는데
키에는 속성이름 값에는 타입이 들어감
기본값이나 세부사항(setter또는 getter, AccessModifier)은 Descriptor이라는 개체를 생성해야함
Descriptor에 타입을 나타내는 Kind라는 개체가 필요함
이 Kind클래스는 XClass.Kind로 구할수있음

### Kind

Kind는 Descriptor에서 타입을 자세하게 표현하기 위한 클래스임

```luau
XClass.Kind.new(Kind.any 또는 타입태그 또는 문자열 또는 함수 또는 클래스...)
```

Kind.any라는 any를 뜻하는 기본 내장 타입 태그가 있음
```luau
const yeahItsAny = XClass.Kind.any
```

타입태그가 무엇이냐면 클래스에서 클래스를 의미하는 타입 개체를 만들때
타입태그라는 오브젝트를 따로 정의하여 그 타입태그로 Kind를 생성한경우 해당 Kind개체가
그 타입태그의 클래스를 의미하게 할수있음

예시: 타입태그로 Kind를 생성하는 코드
```luau
-- 고유 태그 생성
const typeTag1 = newproxy()

-- 지금은 안배우지만 나중에 클래스에 타입태그를 입히는방법이있음
const myXClass = XClass.new(생성자, 속성, 설정) -- 대충 TypeTag가 typeTag1인 클래스 (설정에서 타입태그를 설정가능)

const myKind = XClass.Kind.new(typeTag1) -- 이제 이 Kind는 저 타입태그를 가지고 있는 클래스를 의미함

```

문자열에 경우 클래스마다 따로 TypeOf함수를 설정할수있는데 (기본적으론 이름을 반환하는 XClass 내장 TypeOf함수)
이때 그 TypeOf함수를 실행할때 그의 결과 값과 비교할 문자열이 들어감
TypeOf함수는 클래스에 따로 설정 할 수 있기에 강력한 보안을 원한다면 TypeTag를 이용하는 것을 추천

예시: 문자열로 Kind를 생성하는 코드
```luau
const myKind = XClass.Kind.new("string")
const myKind2 = XClass.Kind.new("MyClass")
```

함수에 경우 따로 검사 함수를 만들수있음
검사함수엔 첫번째 매개변수로 어떤 오브젝트를 검사할지가 들어감
따로 원하는대로 검사 함수를 만들수있음

예시: 검사 함수로 Kind를 생성하는 코드
```luau
const myKind = XClass.Kind.new(function(self)
    return if self == type("string") then true else false
end)
```

클래스로도 Kind를 생성할수있음
말그대로 생성된 Kind는 그 클래스에서 생성된 개체를 의미함

예시: 클래스로 Kind를 생성하는 코드
```luau
const myClass = XClass.new(생성자, 속성, 설정)
const myKind = Kind.new(myClass)
```
#### 메소드

```luau
Kind:contains(검사할 값)
```
검사할 값이 Kind에 포함되는지 검사하는 메소드
포함되면 true 아니면 false (당연하지...)

```luau
Kind:unionof(Kind.any 또는 타입태그 또는 문자열 또는 함수 또는 클래스...)
```
Kind에 여러 다른 조건을 합치는 코드
전부 조건에 맞을 필요는 없고 저중 하나라도 포함된경우 통과임

Kind로 여러 다른조건을 합치는 예시 코드
```luau
const myKind = XClass.Kind.new("boolean"):unionof("number", "string")
```
사실 이 코드보다 아래 코드가 더 같지만 더 효율적임
```luau
const myKind = XClass.Kind.new("boolean", "number", "string")
```

```luau
Kind:negationof(Kind.any 또는 타입태그 또는 문자열 또는 함수 또는 클래스...)
```
말그대로 부정 타입을 추가함

부정 타입을 추가하는 예시 코드
```luau
-- 숫자가 아닌 모든 타입에 대해서 괜찮은 Kind
const noNumberKind = XClass.Kind.new(XClass.Kind.any):negationof("number")
```

```luau
Kind:optional(타겟)
```
그냥
```luau
Kind:unionof(nil)
```
과 같음

타겟을 정할수있는데
기본 타겟은 "components"고 그 외에 "negations"라는 다른 타겟 조정가능함
```luau
-- 셋이 같음
Kind:optional()
Kind:optional("components")
Kind:unionof(nil)

-- 둘이 같음
Kind:optional("negations")
Kind:negationof(nil)
```

두개의 허용된 타겟이 아니면 에러남

### Descriptor

Descriptor은 속성의 세부사항(setter또는 getter, AccessModifier)을 나타내는 개체임



## 예시

### Signal

```luau
미완이다
```

### RobloxStyleObject

```luau
미완이다
```


## 참고

AI 쓰긴 썼는데 모든 로직 전부 제가 구상했고, 미리 프로토타입 코드도 전부 제가 먼저 작성했습니다.
90%의 코드를 제가 작성헀고 AI에게 단순 노가다로 짜야하는 코드 또는
코드의 시스템 또는 스타일 자체를 확 바꿔야 할때 사용했습니다.
