--!native
--!optimize 2
--[[
    Dynamo 
    [ V1.1.2 ]
    [ by Elentium ]
    [ Apache-2.0 license ]

    Optimized schemaless SerDes library

    Successor to VoidSentry2 dynamic serialization

    Wally: 
    ```
    Dynamo = "elentium/dynamo@1.1.2"
    ```

    Pesde:
    ```
    pesde add elentium/dynamo
    ```

    Npm:
    ```
    npm install @elentium/dynamo
    ```

    Github: https://github.com/Elentium/Dynamo
    Docs: https://elentium.github.io/Dynamo
]]
----------------------------------------------------
-- CONSTANTS
----------------------------------------------------
const WriteBufferSize = 1_000_000
local SerInstanceSerialization = false
local DoMapCompute = true -- if true, will compute the map length for more precise type assignment, if false, the infer function will default to Map (65535 elements max)
local InstanceRefMode = "Normal" :: "Normal" | "Extended" -- Normal = 2 bytes, Extended = 3 bytes
const InstanceRefAttribute = "_VSID"
-- with normal there must only be < 2 ^ 16 instances
-- with extended there must only be < 2 ^ 24 instances
local UseQuaternion = true
local QuantizedScaleMax = 1
local QuantizedScaleMin = 0

----------------------------------------------------
-- TYPE SIGNS
----------------------------------------------------
const U8 = 1
const I8 = 2
const U16 = 3
const I16 = 4
const U24 = 5
const I24 = 6
const U32 = 7
const I32 = 8
const F32 = 9
const F64 = 10
const Str = 11
const Str8 = 12
const Str24 = 13
const Bool = 14
const Array = 15
const Array8 = 16
const Array24 = 17
const Map = 18
const Map8 = 19
const Map24 = 20
const Buf = 21
const Buf8 = 22
const Buf24 = 23
const Vec = 24
const Void = 25
const Nil = 26
const Cframe = 27
const RefInstance = 28
const SerInstance = 29
local Inst = SerInstanceSerialization and SerInstance or RefInstance
const Color = 30
const Udim2 = 31
const Udim = 32
const Vec2 = 33
const EnumItem = 34
const EnumType = 35
const U40 = 36
const I40 = 37
const U48 = 38
const I48 = 39
const QCframe = 40
local Cf = UseQuaternion and QCframe or Cframe

const NumTypes = 40

----------------------------------------------------
-- TYPES
----------------------------------------------------
export type Ser = (any) -> ()
export type Des = () -> any

export type Constants = "SerInstanceSerialization" | "DoMapCompute" | "InstanceRefMode" | "UseQuaternion" | "QuantizedScaleMin" | "QuantizedScaleMax"

export type Lib = {
    read Serialize: (...any) -> buffer,
    read SerializeWOffset: (Offset: number, ...any) -> buffer,
    read Serialize1: (Value: any) -> buffer,
    read Serialize1WOffset: (Value: any, Offset: number) -> buffer,
    
    read Deserialize: (Buf: buffer) -> ...any,
    read Deserialize1: (Buf: buffer) -> (any, number),
    read DeserializeRange: (Buf: buffer, Start: number, End: number?) -> ...any,
    read Deserialize1WOffset: (Buf: buffer, Offset: number) -> (any, number),

    read Push: (Buf: buffer, Offset: number, ...any) -> number,
    read Push1: (Buf: buffer, Offset: number, Value: any) -> number,

    read SetWriteBufferSize: (Size: number) -> (),
    read DefineSerInstanceSchema: (ClassName: string, Schema: { [string]: number }) -> (),

    read SetConstant: (Constant: Constants, Value: any) -> (),
    read Restore: () -> (),

    read Types: {
        read U8: number,
        read I8: number,
        read U16: number,
        read I16: number,
        read U24: number,
        read I24: number,
        read U32: number,
        read I32: number,
        read F32: number,
        read F64: number,
        read Str: number,
        read Str8: number,
        read Str24: number,
        read Bool: number,
        read Array: number,
        read Array8: number,
        read Array24: number,
        read Map: number,
        read Map8: number,
        read Map24: number,
        read Buf: number,
        read Buf8: number,
        read Buf24: number,
        read Vec: number,
        read Void: number,
        read Nil: number,
        read Cframe: number,
        read QCframe: number,
        read RefInstance: number,
        read SerInstance: number,
        read Color: number,
        read Udim2: number,
        read Udim: number,
        read Vec2: number,
        read EnumItem: number,
        read EnumType: number,
        read U40: number,
        read I40: number,
        read U48: number,
        read I48: number,
    }
}

----------------------------------------------------
-- LOCALIZED BUILTINS
----------------------------------------------------
const TableCreate = table.create
const Next = next
const TablePack = table.pack
const Vector2New = Vector2.new
const CFrameNew = CFrame.new
const Color3New = Color3.fromRGB
const UDimNew = UDim.new
const UDim2New = UDim2.new
const InstanceNew = Instance.new
const TaskSpawn = task.spawn
const TaskDelay = task.delay
const CoroutineRunning = coroutine.running
const CoroutineYield = coroutine.yield
const Pcall = pcall
const TableSort = table.sort
const Freeze = table.freeze

----------------------------------------------------
-- SERVICES
----------------------------------------------------
const RunService = game:GetService("RunService")

----------------------------------------------------
-- MODULE
----------------------------------------------------
--- Efficient schemaless buffer serialization.
---
--- Pass values directly to serialize/deserialize APIs. Dynamo infers compact
--- wire types at runtime (numbers, strings, buffers, tables, Vector3, CFrame,
--- Color3, UDim/UDim2, Enums, Instance refs, and more).
---
--- @class Dynamo
const Dynamo = {}
const Types = {}
Dynamo.Types = Types
const SerHandlers: { [string]: Ser }  = {}
const Ser = TableCreate<<Ser>>(NumTypes)
const Des = TableCreate<<Des>>(NumTypes)

----------------------------------------------------
-- VARIABLES
----------------------------------------------------
local WriteBuffer = buffer.create(WriteBufferSize)
local WBSize = WriteBufferSize
const SafeCopy = WriteBuffer
local Cursor = 0
local ReadBuffer: buffer? = nil
const SerInstance_Keys: { [string]: { string } } = {}
const SerInstance_Ser: { [string]: { Ser } } = {}
const SerInstance_Des: { [string]: { Des } } = {}
const SerInstance_Ids: { [string]: number } = {}
const SerInstance_Reverse: { [number]: string } = {}
local SerInstanceSchemaCount = 0
const IdMap = setmetatable({} :: { [number]: Instance }, { __mode = "v" })
const InstanceMap = setmetatable({} :: { [Instance]: number }, { __mode = "k" })
const EnumMap: { [Enum]: number } = {}
const EnumIdMap: { [number]: Enum } = Enum:GetEnums()

local QuantizedScaleRange = QuantizedScaleMax - QuantizedScaleMin
local QuantizedScaleToU16 = 1 / (65535 / QuantizedScaleRange)
local QuantizedScaleFromU16 = QuantizedScaleRange / 65535

const Reciprocal = 1 / 255

const ConstantsMap = {
    SerInstanceSerialization = "boolean",
    DoMapCompute = "boolean",
    InstanceRefMode = "string",
    UseQuaternion = "boolean",
    QuantizedScaleMin = "number",
    QuantizedScaleMax = "number"
}

----------------------------------------------------
-- API
----------------------------------------------------
--- Serializes one or more values into a new exactly sized buffer.
---
--- Each value is prefixed with a type tag.
--- @tag Core
--- @param ... any -- Values to serialize, in order.
--- @return buffer
function Dynamo.Serialize(...: any): buffer
    Cursor = 0
    const Input = TablePack(...)
    for Index = 1, Input.n do
        const Value = Input[Index]
        SerHandlers[typeof(Value)](Value)
    end

    const Cur = Cursor
    const Buf = buffer.create(Cur)
    buffer.copy(Buf, 0, WriteBuffer, 0, Cur)
    return Buf
end

--- Serializes values into a new buffer after a zero-filled prefix.
---
--- Writing starts at `Offset`. The returned buffer length equals the final
--- cursor (including the reserved prefix). Fill the leading bytes yourself.
--- @tag Core
--- @param Offset number -- Byte offset where the payload begins.
--- @param ... any -- Values to serialize, in order.
--- @return buffer
function Dynamo.SerializeWOffset(Offset: number, ...: any): buffer
    Cursor = Offset
    const Input = TablePack(...)
    for Index = 1, Input.n do
        const Value = Input[Index]
        SerHandlers[typeof(Value)](Value)
    end

    const Cur = Cursor
    const Buf = buffer.create(Cur)
    buffer.copy(Buf, 0, WriteBuffer, 0, Cur)
    return Buf
end

--- Serializes a single value into a new exactly sized buffer.
--- @tag Core
--- @param Value any -- Value to serialize.
--- @return buffer
function Dynamo.Serialize1(Value: any): buffer
    Cursor = 0
    SerHandlers[typeof(Value)](Value)

    const Cur = Cursor
    const Buf = buffer.create(Cur)
    buffer.copy(Buf, 0, WriteBuffer, 0, Cur)
    return Buf
end

--- Serializes a single value after a zero-filled prefix.
--- @tag Core
--- @param Value any -- Value to serialize.
--- @param Offset number -- Byte offset where the payload begins.
--- @return buffer
function Dynamo.Serialize1WOffset(Value: any, Offset: number): buffer
    Cursor = Offset
    SerHandlers[typeof(Value)](Value)

    const Cur = Cursor
    const Buf = buffer.create(Cur)
    buffer.copy(Buf, 0, WriteBuffer, 0, Cur)
    return Buf
end

--- Deserializes every top-level value from the start of a buffer to its end.
--- @tag Core
--- @param Buf buffer -- Buffer containing encoded values.
--- @return ...any
function Dynamo.Deserialize(Buf: buffer): ...any
    Cursor = 0
    ReadBuffer = Buf

    const Len = buffer.len(Buf)
    local Resultc = 0
    const Result = {}

    while Cursor < Len do
        const Cur = Cursor
        const Id = buffer.readu8(Buf, Cur)
        Cursor = Cur + 1
        const Read = Des[Id]
        Resultc += 1
        Result[Resultc] = Read()
    end
    ReadBuffer = nil

    return table.unpack(Result, 1, Resultc)
end

--- Deserializes top-level values while the cursor is in `[Start, End)`.
---
--- `End` defaults to `buffer.len(Buf)`.
--- @tag Core
--- @param Buf buffer -- Buffer containing encoded values.
--- @param Start number -- Byte offset at which reading begins.
--- @param End number? -- Exclusive end offset. Defaults to buffer length.
--- @return ...any
function Dynamo.DeserializeRange(Buf: buffer, Start: number, End: number?): ...any
    Cursor = Start
    ReadBuffer = Buf

    local Resultc = 0
    const Result = {}

    const Max = End or buffer.len(Buf)

    while Cursor < Max do
        const Cur = Cursor
        const Id = buffer.readu8(Buf, Cur)
        Cursor = Cur + 1
        const Read = Des[Id]
        Resultc += 1
        Result[Resultc] = Read()
    end
    ReadBuffer = nil
    
    return table.unpack(Result, 1, Resultc)
end

--- Deserializes a single top-level value from the start of a buffer.
--- @tag Core
--- @param Buf buffer -- Buffer containing an encoded value.
--- @return any -- Decoded value.
--- @return number -- Cursor after the value (next unread offset).
function Dynamo.Deserialize1(Buf: buffer): (any, number)
    Cursor = 0
    ReadBuffer = Buf

    const Cur = Cursor
    const Id = buffer.readu8(Buf, Cur)
    Cursor = Cur + 1
    const Read = Des[Id]
    const Result = Read()
    ReadBuffer = nil
    return Result, Cursor
end

--- Deserializes a single top-level value beginning at a byte offset.
--- @tag Core
--- @param Buf buffer -- Buffer containing an encoded value.
--- @param Offset number -- Byte offset at which reading begins.
--- @return any -- Decoded value.
--- @return number -- Cursor after the value (next unread offset).
function Dynamo.Deserialize1WOffset(Buf: buffer, Offset: number): (any, number)
    Cursor = Offset
    ReadBuffer = Buf

    const Cur = Cursor
    const Id = buffer.readu8(Buf, Cur)
    Cursor = Cur + 1
    const Read = Des[Id]
    const Result = Read()
    ReadBuffer = nil
    return Result, Cursor
end

--- Writes one or more values into an existing buffer and returns the new cursor.
---
--- If a push errors mid-write, call `Restore` so the internal scratch buffer
--- is reset.
--- @tag Core
--- @param Buf buffer -- Destination buffer (must already be large enough).
--- @param Offset number -- Byte offset at which writing begins.
--- @param ... any -- Values to serialize, in order.
--- @return number -- Cursor after the write.
function Dynamo.Push(Buf: buffer, Offset: number, ...: any): number
    const WB = WriteBuffer
    WriteBuffer = Buf

    Cursor = Offset
    const Input = TablePack(...)
    for Index = 1, Input.n do
        const Value = Input[Index]
        SerHandlers[typeof(Value)](Value)
    end

    WriteBuffer = WB
    return Cursor
end

--- Writes a single value into an existing buffer and returns the new cursor.
---
--- If a push errors mid-write, call `Restore` so the internal scratch buffer
--- is reset.
--- @tag Core
--- @param Buf buffer -- Destination buffer (must already be large enough).
--- @param Offset number -- Byte offset at which writing begins.
--- @param Value any -- Value to serialize.
--- @return number -- Cursor after the write.
function Dynamo.Push1(Buf: buffer, Offset: number, Value: any): number
    const WB = WriteBuffer
    WriteBuffer = Buf

    Cursor = Offset
    SerHandlers[typeof(Value)](Value)

    WriteBuffer = WB
    return Cursor
end

--- Restores the internal write scratch buffer after a failed `Push` / `Push1`.
--- @tag Core
function Dynamo.Restore()
    WriteBuffer = SafeCopy
end

--- Replaces the reusable serialization scratch buffer with a new capacity.
---
--- The default capacity is 1,000,000 bytes. Existing content up to the previous
--- size is copied when possible.
--- @tag Core
--- @param Size number -- New scratch-buffer size in bytes.
function Dynamo.SetWriteBufferSize(Size: number)
    const Buf = buffer.create(Size)
    buffer.copy(Buf, 0, WriteBuffer, 0, WBSize)
    WriteBuffer = Buf
    WBSize = Size
end

--- Registers a property schema for value-style instance serialization (`SerInstance`).
---
--- Schema values are type-tag ids from `Dynamo.Types` (for example
--- `Dynamo.Types.Vec`). Property payloads are untagged (the schema
--- already names the type). Up to 255 schemas may be registered.
--- @tag Core
--- @param ClassName string -- Instance `ClassName` this schema applies to.
--- @param Schema { [string]: number } -- Property name → type tag id map.
function Dynamo.DefineSerInstanceSchema(ClassName: string, Schema: { [string]: number })
    local Idx = 0
    const Keys = {}
    for Key in Schema do
        Idx += 1
        Keys[Idx] = Key
    end
    TableSort(Keys)
    
    const SerStruct = TableCreate<<Ser>>(Idx)
    const DesStruct = TableCreate<<Des>>(Idx)
    for i, Key in Keys do
        const Id = Schema[Key]
        SerStruct[i] = Ser[Id]
        DesStruct[i] = Des[Id]
    end
    SerInstance_Ser[ClassName] = SerStruct
    SerInstance_Des[ClassName] = DesStruct
    SerInstance_Keys[ClassName] = Keys
    SerInstanceSchemaCount += 1
    if SerInstanceSchemaCount > 255 then
        error("Exceeded Max allowed SerInstance schema definitions(255)")
    end
    SerInstance_Ids[ClassName] = SerInstanceSchemaCount
    SerInstance_Reverse[SerInstanceSchemaCount] = ClassName
end

--- Replaces a runtime configuration constant that affects inference / wire layout.
---
--- Valid names: `SerInstanceSerialization`, `DoMapCompute`, `InstanceRefMode`,
--- `UseQuaternion`, `QuantizedScaleMin`, `QuantizedScaleMax`.
--- Changing `SerInstanceSerialization` or `UseQuaternion` updates which type tag
--- Instances / CFrames use on subsequent serialize calls.
--- @tag Core
--- @param Constant Constants -- Constant name.
--- @param Value any -- New value (`boolean`, `string`, or `number` as required).
function Dynamo.SetConstant(Constant: Constants, Value: any)
    const Type: string = ConstantsMap[Constant]
    if not Type then
        error("Invalid constant")
    end

    const VType = type(Value)
    if VType ~= Type then
        error("Invalid constant input type; expected " .. Type .. " got "  .. VType)
    end

    if Constant == "DoMapCompute" then
        DoMapCompute = Value
    elseif Constant == "InstanceRefMode" then
        InstanceRefMode = Value
    elseif Constant == "QuantizedScaleMax" then
        QuantizedScaleMax = Value
        QuantizedScaleRange = QuantizedScaleMax - QuantizedScaleMin
        QuantizedScaleToU16 = 1 / (65535 / QuantizedScaleRange)
        QuantizedScaleFromU16 = QuantizedScaleRange / 65535
    elseif Constant == "QuantizedScaleMin" then
        QuantizedScaleMin = Value
        QuantizedScaleRange = QuantizedScaleMax - QuantizedScaleMin
        QuantizedScaleToU16 = 1 / (65535 / QuantizedScaleRange)
        QuantizedScaleFromU16 = QuantizedScaleRange / 65535
    elseif Constant == "SerInstanceSerialization" then
        SerInstanceSerialization = Value
        Inst = Value and SerInstance or RefInstance
    elseif Constant == "UseQuaternion" then
        UseQuaternion = Value
        Cf = Value and QCframe or Cframe
    end
end

----------------------------------------------------
-- INIT
----------------------------------------------------
do
    const function SerHandler_Nil()
        const Cur = Cursor
        buffer.writeu8(WriteBuffer, Cur, Nil)
        Cursor = Cur + 1
    end

    SerHandlers["nil"] = SerHandler_Nil
end

do
    const function SerHandler_Boolean(Value: boolean)
        const Cur = Cursor
        buffer.writeu16(WriteBuffer, Cur, ((Value and 1 or 0) * 256) + Bool)
        Cursor = Cur + 2
    end

    SerHandlers["boolean"] = SerHandler_Boolean
end

do
    const function SerHandler_Number(Value: number)
        const IsInteger: boolean = Value // 1 == Value
        const Cur = Cursor
		if IsInteger then
			if Value >= 0 then
				-- unsigned logic
				if Value < 2 ^ 8 then
					-- u8
                    buffer.writeu16(WriteBuffer, Cur, (Value * 256) + U8)
                    Cursor = Cur + 2
                    return
				elseif Value < 2 ^ 16 then
					-- u16
                    const Buf = WriteBuffer
                    buffer.writeu8(Buf, Cur, U16)
                    buffer.writeu16(Buf, Cur + 1, Value)
                    Cursor = Cur + 3
                    return
                elseif Value < 2 ^ 24 then
                    -- u24
                    const Buf = WriteBuffer
                    buffer.writeu8(Buf, Cur, U24)
                    buffer.writeu16(Buf, Cur + 1, bit32.band(Value, 0xFFFF))
                    buffer.writeu8(Buf, Cur + 3, bit32.extract(Value, 16, 8))
                    Cursor = Cur + 4
                    return
				elseif Value < 2 ^ 32 then
					-- u32
                    const Buf = WriteBuffer
                    buffer.writeu8(Buf, Cur, U32)
                    buffer.writeu32(Buf, Cur + 1, Value)
                    Cursor = Cur + 5
                    return
				elseif Value < 2 ^ 40 then
					-- u40
                    const Buf = WriteBuffer
                    buffer.writeu8(Buf, Cur, U40)
                    buffer.writeu32(Buf, Cur + 1, bit32.band(Value, 0xFFFFFFFF))
                    buffer.writeu8(Buf, Cur + 5, bit32.band(Value // 0x100000000, 0xFF))
                    Cursor = Cur + 6
                    return
				elseif Value < 2 ^ 48 then
					-- u48
                    const Buf = WriteBuffer
                    buffer.writeu8(Buf, Cur, U48)
                    buffer.writeu32(Buf, Cur + 1, bit32.band(Value, 0xFFFFFFFF))
                    buffer.writeu16(Buf, Cur + 5, bit32.band(Value // 0x100000000, 0xFFFF))
                    Cursor = Cur + 7
                    return
				end
			else
				-- signed logic
				if Value >= -(2 ^ 7) then
                    -- i8
					buffer.writeu16(WriteBuffer, Cur, (Value * 256) + I8)
                    Cursor = Cur + 2
                    return
				elseif Value >= -(2 ^ 15) then
                    -- i16
					const Buf = WriteBuffer
                    buffer.writeu8(Buf, Cur, I16)
                    buffer.writei16(Buf, Cur + 1, Value)
                    Cursor = Cur + 3
                    return
                elseif Value >= -(2 ^ 23) then
                    -- i24
                    const Buf = WriteBuffer
                    buffer.writeu8(Buf, Cur, I24)
                    buffer.writeu16(Buf, Cur + 1, bit32.band(Value, 0xFFFF))
                    buffer.writeu8(Buf, Cur + 3, bit32.extract(Value, 16, 8))
                    Cursor = Cur + 4
                    return
				elseif Value >= -(2 ^ 31) then
                    -- i32
					const Buf = WriteBuffer
                    buffer.writeu8(Buf, Cur, I32)
                    buffer.writei32(Buf, Cur + 1, Value)
                    Cursor = Cur + 5
                    return
				elseif Value >= -(2 ^ 39) then
                    -- i40
					const Buf = WriteBuffer
                    buffer.writeu8(Buf, Cur, I40)
                    buffer.writeu32(Buf, Cur + 1, bit32.band(Value, 0xFFFFFFFF))
                    buffer.writeu8(Buf, Cur + 5, bit32.band(Value // 0x100000000, 0xFF))
                    Cursor = Cur + 6
                    return
				elseif Value >= -(2 ^ 47) then
                    -- i48
					const Buf = WriteBuffer
                    buffer.writeu8(Buf, Cur, I48)
                    buffer.writeu32(Buf, Cur + 1, bit32.band(Value, 0xFFFFFFFF))
                    buffer.writeu16(Buf, Cur + 5, bit32.band(Value // 0x100000000, 0xFFFF))
                    Cursor = Cur + 7
                    return
				end
			end

			const Buf = WriteBuffer
            buffer.writeu8(Buf, Cur, F64)
            buffer.writef64(Buf, Cur + 1, Value)
            Cursor = Cur + 9
            return
		end

		if Value >= -3.4028234663852886e38 and Value <= 3.4028234663852886e38 then
			const Buf = WriteBuffer
            buffer.writeu8(Buf, Cur, F32)
            buffer.writef32(Buf, Cur + 1, Value)
            Cursor = Cur + 5
            return
		end

		const Buf = WriteBuffer
        buffer.writeu8(Buf, Cur, F64)
        buffer.writef64(Buf, Cur + 1, Value)
        Cursor = Cur + 9
    end

    SerHandlers["number"] = SerHandler_Number
end

do
    const function SerHandler_String(Value: string)
        const Len = #Value
        local Cur = Cursor
        const Buf = WriteBuffer
        if Len < 2 ^ 8 then
            buffer.writeu16(Buf, Cur, (Len * 256) + Str8)
            Cur += 2
            buffer.writestring(Buf, Cur, Value)
            Cursor = Cur + Len
            return
        elseif Len < 2 ^ 16 then
            buffer.writeu8(Buf, Cur, Str)
            buffer.writeu16(Buf, Cur + 1, Len)
            Cur += 3
            buffer.writestring(Buf, Cur, Value)
            Cursor = Cur + Len
            return
        elseif Len < 2 ^ 24 then
            buffer.writeu32(Buf, Cur, Str24 + (Len * 256))
            Cur += 4
            buffer.writestring(Buf, Cur, Value)
            Cursor = Cur + Len
            return
        end

        error("String too large, max length: " .. 2 ^ 24 - 1 .. " provided length: " .. Len)
    end

    SerHandlers["string"] = SerHandler_String
end

do
    const function SerHandler_Table(Value: { [any]: any })
        const Len: number = #Value
        const NextValue = Next(Value)

        const Cur = Cursor
		-- empty table
		if Len == 0 and NextValue == nil then
            buffer.writeu8(WriteBuffer, Cur, Void)
            Cursor = Cur + 1
            return
		end

        -- array
        if Len ~= 0 and Next(Value, Len) == nil then
            if Len < 2 ^ 8 then
                buffer.writeu16(WriteBuffer, Cur, (Len * 256) + Array8)
                Cursor = Cur + 2
                for Index = 1, Len do
                    const Element = Value[Index]
                    SerHandlers[typeof(Element)](Element)
                end
                return
            elseif Len < 2 ^ 16 then
                buffer.writeu8(WriteBuffer, Cur, Array)
                buffer.writeu16(WriteBuffer, Cur + 1, Len)
                Cursor = Cur + 3
                for Index = 1, Len do
                    const Element = Value[Index]
                    SerHandlers[typeof(Element)](Element)
                end
                return
            elseif Len < 2 ^ 24 then
                buffer.writeu32(WriteBuffer, Cur, (Len * 256) + Array24)
                Cursor = Cur + 4
                for Index = 1, Len do
                    const Element = Value[Index]
                    SerHandlers[typeof(Element)](Element)
                end
                return
            end
            error("Array too large, max length: " .. 2 ^ 24 - 1 .. " provided length: " .. Len)
        end

        -- map
        if DoMapCompute then
            local MapLen = 0
            for _ in Value do
                MapLen += 1
            end

            if MapLen < 2 ^ 8 then
                buffer.writeu16(WriteBuffer, Cur, (MapLen * 256) + Map8)
                Cursor = Cur + 2
                for Key, Element in Value do
                    SerHandlers[typeof(Key)](Key)
                    SerHandlers[typeof(Element)](Element)
                end
                return
            elseif MapLen < 2 ^ 16 then
                const Buf = WriteBuffer
                buffer.writeu8(Buf, Cur, Map)
                buffer.writeu16(Buf, Cur + 1, MapLen)
                Cursor = Cur + 3
                for Key, Element in Value do
                    SerHandlers[typeof(Key)](Key)
                    SerHandlers[typeof(Element)](Element)
                end
                return
            elseif MapLen < 2 ^ 24 then
                buffer.writeu32(WriteBuffer, Cur, (MapLen * 256) + Map24)
                Cursor = Cur + 4
                for Key, Element in Value do
                    SerHandlers[typeof(Key)](Key)
                    SerHandlers[typeof(Element)](Element)
                end
                return
            end
            error("Map too large, max length: " .. 2 ^ 24 - 1 .. " provided length: " .. MapLen)
        end

        const Buf = WriteBuffer
        local MapLen = 0
        buffer.writeu8(Buf, Cur, Map)
        Cursor = Cur + 3
        for Key, Element in Value do
            MapLen += 1
            SerHandlers[typeof(Key)](Key)
            SerHandlers[typeof(Element)](Element)
        end
        buffer.writeu16(Buf, Cur + 1, MapLen)
    end

    SerHandlers["table"] = SerHandler_Table
end

do
    const function SerHandler_Buffer(Value: buffer)
        const Len = buffer.len(Value)
        local Cur = Cursor
        const WBuf = WriteBuffer

        if Len < 2 ^ 8 then
            buffer.writeu16(WBuf, Cur, (Len * 256) + Buf8)
            Cur += 2
            buffer.copy(WBuf, Cur, Value, 0, Len)
            Cursor = Cur + Len
            return
        elseif Len < 2 ^ 16 then
            buffer.writeu8(WBuf, Cur, Buf)
            buffer.writeu16(WBuf, Cur + 1, Len)
            Cur += 3
            buffer.copy(WBuf, Cur, Value, 0, Len)
            Cursor = Cur + Len
            return
        elseif Len < 2 ^ 24 then
            buffer.writeu32(WBuf, Cur, (Len * 256) + Buf24)
            Cur += 4
            buffer.copy(WBuf, Cur, Value, 0, Len)
            Cursor = Cur + Len
            return
        end

        error("Buffer too large, max length: " .. 2 ^ 24 - 1 .. " provided length: " .. Len)
    end

    SerHandlers["buffer"] = SerHandler_Buffer
end

do
    const function SerHandler_Function(): ()
        error("Function type cannot be serialized")
    end

    SerHandlers["function"] = SerHandler_Function
end

do
    const function SerHandler_Userdata(): ()
        error("Custom/Unsupported userdata type cannot be serialized")
    end

    SerHandlers["userdata"] = SerHandler_Userdata
end

do
    const function SerHandler_Thread(): ()
        error("Thread type cannot be serialized")
    end

    SerHandlers["thread"] = SerHandler_Thread
end

do
    const function SerHandler_Vector3(Value: Vector3)
        const Buf = WriteBuffer
        const Cur = Cursor
        buffer.writeu8(Buf, Cur, Vec)
        buffer.writef32(Buf, Cur + 1, Value.X)
        buffer.writef32(Buf, Cur + 5, Value.Y)
        buffer.writef32(Buf, Cur + 9, Value.Z)
        Cursor = Cur + 13
    end

    SerHandlers["Vector3"] = SerHandler_Vector3
end

do
    const function SerHandler_CFrame(Value: CFrame)
        if Cf == QCframe then
            const Pos = Value.Position
            const Axis, Angle = Value:ToAxisAngle()
        
            const HalfAngle = Angle * 0.5
            const s = math.sin(HalfAngle)
        
            const qx = Axis.X * s
            const qy = Axis.Y * s
            const qz = Axis.Z * s
            const qw = math.cos(HalfAngle)
        
            const Cur = Cursor
            const Buf = WriteBuffer
            buffer.writeu8(Buf, Cur, QCframe)
            buffer.writef32(Buf, Cur + 1, Pos.X)
            buffer.writef32(Buf, Cur + 5, Pos.Y)
            buffer.writef32(Buf, Cur + 9, Pos.Z)
            buffer.writef32(Buf, Cur + 13, qx)
            buffer.writef32(Buf, Cur + 17, qy)
            buffer.writef32(Buf, Cur + 21, qz)
            buffer.writef32(Buf, Cur + 25, qw)
            Cursor = Cur + 29
            return
        end

        const X, Y, Z, R0, R01, R02, R10, R11, R12, R20, R21, R22 = Value:GetComponents()
        const Cur = Cursor
        const Buf = WriteBuffer
        buffer.writeu8(Buf, Cur, Cframe)
        buffer.writef32(Buf, Cur + 1, X)
        buffer.writef32(Buf, Cur + 5, Y)
        buffer.writef32(Buf, Cur + 9, Z)
        buffer.writef32(Buf, Cur + 13, R0)
        buffer.writef32(Buf, Cur + 17, R01)
        buffer.writef32(Buf, Cur + 21, R02)
        buffer.writef32(Buf, Cur + 25, R10)
        buffer.writef32(Buf, Cur + 29, R11)
        buffer.writef32(Buf, Cur + 33, R12)
        buffer.writef32(Buf, Cur + 37, R20)
        buffer.writef32(Buf, Cur + 41, R21)
        buffer.writef32(Buf, Cur + 45, R22)
        Cursor = Cur + 49
    end

    SerHandlers["CFrame"] = SerHandler_CFrame
end

do
    const function SerHandler_Instance(Value: any)
        if Inst == SerInstance then
            const ClassName = Value.ClassName
            const SerSchema = SerInstance_Ser[ClassName]
            if not SerSchema then
                error("Ser schema does not exist for classname " .. ClassName)
            end
            const SerKeys = SerInstance_Keys[ClassName]
            const Cur = Cursor
            const Buf = WriteBuffer
            buffer.writeu8(Buf, Cur, SerInstance)
            buffer.writeu8(Buf, Cur + 1, SerInstance_Ids[ClassName])
            Cursor = Cur + 2
            for i, Property in SerKeys do
                const Ser = SerSchema[i]
                Ser(Value[Property])
            end
            return
        end

        const Id = InstanceMap[Value]
        if not Id then
            error(Value:GetFullName() .. " not found in instance map")
        end

        const Buf = WriteBuffer
        const Cur = Cursor
        buffer.writeu8(Buf, Cur, RefInstance)
        if InstanceRefMode == "Normal" then
            buffer.writeu16(Buf, Cur + 1, Id)
            Cursor = Cur + 3
            return
        end

        buffer.writeu16(Buf, Cur + 1, bit32.band(Id, 0xFFFF))
        buffer.writeu8(Buf, Cur + 3, bit32.extract(Id, 16, 8))
        Cursor = Cur + 4
    end

    SerHandlers["Instance"] = SerHandler_Instance
end

do
    const function SerHandler_Color3(Value: Color3)
        const Cur = Cursor
        const Buf = WriteBuffer
        buffer.writeu8(Buf, Cur, Color)
        buffer.writeu8(Buf, Cur + 1, Value.R // Reciprocal)
        buffer.writeu8(Buf, Cur + 2, Value.G // Reciprocal)
        buffer.writeu8(Buf, Cur + 3, Value.B // Reciprocal)
        Cursor = Cur + 4
    end

    SerHandlers["Color3"] = SerHandler_Color3
end

do
    const function SerHandler_UDim2(Value: UDim2)
        const X = Value.X
        const Y = Value.Y
        const Cur = Cursor
        const Buf = WriteBuffer
        buffer.writeu8(Buf, Cur, Udim2)
        buffer.writeu16(Buf, Cur + 1, (X.Scale - QuantizedScaleMin) // QuantizedScaleToU16)
        buffer.writei16(Buf, Cur + 3, X.Offset)
        buffer.writeu16(Buf, Cur + 5, (Y.Scale - QuantizedScaleMin) // QuantizedScaleToU16)
        buffer.writei16(Buf, Cur + 7, Y.Offset)
        Cursor = Cur + 9
    end

    SerHandlers["UDim2"] = SerHandler_UDim2
end

do
    const function SerHandler_Vector2(Value: Vector2)
        const Cur = Cursor
        const Buf = WriteBuffer
        buffer.writeu8(Buf, Cur, Vec2)
        buffer.writef32(Buf, Cur + 1, Value.X)
        buffer.writef32(Buf, Cur + 5, Value.Y)
        Cursor = Cur + 9
    end

    SerHandlers["Vector2"] = SerHandler_Vector2
end

do
    const function SerHandler_UDim(Value: UDim)
        const Cur = Cursor
        const Buf = WriteBuffer
        buffer.writeu8(Buf, Cur, Udim)
        buffer.writeu16(Buf, Cur + 1, (Value.Scale - QuantizedScaleMin) // QuantizedScaleToU16)
        buffer.writei16(Buf, Cur + 3, Value.Offset)
        Cursor = Cur + 5
    end

    SerHandlers["UDim"] = SerHandler_UDim
end

do
    const function SerHandlers_Enum(Value: Enum)
        const WB = WriteBuffer
        const Cur = Cursor
        const Id = EnumMap[Value]

        buffer.writeu8(WB, Cur, EnumType)
        buffer.writeu16(WB, Cur + 1, Id)
        Cursor = Cur + 3
    end

    SerHandlers["Enum"] = SerHandlers_Enum
end

do
    const function SerHandlers_EnumItem(Value: EnumItem)
        const WB = WriteBuffer
        const Cur = Cursor
        const EnumParent = Value.EnumType
        const EnumId = EnumMap[EnumParent]

        buffer.writeu8(WB, Cur, EnumItem)
        buffer.writeu16(WB, Cur + 1, EnumId)
        buffer.writeu16(WB, Cur + 3, Value.Value)
        Cursor = Cur + 5
    end

    SerHandlers["EnumItem"] = SerHandlers_EnumItem
end

do
    const function U8Ser(Value: number)
        const Cur = Cursor
        buffer.writeu8(WriteBuffer, Cur, Value)
        Cursor = Cur + 1
    end
    Ser[U8] = U8Ser
    
    const function U8Des()
        const Cur = Cursor
        const Value = buffer.readu8(ReadBuffer :: buffer, Cur)
        Cursor = Cur + 1
        return Value
    end
    Des[U8] = U8Des
end

do
    const function I8Ser(Value: number)
        const Cur = Cursor
        buffer.writei8(WriteBuffer, Cur, Value)
        Cursor = Cur + 1
    end
    Ser[I8] = I8Ser
    
    const function I8Des()
        const Cur = Cursor
        const Value = buffer.readi8(ReadBuffer :: buffer, Cur)
        Cursor = Cur + 1
        return Value
    end
    Des[I8] = I8Des
end

do
    const function U16Ser(Value: number)
        const Cur = Cursor
        buffer.writeu16(WriteBuffer, Cur, Value)
        Cursor = Cur + 2
    end
    Ser[U16] = U16Ser
    
    const function U16Des()
        const Cur = Cursor
        const Value = buffer.readu16(ReadBuffer :: buffer, Cur)
        Cursor = Cur + 2
        return Value
    end
    Des[U16] = U16Des
end

do
    const function I16Ser(Value: number)
        const Cur = Cursor
        buffer.writei16(WriteBuffer, Cur, Value)
        Cursor = Cur + 2
    end
    Ser[I16] = I16Ser
    
    const function I16Des()
        const Cur = Cursor
        const Value = buffer.readi16(ReadBuffer :: buffer, Cur)
        Cursor = Cur + 2
        return Value
    end
    Des[I16] = I16Des
end

do
    const function U32Ser(Value: number)
        const Cur = Cursor
        buffer.writeu32(WriteBuffer, Cur, Value)
        Cursor = Cur + 4
    end
    Ser[U32] = U32Ser
    
    const function U32Des()
        const Cur = Cursor
        const Value = buffer.readu32(ReadBuffer :: buffer, Cur)
        Cursor = Cur + 4
        return Value
    end
    Des[U32] = U32Des
end

do
    const function I32Ser(Value: number)
        const Cur = Cursor
        buffer.writei32(WriteBuffer, Cur, Value)
        Cursor = Cur + 4
    end
    Ser[I32] = I32Ser
    
    const function I32Des()
        const Cur = Cursor
        const Value = buffer.readi32(ReadBuffer :: buffer, Cur)
        Cursor = Cur + 4
        return Value
    end
    Des[I32] = I32Des
end

do
    const function F32Ser(Value: number)
        const Cur = Cursor
        buffer.writef32(WriteBuffer, Cur, Value)
        Cursor = Cur + 4
    end
    Ser[F32] = F32Ser
    
    const function F32Des()
        const Cur = Cursor
        const Value = buffer.readf32(ReadBuffer :: buffer, Cur)
        Cursor = Cur + 4
        return Value
    end
    Des[F32] = F32Des
end

do
    const function F64Ser(Value: number)
        const Cur = Cursor
        buffer.writef64(WriteBuffer, Cur, Value)
        Cursor = Cur + 8
    end
    Ser[F64] = F64Ser
    
    const function F64Des()
        const Cur = Cursor
        const Value = buffer.readf64(ReadBuffer :: buffer, Cur)
        Cursor = Cur + 8
        return Value
    end
    Des[F64] = F64Des
end

do
    const function BoolSer(Value: boolean)
        const Cur = Cursor
        buffer.writeu8(WriteBuffer, Cur, Value and 1 or 0)
        Cursor = Cur + 1
    end
    Ser[Bool] = BoolSer
    
    const function BoolDes()
        const Cur = Cursor
        const Value = buffer.readu8(ReadBuffer :: buffer, Cur)
        Cursor = Cur + 1
        return Value == 1
    end
    Des[Bool] = BoolDes
end

do
    const function U24Ser(Value: number)
        const Cur = Cursor
        const Buf = WriteBuffer
        buffer.writeu16(Buf, Cur, bit32.band(Value, 0xFFFF))
        buffer.writeu8(Buf, Cur + 2, bit32.extract(Value, 16, 8))
        Cursor = Cur + 3
    end
    Ser[U24] = U24Ser
    
    const function U24Des()
        const Buf = ReadBuffer :: buffer
        const Cur = Cursor
        const Low = buffer.readu16(Buf, Cur)
        const High = buffer.readu8(Buf, Cur + 2)
        Cursor = Cur + 3
	    return bit32.bor(Low, bit32.lshift(High, 16))
    end
    Des[U24] = U24Des
end

do
    const function I24Ser(Value: number)
        const Cur = Cursor
        const Buf = WriteBuffer
        buffer.writeu16(Buf, Cur, bit32.band(Value, 0xFFFF))
        buffer.writeu8(Buf, Cur + 2, bit32.extract(Value, 16, 8))
        Cursor = Cur + 3
    end
    Ser[I24] = I24Ser
    
    const function I24Des()
        const Buf = ReadBuffer :: buffer
        const Cur = Cursor
        const Low = buffer.readu16(Buf, Cur)
        const High = buffer.readu8(Buf, Cur + 2)
        Cursor = Cur + 3
	    local Value = bit32.bor(Low, bit32.lshift(High, 16))
        if Value >= 0x800000 then
            Value -= 0x1000000
        end
        return Value
    end
    Des[I24] = I24Des
end

do
    const function U40Ser(Value: number)
        const Cur = Cursor
        const Buf = WriteBuffer
        buffer.writeu32(Buf, Cur, bit32.band(Value, 0xFFFFFFFF))
        buffer.writeu8(Buf, Cur + 4, bit32.band(Value // 0x100000000, 0xFF))
        Cursor = Cur + 5
    end
    Ser[U40] = U40Ser
    
    const function U40Des()
        const Buf = ReadBuffer :: buffer
        const Cur = Cursor
        const Low = buffer.readu32(Buf, Cur)
        const High = buffer.readu8(Buf, Cur + 4)
        Cursor = Cur + 5
	    return Low + High * 0x100000000
    end
    Des[U40] = U40Des
end

do
    const function I40Ser(Value: number)
        const Cur = Cursor
        const Buf = WriteBuffer
        buffer.writeu32(Buf, Cur, bit32.band(Value, 0xFFFFFFFF))
        buffer.writeu8(Buf, Cur + 4, bit32.band(Value // 0x100000000, 0xFF))
        Cursor = Cur + 5
    end
    Ser[I40] = I40Ser
    
    const function I40Des()
        const Buf = ReadBuffer :: buffer
        const Cur = Cursor
        const Low = buffer.readu32(Buf, Cur)
        const High = buffer.readu8(Buf, Cur + 4)
        Cursor = Cur + 5
	    local Value = Low + High * 0x100000000
        if Value >= 0x8000000000 then
            Value -= 0x10000000000
        end
        return Value
    end
    Des[I40] = I40Des
end

do
    const function U48Ser(Value: number)
        const Cur = Cursor
        const Buf = WriteBuffer
        buffer.writeu32(Buf, Cur, bit32.band(Value, 0xFFFFFFFF))
        buffer.writeu16(Buf, Cur + 4, bit32.band(Value // 0x100000000, 0xFFFF))
        Cursor = Cur + 6
    end
    Ser[U48] = U48Ser
    
    const function U48Des()
        const Buf = ReadBuffer :: buffer
        const Cur = Cursor
        const Low = buffer.readu32(Buf, Cur)
        const High = buffer.readu16(Buf, Cur + 4)
        Cursor = Cur + 6
	    return Low + High * 0x100000000
    end
    Des[U48] = U48Des
end

do
    const function I48Ser(Value: number)
        const Cur = Cursor
        const Buf = WriteBuffer
        buffer.writeu32(Buf, Cur, bit32.band(Value, 0xFFFFFFFF))
        buffer.writeu16(Buf, Cur + 4, bit32.band(Value // 0x100000000, 0xFFFF))
        Cursor = Cur + 6
    end
    Ser[I48] = I48Ser
    
    const function I48Des()
        const Buf = ReadBuffer :: buffer
        const Cur = Cursor
        const Low = buffer.readu32(Buf, Cur)
        const High = buffer.readu16(Buf, Cur + 4)
        Cursor = Cur + 6
	    local Value = Low + High * 0x100000000
        if Value >= 0x800000000000 then
            Value -= 0x1000000000000
        end
        return Value
    end
    Des[I48] = I48Des
end

do
    const function Vec3Ser(Value: Vector3)
        const Cur = Cursor
        const Buf = WriteBuffer
        buffer.writef32(Buf, Cur, Value.X)
        buffer.writef32(Buf, Cur + 4, Value.Y)
        buffer.writef32(Buf, Cur + 8, Value.Z)
        Cursor = Cur + 12
    end
    Ser[Vec] = Vec3Ser
    
    const function Vec3Des()
        const Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const X = buffer.readf32(Buf, Cur)
        const Y = buffer.readf32(Buf, Cur + 4)
        const Z = buffer.readf32(Buf, Cur + 8)
        Cursor = Cur + 12
        return Vector3.new(X, Y, Z)
    end
    Des[Vec] = Vec3Des
end

do
    const function Color3Ser(Value: Color3)
        const Cur = Cursor
        const Buf = WriteBuffer
        buffer.writeu8(Buf, Cur, Value.R // Reciprocal)
        buffer.writeu8(Buf, Cur + 1, Value.G // Reciprocal)
        buffer.writeu8(Buf, Cur + 2, Value.B // Reciprocal)
        Cursor = Cur + 3
    end
    Ser[Color] = Color3Ser
    
    const function Color3Des()
        const Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const R = buffer.readu8(Buf, Cur)
        const G = buffer.readu8(Buf, Cur + 1)
        const B = buffer.readu8(Buf, Cur + 2)
        Cursor = Cur + 3
        return Color3New(R, G, B)
    end
    Des[Color] = Color3Des
end

do
    const function UDimSer(Value: UDim)
        const Cur = Cursor
        const Buf = WriteBuffer
        buffer.writeu16(Buf, Cur, (Value.Scale - QuantizedScaleMin) // QuantizedScaleToU16)
        buffer.writei16(Buf, Cur + 2, Value.Offset)
        Cursor = Cur + 4
    end
    Ser[Udim] = UDimSer
    
    const function UDimDes()
        const Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const Scale = QuantizedScaleMin + buffer.readu16(Buf, Cur) * QuantizedScaleFromU16
        const Offset = buffer.readi16(Buf, Cur + 2)
        Cursor = Cur + 4
        return UDimNew(Scale, Offset)
    end
    Des[Udim] = UDimDes
end

do
    const function UDim2Ser(Value: UDim2)
        const X = Value.X
        const Y = Value.Y
        const Cur = Cursor
        const Buf = WriteBuffer
        buffer.writeu16(Buf, Cur + 1, (X.Scale - QuantizedScaleMin) // QuantizedScaleToU16)
        buffer.writei16(Buf, Cur + 3, X.Offset)
        buffer.writeu16(Buf, Cur + 5, (Y.Scale - QuantizedScaleMin) // QuantizedScaleToU16)
        buffer.writei16(Buf, Cur + 7, Y.Offset)
        Cursor = Cur + 8
    end
    Ser[Udim2] = UDim2Ser
    
    const function UDim2Des()
        const Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const XScale = QuantizedScaleMin + buffer.readu16(Buf, Cur) * QuantizedScaleFromU16
        const XOffset = buffer.readi16(Buf, Cur + 2)
        const YScale = QuantizedScaleMin + buffer.readu16(Buf, Cur + 4) * QuantizedScaleFromU16
        const YOffset = buffer.readi16(Buf, Cur + 6)
        Cursor = Cur + 8
        return UDim2New(XScale, XOffset, YScale, YOffset)
    end
    Des[Udim2] = UDim2Des
end

do
    const function Vec2Ser(Value: Vector2)
        const Cur = Cursor
        const Buf = WriteBuffer
        buffer.writef32(Buf, Cur, Value.X)
        buffer.writef32(Buf, Cur + 4, Value.Y)
        Cursor = Cur + 8
    end
    Ser[Vec2] = Vec2Ser
    
    const function Vec2Des()
        const Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const X = buffer.readf32(Buf, Cur)
        const Y = buffer.readf32(Buf, Cur + 4)
        Cursor = Cur + 8
        return Vector2New(X, Y)
    end
    Des[Vec2] = Vec2Des
end

do
    const function NilSer()
    end
    Ser[Nil] = NilSer
    
    const function NilDes()
        return nil
    end
    Des[Nil] = NilDes
end

do
    const function VoidSer()
    end
    Ser[Void] = VoidSer
    
    const function VoidDes()
        return {}
    end
    Des[Void] = VoidDes
end

do
    const function CFrameSer(Value: CFrame)
        const X, Y, Z, R0, R01, R02, R10, R11, R12, R20, R21, R22 = Value:GetComponents()
        const Cur = Cursor
        const Buf = WriteBuffer
        buffer.writef32(Buf, Cur, X)
        buffer.writef32(Buf, Cur + 4, Y)
        buffer.writef32(Buf, Cur + 8, Z)
        buffer.writef32(Buf, Cur + 12, R0)
        buffer.writef32(Buf, Cur + 16, R01)
        buffer.writef32(Buf, Cur + 20, R02)
        buffer.writef32(Buf, Cur + 24, R10)
        buffer.writef32(Buf, Cur + 28, R11)
        buffer.writef32(Buf, Cur + 32, R12)
        buffer.writef32(Buf, Cur + 36, R20)
        buffer.writef32(Buf, Cur + 40, R21)
        buffer.writef32(Buf, Cur + 44, R22)
        Cursor = Cur + 48
    end
    Ser[Cframe] = CFrameSer
    
    const function CFrameDes()
        const Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const X = buffer.readf32(Buf, Cur)
        const Y = buffer.readf32(Buf, Cur + 4)
        const Z = buffer.readf32(Buf, Cur + 8)
        const R0 = buffer.readf32(Buf, Cur + 12)
        const R01 = buffer.readf32(Buf, Cur + 16)
        const R02 = buffer.readf32(Buf, Cur + 20)
        const R10 = buffer.readf32(Buf, Cur + 24)
        const R11 = buffer.readf32(Buf, Cur + 28)
        const R12 = buffer.readf32(Buf, Cur + 32)
        const R20 = buffer.readf32(Buf, Cur + 36)
        const R21 = buffer.readf32(Buf, Cur + 40)
        const R22 = buffer.readf32(Buf, Cur + 44)
        Cursor = Cur + 48
        return CFrameNew(X, Y, Z, R0, R01, R02, R10, R11, R12, R20, R21, R22)
    end
    Des[Cframe] = CFrameDes
end

do
    const function QCFrameSer(Value: CFrame)
        const Pos = Value.Position
        const Axis, Angle = Value:ToAxisAngle()
    
        const HalfAngle = Angle * 0.5
        const s = math.sin(HalfAngle)
    
        const qx = Axis.X * s
        const qy = Axis.Y * s
        const qz = Axis.Z * s
        const qw = math.cos(HalfAngle)
    
        const Cur = Cursor
        const Buf = WriteBuffer
        buffer.writef32(Buf, Cur, Pos.X)
        buffer.writef32(Buf, Cur + 4, Pos.Y)
        buffer.writef32(Buf, Cur + 8, Pos.Z)
        buffer.writef32(Buf, Cur + 12, qx)
        buffer.writef32(Buf, Cur + 16, qy)
        buffer.writef32(Buf, Cur + 20, qz)
        buffer.writef32(Buf, Cur + 24, qw)
        Cursor = Cur + 28
    end
    Ser[QCframe] = QCFrameSer
    
    const function QCFrameDes()
        const Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const X = buffer.readf32(Buf, Cur)
        const Y = buffer.readf32(Buf, Cur + 4)
        const Z = buffer.readf32(Buf, Cur + 8)
        const qx = buffer.readf32(Buf, Cur + 12)
        const qy = buffer.readf32(Buf, Cur + 16)
        const qz = buffer.readf32(Buf, Cur + 20)
        const qw = buffer.readf32(Buf, Cur + 24)
        Cursor = Cur + 28
        return CFrameNew(X, Y, Z, qx, qy, qz, qw)
    end
    Des[QCframe] = QCFrameDes
end

do
    const function SerInstanceSer(Value: any)
        const ClassName = Value.ClassName
        const SerSchema = SerInstance_Ser[ClassName]
        if not SerSchema then
            error("Ser schema does not exist for classname " .. ClassName)
        end
        const SerKeys = SerInstance_Keys[ClassName]
        const Cur = Cursor
        buffer.writeu8(WriteBuffer, Cur, SerInstance_Ids[ClassName])
        Cursor = Cur + 1
        for i, Property in SerKeys do
            const Ser = SerSchema[i]
            Ser(Value[Property])
        end
    end
    Ser[SerInstance] = SerInstanceSer
    const function SerInstanceDes()
        const Cur = Cursor
        const Id = buffer.readu8(ReadBuffer :: buffer, Cur)
        Cursor = Cur + 1
        const ClassName = SerInstance_Reverse[Id]
        if not ClassName then
            error("Invalid SerInstance id: " .. Id)
        end
        const Keys = SerInstance_Keys[ClassName]
        const DesSchema = SerInstance_Des[ClassName]

        const Inst = InstanceNew(ClassName) :: any
        for i, Property in Keys do
            const Des = DesSchema[i]
            Inst[Property] = Des()
        end
        return Inst
    end
    Des[SerInstance] = SerInstanceDes
end

do
    const function RefInstanceSer(Value: Instance)
        const Id = InstanceMap[Value]
        if not Id then
            error(Value:GetFullName() .. " not found in instance map")
        end

        const Buf = WriteBuffer
        const Cur = Cursor
        if InstanceRefMode == "Normal" then
            buffer.writeu16(Buf, Cur, Id)
            Cursor = Cur + 2
            return
        end

        buffer.writeu16(Buf, Cur, bit32.band(Id, 0xFFFF))
        buffer.writeu8(Buf, Cur + 2, bit32.extract(Id, 16, 8))
        Cursor = Cur + 3
    end
    Ser[RefInstance] = RefInstanceSer

    const function RefInstanceDes()
        const Buf = ReadBuffer :: buffer
        const Cur = Cursor
        if InstanceRefMode == "Normal" then
            const Id = buffer.readu16(Buf, Cur)
            Cursor = Cur + 2
            return IdMap[Id]
        end

        const Low = buffer.readu16(Buf, Cur)
        const High = buffer.readu8(Buf, Cur + 2)
        Cursor = Cur + 3
        return IdMap[bit32.bor(Low, bit32.lshift(High, 16))]
    end
    Des[RefInstance] = RefInstanceDes
end

do
    const function ArraySer(Value: { any })
        const Buf = WriteBuffer
        const Cur = Cursor
        const Len = #Value

        buffer.writeu16(Buf, Cur, Len)
        Cursor = Cur + 2
        for Index = 1, Len do
            const Element = Value[Index]
            SerHandlers[typeof(Element)](Element)
        end
    end
    Ser[Array] = ArraySer

    const function ArrayDes()
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const Len = buffer.readu16(Buf, Cur)
        Cursor = Cur + 2

        const Value = TableCreate(Len)
        for i = 1, Len do
            Cur = Cursor
            const Id = buffer.readu8(Buf, Cur)
            Cursor = Cur + 1
            Value[i] = Des[Id]()
        end

        return Value
    end
    Des[Array] = ArrayDes
end

do
    const function Array8Ser(Value: { any })
        const Buf = WriteBuffer
        const Cur = Cursor
        const Len = #Value

        buffer.writeu8(Buf, Cur, Len)
        Cursor = Cur + 1
        for Index = 1, Len do
            const Element = Value[Index]
            SerHandlers[typeof(Element)](Element)
        end
    end
    Ser[Array8] = Array8Ser

    const function Array8Des()
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const Len = buffer.readu8(Buf, Cur)
        Cursor = Cur + 1

        const Value = TableCreate(Len)
        for i = 1, Len do
            Cur = Cursor
            const Id = buffer.readu8(Buf, Cur)
            Cursor = Cur + 1
            Value[i] = Des[Id]()
        end

        return Value
    end
    Des[Array8] = Array8Des
end

do
    const function Array24Ser(Value: { any })
        const Buf = WriteBuffer
        const Cur = Cursor
        const Len = #Value

        buffer.writeu16(Buf, Cur, bit32.band(Len, 0xFFFF))
        buffer.writeu8(Buf, Cur + 2, bit32.extract(Len, 16, 8))
        Cursor = Cur + 3
        for Index = 1, Len do
            const Element = Value[Index]
            SerHandlers[typeof(Element)](Element)
        end
    end
    Ser[Array24] = Array24Ser

    const function Array24Des()
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const Low = buffer.readu16(Buf, Cur)
        const High = buffer.readu8(Buf, Cur + 2)
        const Len = bit32.bor(Low, bit32.lshift(High, 16))
        Cursor = Cur + 3

        const Value = TableCreate(Len)
        for i = 1, Len do
            Cur = Cursor
            const Id = buffer.readu8(Buf, Cur)
            Cursor = Cur + 1
            Value[i] = Des[Id]()
        end

        return Value
    end
    Des[Array24] = Array24Des
end

do
    const function MapSer(Value: { [any]: any })
        const Buf = WriteBuffer
        const Cur = Cursor
        local Len = 0

        Cursor = Cur + 2
        for Key, Element in Value do
            Len += 1
            SerHandlers[typeof(Key)](Key)
            SerHandlers[typeof(Element)](Element)
        end
        buffer.writeu16(Buf, Cur, Len)
    end
    Ser[Map] = MapSer

    const function MapDes()
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const Len = buffer.readu16(Buf, Cur)
        Cursor = Cur + 2

        const Value = {}
        for _ = 1, Len do
            Cur = Cursor
            const KeyId = buffer.readu8(Buf, Cur)
            Cursor = Cur + 1
            const Key = Des[KeyId]()

            Cur = Cursor
            const ValueId = buffer.readu8(Buf, Cur)
            Cursor = Cur + 1
            Value[Key] = Des[ValueId]()
        end

        return Value
    end
    Des[Map] = MapDes
end

do
    const function Map8Ser(Value: { [any]: any })
        const Buf = WriteBuffer
        const Cur = Cursor
        local Len = 0

        Cursor = Cur + 1
        for Key, Element in Value do
            Len += 1
            SerHandlers[typeof(Key)](Key)
            SerHandlers[typeof(Element)](Element)
        end
        buffer.writeu8(Buf, Cur, Len)
    end
    Ser[Map8] = Map8Ser

    const function Map8Des()
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const Len = buffer.readu8(Buf, Cur)
        Cursor = Cur + 1

        const Value = {}
        for _ = 1, Len do
            Cur = Cursor
            const KeyId = buffer.readu8(Buf, Cur)
            Cursor = Cur + 1
            const Key = Des[KeyId]()

            Cur = Cursor
            const ValueId = buffer.readu8(Buf, Cur)
            Cursor = Cur + 1
            Value[Key] = Des[ValueId]()
        end

        return Value
    end
    Des[Map8] = Map8Des
end

do
    const function Map24Ser(Value: { [any]: any })
        const Buf = WriteBuffer
        const Cur = Cursor
        local Len = 0

        Cursor = Cur + 3
        for Key, Element in Value do
            Len += 1
            SerHandlers[typeof(Key)](Key)
            SerHandlers[typeof(Element)](Element)
        end
        buffer.writeu16(Buf, Cur, bit32.band(Len, 0xFFFF))
        buffer.writeu8(Buf, Cur + 2, bit32.extract(Len, 16, 8))
    end
    Ser[Map24] = Map24Ser

    const function Map24Des()
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const Low = buffer.readu16(Buf, Cur)
        const High = buffer.readu8(Buf, Cur + 2)
        const Len = bit32.bor(Low, bit32.lshift(High, 16))
        Cursor = Cur + 3

        const Value = {}
        for _ = 1, Len do
            Cur = Cursor
            const KeyId = buffer.readu8(Buf, Cur)
            Cursor = Cur + 1
            const Key = Des[KeyId]()

            Cur = Cursor
            const ValueId = buffer.readu8(Buf, Cur)
            Cursor = Cur + 1
            Value[Key] = Des[ValueId]()
        end

        return Value
    end
    Des[Map24] = Map24Des
end

do
    const function BufSer(Value: buffer)
        const WB = WriteBuffer
        const Cur = Cursor
        const Len = buffer.len(Value)

        buffer.writeu16(WB, Cur, Len)
        buffer.copy(WB, Cur + 2, Value, 0, Len)
        Cursor = Cur + Len + 2
    end
    Ser[Buf] = BufSer

    const function BufDes()
        const Cur = Cursor
        const RB = ReadBuffer :: buffer
        const Len = buffer.readu16(RB, Cur)
        const Value = buffer.create(Len)
        buffer.copy(Value, 0, RB, Cur + 2, Len)
        Cursor = Cur + Len + 2
        return Value
    end
    Des[Buf] = BufDes
end

do
    const function Buf8Ser(Value: buffer)
        const WB = WriteBuffer
        const Cur = Cursor
        const Len = buffer.len(Value)

        buffer.writeu8(WB, Cur, Len)
        buffer.copy(WB, Cur + 1, Value, 0, Len)
        Cursor = Cur + Len + 1
    end
    Ser[Buf8] = Buf8Ser

    const function Buf8Des()
        const Cur = Cursor
        const RB = ReadBuffer :: buffer
        const Len = buffer.readu8(RB, Cur)
        const Value = buffer.create(Len)
        buffer.copy(Value, 0, RB, Cur + 1, Len)
        Cursor = Cur + Len + 1
        return Value
    end
    Des[Buf8] = Buf8Des
end

do
    const function Buf24Ser(Value: buffer)
        const WB = WriteBuffer
        const Cur = Cursor
        const Len = buffer.len(Value)

        buffer.writeu16(WB, Cur, bit32.band(Len, 0xFFFF))
        buffer.writeu8(WB, Cur + 2, bit32.extract(Len, 16, 8))
        buffer.copy(WB, Cur + 3, Value, 0, Len)
        Cursor = Cur + Len + 3
    end
    Ser[Buf24] = Buf24Ser

    const function Buf24Des()
        const Cur = Cursor
        const RB = ReadBuffer :: buffer
        const Low = buffer.readu16(RB, Cur)
        const High = buffer.readu8(RB, Cur + 2)
        const Len = bit32.bor(Low, bit32.lshift(High, 16))
        const Value = buffer.create(Len)
        buffer.copy(Value, 0, RB, Cur + 3, Len)
        Cursor = Cur + Len + 3
        return Value
    end
    Des[Buf24] = Buf24Des
end

do
    const function StrSer(Value: string)
        const Buf = WriteBuffer
        const Cur = Cursor
        const Len = #Value

        buffer.writeu16(Buf, Cur, Len)
        buffer.writestring(Buf, Cur + 2, Value)
        Cursor = Cur + Len + 2
    end
    Ser[Str] = StrSer

    const function StrDes()
        const Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const Len = buffer.readu16(Buf, Cur)
        const Value = buffer.readstring(Buf, Cur + 2, Len)
        Cursor = Cur + Len + 2
        return Value
    end
    Des[Str] = StrDes
end

do
    const function Str8Ser(Value: string)
        const Buf = WriteBuffer
        const Cur = Cursor
        const Len = #Value

        buffer.writeu8(Buf, Cur, Len)
        buffer.writestring(Buf, Cur + 1, Value)
        Cursor = Cur + Len + 1
    end
    Ser[Str8] = Str8Ser

    const function Str8Des()
        const Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const Len = buffer.readu8(Buf, Cur)
        const Value = buffer.readstring(Buf, Cur + 1, Len)
        Cursor = Cur + Len + 1
        return Value
    end
    Des[Str8] = Str8Des
end

do
    const function Str24Ser(Value: string)
        const Buf = WriteBuffer
        const Cur = Cursor
        const Len = #Value

        buffer.writeu16(Buf, Cur, bit32.band(Len, 0xFFFF))
        buffer.writeu8(Buf, Cur + 2, bit32.extract(Len, 16, 8))
        buffer.writestring(Buf, Cur + 3, Value)
        Cursor = Cur + Len + 3
    end
    Ser[Str24] = Str24Ser

    const function Str24Des()
        const Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const Low = buffer.readu16(Buf, Cur)
        const High = buffer.readu8(Buf, Cur + 2)
        const Len = bit32.bor(Low, bit32.lshift(High, 16))
        const Value = buffer.readstring(Buf, Cur + 3, Len)
        Cursor = Cur + Len + 3
        return Value
    end
    Des[Str24] = Str24Des
end

do
    const function EnumSer(Value: Enum)
        const WB = WriteBuffer
        const Cur = Cursor
        const Id = EnumMap[Value]

        buffer.writeu16(WB, Cur, Id)
        Cursor = Cur + 2
    end
    Ser[EnumType] = EnumSer

    const function EnumDes()
        const Cur = Cursor
        const Id = buffer.readu16(ReadBuffer :: buffer, Cur)
        Cursor = Cur + 2
        return EnumIdMap[Id]
    end
    Des[EnumType] = EnumDes
end

do
    const function EnumItemSer(Value: EnumItem)
        const WB = WriteBuffer
        const Cur = Cursor
        const EnumParent = Value.EnumType
        const EnumId = EnumMap[EnumParent]

        buffer.writeu16(WB, Cur, EnumId)
        buffer.writeu16(WB, Cur + 2, Value.Value)
        Cursor = Cur + 4
    end
    Ser[EnumItem] = EnumItemSer

    const function EnumItemDes()
        const Buf = ReadBuffer :: buffer
        const Cur = Cursor
        const EnumId = buffer.readu16(Buf, Cur)
        const Id = buffer.readu16(Buf, Cur + 2)
        Cursor = Cur + 4
        return EnumIdMap[EnumId]:FromValue(Id)
    end
    Des[EnumItem] = EnumItemDes
end

Types.U8 = U8
Types.I8 = I8
Types.U16 = U16
Types.I16 = I16
Types.U24 = U24
Types.I24 = I24
Types.U32 = U32
Types.I32 = I32
Types.F32 = F32
Types.F64 = F64
Types.Str = Str
Types.Str8 = Str8
Types.Str24 = Str24
Types.Bool = Bool
Types.Array = Array
Types.Array8 = Array8
Types.Array24 = Array24
Types.Map = Map
Types.Map8 = Map8
Types.Map24 = Map24
Types.Buf = Buf
Types.Buf8 = Buf8
Types.Buf24 = Buf24
Types.Vec = Vec
Types.Void = Void
Types.Nil = Nil
Types.Cframe = Cframe
Types.QCframe = QCframe
Types.RefInstance = RefInstance
Types.SerInstance = SerInstance
Types.Color = Color
Types.Udim2 = Udim2
Types.Udim = Udim
Types.Vec2 = Vec2
Types.EnumItem = EnumItem
Types.EnumType = EnumType
Types.U40 = U40
Types.I40 = I40
Types.U48 = U48
Types.I48 = I48

if RunService:IsClient() then
    const function RetryGetAttribute(Co: thread, Descendant: Instance): ()
        TaskSpawn(Co, Descendant.GetAttribute, Descendant, InstanceRefAttribute)
    end
    
    const function DeferFetch(Descendant: Instance): number?
        const Co = CoroutineRunning()
        TaskDelay(0, RetryGetAttribute, Co, Descendant)
        return CoroutineYield()
    end
    
    const function OnInstance(Descendant: Instance): ()
        local Success: boolean, Id: number? = Pcall(Descendant.GetAttribute :: (Instance, string) -> number?, Descendant, InstanceRefAttribute)
        if not Success or not Id then
            Id = DeferFetch(Descendant)
            
            if not Id then
                return
            end
        end
        IdMap[Id :: number] = Descendant
        InstanceMap[Descendant] = Id
    end

    for _, Descendant in game:GetDescendants() do
        TaskSpawn(OnInstance, Descendant)
    end
    game.DescendantAdded:Connect(OnInstance)
else
    const FreeIds: { number } = {}
    local FreeIdsCount = 0
    local Total = 0

    const function OnInstance(Descendant: Instance): ()
        if FreeIdsCount ~= 0 then
            const Count = FreeIdsCount
            const Id = FreeIds[Count]
            FreeIds[Count] = nil
            FreeIdsCount = Count - 1

            const Success = Pcall(Descendant.SetAttribute, Descendant, InstanceRefAttribute, Id)
            if Success then
                IdMap[Id] = Descendant
                InstanceMap[Descendant] = Id
            end
        else
            const NewTotal = Total + 1
            const Success = Pcall(Descendant.SetAttribute, Descendant, InstanceRefAttribute, NewTotal)
    
            if Success then
                Total = NewTotal
                IdMap[Total] = Descendant
                InstanceMap[Descendant] = NewTotal
            end
        end
    end

    const function OnRemoving(Descendant: Instance): ()
        const Id = InstanceMap[Descendant]
        if Id then
            table.insert(FreeIds, Id)
            FreeIdsCount += 1
        end
        -- the entries are cleaned up automatically
    end

    for _, Descendant in game:GetDescendants() do
        TaskSpawn(OnInstance, Descendant)
    end
    game.DescendantAdded:Connect(OnInstance)
    game.DescendantRemoving:Connect(OnRemoving)
end

for i, En in EnumIdMap do
    EnumMap[En] = i
end

Freeze(Types)
Freeze(Dynamo)

return Dynamo :: Lib
