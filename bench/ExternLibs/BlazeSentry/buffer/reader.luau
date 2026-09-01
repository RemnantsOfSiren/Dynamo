--!strict
--!optimize 2
--[[
    BufferReader V0.1.1

	Middleware for deserializing the current buffer
	manages overflow handling, offset pointer(cursor), extra types(float16, float24, uint24, int24)
]]
-----------------------------------------------------
-- STATE                                           --
-----------------------------------------------------
local currentBuffer: buffer? = nil
local cursor: number = 0
local len: number = 0

-----------------------------------------------------
-- LOCALIZE BUILTINS                               --
-----------------------------------------------------
const READ_U8: (buffer, number) -> number = buffer.readu8
const READ_I8: (buffer, number) -> number = buffer.readi8
const READ_U16: (buffer, number) -> number = buffer.readu16
const READ_I16: (buffer, number) -> number = buffer.readi16
const READ_U32: (buffer, number) -> number = buffer.readu32
const READ_I32: (buffer, number) -> number = buffer.readi32
const READ_F32: (buffer, number) -> number = buffer.readf32
const READ_F64: (buffer, number) -> number = buffer.readf64
const READ_STRING: (buffer, number, number) -> string = buffer.readstring
const LEN: (buffer) -> number = buffer.len

const LDEXP: (number, number) -> number = math.ldexp

const AND: (...number) -> number = bit32.band
const OR: (...number) -> number = bit32.bor
const LSHIFT: (number, number) -> number = bit32.lshift
const EXTRACT: (number, number, number?) -> number = bit32.extract

const VECTOR2_NEW: (number?, number?) -> Vector2 = Vector2.new
const VECTOR_CREATE: (number, number, number?) -> vector = vector.create
const COLOR3_FROM_RGB: (number?, number?, number?) -> Color3 = Color3.fromRGB
const CFRAME_NEW: (() -> CFrame) & ((Vector3) -> CFrame) & ((Vector3, Vector3) -> CFrame) & ((number, number, number) -> CFrame) & ((number, number, number, number, number, number, number) -> CFrame) & ((
    number,
    number,
    number,
    number,
    number,
    number,
    number,
    number,
    number,
    number,
    number,
    number
) -> CFrame) = CFrame.new

const NAN: number = math.nan
const HUGE: number = math.huge

-----------------------------------------------------
-- API                                             --
-----------------------------------------------------
--[[
    Initializes the variables for the reader operations
]]
@native
const function start(b: buffer, offset: number?): ()
	currentBuffer = b
	cursor = offset or 0
	len = LEN(b)
end

--[[
    Removes the buffer reference to GC the buffer
]]
@native
const function finish(): ()
	currentBuffer, cursor, len = nil, 0, 0
end

--[[
    UInt8 read operation
]]
@native
const function readu8(): number
	const value: number = READ_U8(currentBuffer :: buffer, cursor)
	cursor += 1
	return value
end

--[[
    Int8 read operation
]]
@native
const function readi8(): number
	const value: number = READ_I8(currentBuffer :: buffer, cursor)
	cursor += 1
	return value
end

--[[
    UInt16 read operation
]]
@native
const function readu16(): number
	const value: number = READ_U16(currentBuffer :: buffer, cursor)
	cursor += 2
	return value
end

--[[
    Int16 read operation
]]
@native
const function readi16(): number
	const value: number = READ_I16(currentBuffer :: buffer, cursor)
	cursor += 2
	return value
end

--[[
    Float16 read operation
    Unpacks 1s|5e(bias15)|10m.
    Special values: ±Inf and NaN are preserved.
]]
@native
const function readf16(): number
	const packed: number = READ_U16(currentBuffer :: buffer, cursor)
	cursor += 2

	const sign: number = EXTRACT(packed, 15, 1)
	const exp16: number = EXTRACT(packed, 10, 5)
	const mant10: number = EXTRACT(packed, 0, 10)

	local result: number
	if exp16 == 0x1F then
		result = if mant10 ~= 0 then NAN else HUGE
	elseif exp16 == 0 then
		result = 0
	else
		-- Normal: (1 + mant10/1024) * 2^(exp16 - 15)
		result = LDEXP(1 + mant10 / 1024, exp16 - 15)
	end

	if sign == 1 then
		result = -result
	end
	return result
end

--[[
    UInt24 read operation
]]
@native
const function readu24(): number
	const low: number = READ_U16(currentBuffer :: buffer, cursor)
	const high: number = READ_U8(currentBuffer :: buffer, cursor + 2)
	cursor += 3
	return OR(low, LSHIFT(high, 16))
end

--[[
    Int24 read operation
]]
@native
const function readi24(): number
	const low: number = READ_U16(currentBuffer :: buffer, cursor)
	const high: number = READ_U8(currentBuffer :: buffer, cursor + 2)
	cursor += 3

	local value: number = OR(low, LSHIFT(high, 16))
	-- bit32.arshift returns an unsigned 32-bit number; manually sign-extend to 24-bit.
	if value >= 0x800000 then
		value -= 0x1000000
	end
	return value
end

--[[
    Float24 read operation
    Unpacks 16m | (1s | 7e(bias63)).
    Special values: ±Inf and NaN are preserved (exp24=0x7F).
]]
@native
const function readf24(): number
	const mant16: number = READ_U16(currentBuffer :: buffer, cursor)
	const byte2: number = READ_U8(currentBuffer :: buffer, cursor + 2)
	cursor += 3

	const sign: number = EXTRACT(byte2, 7, 1)
	const exp24: number = AND(byte2, 0x7F)

	local result: number
	if exp24 == 0x7F then
		result = if mant16 ~= 0 then NAN else HUGE
	elseif exp24 == 0 then
		result = 0
	else
		-- Normal: (1 + mant16/65536) * 2^(exp24 - 63)
		result = LDEXP(1 + mant16 / 65536, exp24 - 63)
	end

	if sign == 1 then
		result = -result
	end

	return result
end

--[[
    UInt32 read operation
]]
@native
const function readu32(): number
	const value: number = READ_U32(currentBuffer :: buffer, cursor)
	cursor += 4
	return value
end

--[[
    Int32 read operation
]]
@native
const function readi32(): number
	const value: number = READ_I32(currentBuffer :: buffer, cursor)
	cursor += 4
	return value
end

--[[
    Float32 read operation
]]
@native
const function readf32(): number
	const value: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	return value
end

--[[
    Float64 read operation
]]
@native
const function readf64(): number
	const value: number = READ_F64(currentBuffer :: buffer, cursor)
	cursor += 8
	return value
end

--[[
    String255 read operation
]]
@native
const function reads255(): string
	const strlen: number = READ_U8(currentBuffer :: buffer, cursor)
	cursor += 1
	const value: string = READ_STRING(currentBuffer :: buffer, cursor, strlen)
	cursor += strlen
	return value
end

--[[
    String65535 read operation
]]
@native
const function reads65(): string
	const strlen: number = READ_U16(currentBuffer :: buffer, cursor)
	cursor += 2
	const value: string = READ_STRING(currentBuffer :: buffer, cursor, strlen)
	cursor += strlen
	return value
end

@native const function readu40(): number
	const lower: number = READ_U32(currentBuffer :: buffer, cursor)
	cursor += 4
	const upper: number = READ_U8(currentBuffer :: buffer, cursor)
	cursor += 1

	const value: number = upper * 0x100000000 + lower

	return value
end

@native const function readi40(): number
	const lower: number = READ_U32(currentBuffer :: buffer, cursor)
	cursor += 4
	const upper: number = READ_U8(currentBuffer :: buffer, cursor)
	cursor += 1

	local value: number = upper * 0x100000000 + lower
	if upper >= 0x80 then
		value -= 0x10000000000
	end

	return value
end

@native const function readu48(): number
	const lower: number = READ_U32(currentBuffer :: buffer, cursor)
	cursor += 4
	const upper: number = READ_U16(currentBuffer :: buffer, cursor)
	cursor += 2

	const value: number = upper * 0x100000000 + lower

	return value
end

@native const function readi48(): number
	const lower: number = READ_U32(currentBuffer :: buffer, cursor)
	cursor += 4
	const upper: number = READ_U16(currentBuffer :: buffer, cursor)
	cursor += 2

	local value: number = upper * 0x100000000 + lower
	if upper >= 0x8000 then
		value -= 0x1000000000000
	end

	return value
end

@native const function readv2f32(): Vector2
	const x: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	const y: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	return VECTOR2_NEW(x, y)
end

@native const function readv2f24(): Vector2
	const x = readf24()
	const y = readf24()
	return VECTOR2_NEW(x, y)
end

@native const function readv2f16(): Vector2
	const x: number = readf16()
	const y: number = readf16()
	return VECTOR2_NEW(x, y)
end

@native const function readvf32(): vector
	const x: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	const y: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	const z: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	return VECTOR_CREATE(x, y, z)
end

@native const function readvf24(): vector
	const x = readf24()
	const y = readf24()
	const z = readf24()
	return VECTOR_CREATE(x, y, z)
end

@native const function readvf16(): vector
	const x = readf16()
	const y = readf16()
	const z = readf16()
	return VECTOR_CREATE(x, y, z)
end

@native const function readcolor3(): Color3
	const r: number = READ_U8(currentBuffer :: buffer, cursor)
	cursor += 1
	const g: number = READ_U8(currentBuffer :: buffer, cursor)
	cursor += 1
	const b: number = READ_U8(currentBuffer :: buffer, cursor)
	cursor += 1
	return COLOR3_FROM_RGB(r, g, b)
end

@native const function readcf32(): CFrame
	const x: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	const y: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	const z: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	const R0: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	const R01: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	const R02: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	const R10: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	const R11: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	const R12: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	const R20: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	const R21: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	const R22: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	return CFRAME_NEW(x, y, z, R0, R01, R02, R10, R11, R12, R20, R21, R22)
end

@native const function readcf24(): CFrame
	const x = readf24()
	const y = readf24()
	const z = readf24()
	const R0 = readf24()
	const R01 = readf24()
	const R02 = readf24()
	const R10 = readf24()
	const R11 = readf24()
	const R12 = readf24()
	const R20 = readf24()
	const R21 = readf24()
	const R22 = readf24()
	return CFRAME_NEW(x, y, z, R0, R01, R02, R10, R11, R12, R20, R21, R22)
end

@native const function readcf16(): CFrame
	const x = readf16()
	const y = readf16()
	const z = readf16()
	const R0 = readf16()
	const R01 = readf16()
	const R02 = readf16()
	const R10 = readf16()
	const R11 = readf16()
	const R12 = readf16()
	const R20 = readf16()
	const R21 = readf16()
	const R22 = readf16()
	return CFRAME_NEW(
		x, y, z, R0, R01, R02, R10, R11, R12, R20, R21, R22
	)
end

@native const function readqcf32(): CFrame
	const x: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	const y: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	const z: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	const qx: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	const qy: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	const qz: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	const qw: number = READ_F32(currentBuffer :: buffer, cursor)
	cursor += 4
	return CFRAME_NEW(x, y, z, qx, qy, qz, qw)
end

@native const function readqcf24(): CFrame
	const x = readf24()
	const y = readf24()
	const z = readf24()
	const qx = readf24()
	const qy = readf24()
	const qz = readf24()
	const qw = readf24()
	return CFRAME_NEW(x, y, z, qx, qy, qz, qw)
end

@native const function readqcf16(): CFrame
	const x = readf16()
	const y = readf16()
	const z = readf16()
	const qx = readf16()
	const qy = readf16()
	const qz = readf16()
	const qw = readf16()
	return CFRAME_NEW(x, y, z, qx, qy, qz, qw)
end

@native const function getcursor(): number
	return cursor
end

@native const function isFull(): boolean
	return cursor >= len
end

return table.freeze({
	U8 = readu8,
	I8 = readi8,
	U16 = readu16,
	I16 = readi16,
	F16 = readf16,
	U24 = readu24,
	I24 = readi24,
	F24 = readf24,
	U32 = readu32,
	I32 = readi32,
	F32 = readf32,
	U40 = readu40,
	I40 = readi40,
	U48 = readu48,
	I48 = readi48,
	F64 = readf64,
	STR_S = reads255,
	STR = reads65,

	V2F32 = readv2f32,
	V2F24 = readv2f24,
	V2F16 = readv2f16,
	VF32 = readvf32,
	VF24 = readvf24,
	VF16 = readvf16,
	COLOR3 = readcolor3,
	CF32 = readcf32,
	CF24 = readcf24,
	CF16 = readcf16,
	QCF32 = readqcf32,
	QCF24 = readqcf24,
	QCF16 = readqcf16,

	START = start,
	FINISH = finish,
	GETCURSOR = getcursor,
	ISFULL = isFull
})