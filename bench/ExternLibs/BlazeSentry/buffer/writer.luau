--!strict
--!optimize 2
--[[
	BufferWriter V0.1.1

	Serializes into one reusable big buffer (config.maxBufferSize).
	START sets the write cursor (with optional offset for metadata/headers)
	FINISH allocates a buffer of length `cursor` and copies bigBuffer [0, cursor).
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const config = require("../shared/config")

-----------------------------------------------------
-- LOCALIZE BUILTINS                               --
-----------------------------------------------------
const CREATE: (number) -> buffer = buffer.create
const COPY: (buffer, number, buffer, number?, number?) -> () = buffer.copy

const WRITE_U8: (buffer, number, number) -> () = buffer.writeu8
const WRITE_I8: (buffer, number, number) -> () = buffer.writei8
const WRITE_U16: (buffer, number, number) -> () = buffer.writeu16
const WRITE_I16: (buffer, number, number) -> () = buffer.writei16
const WRITE_U32: (buffer, number, number) -> () = buffer.writeu32
const WRITE_I32: (buffer, number, number) -> () = buffer.writei32
const WRITE_F32: (buffer, number, number) -> () = buffer.writef32
const WRITE_F64: (buffer, number, number) -> () = buffer.writef64
const WRITE_STRING: (buffer, number, string, number?) -> () = buffer.writestring

const ABS: (number) -> number = math.abs
const FREXP: (number) -> (number, number) = math.frexp

const AND: (...number) -> number = bit32.band
const OR: (...number) -> number = bit32.bor
const EXTRACT: (number, number, number?) -> number = bit32.extract
const LSHIFT: (number, number) -> number = bit32.lshift

const HUGE: number = math.huge
const NHUGE: number = -HUGE
const SQRT: (number) -> number = math.sqrt

-----------------------------------------------------
-- STATE                    			           --
-----------------------------------------------------
local bigCap: number = config.maxBufferSize
local bigBuffer: buffer = CREATE(bigCap)

local cursor: number = 0
local off: number = 0

-----------------------------------------------------
-- API                                             --
-----------------------------------------------------
@native
const function need(size: number): boolean
	return cursor + size <= bigCap
end

@native
const function start(offset: number?): ()
	cursor = offset or 0
	off = cursor
end

@native
const function finish(): buffer
	const b: buffer = CREATE(cursor)
	if cursor > 0 then
		-- ensure the offset bytes are all zeroed
		-- if previous operation(s) had no offset – the first bytes have previous data
		COPY(b, off, bigBuffer, off, cursor - off)
	end
	return b
end

-----------------------------------------------------
-- PRIMITIVE WRITES                                --
-----------------------------------------------------
@native
const function writeu8(value: number): ()
	WRITE_U8(bigBuffer, cursor, value)
	cursor += 1
end

@native
const function writei8(value: number): ()
	WRITE_I8(bigBuffer, cursor, value)
	cursor += 1
end

@native
const function writeu16(value: number): ()
	WRITE_U16(bigBuffer, cursor, value)
	cursor += 2
end

@native
const function writei16(value: number): ()
	WRITE_I16(bigBuffer, cursor, value)
	cursor += 2
end

--[[
	Float16 write operation: 1s | 5e(bias15) | 10m
	Special values: ±Inf stored as exp=0x1F mant=0; NaN as exp=0x1F mant=0x200.
]]
@native
const function writef16(value: number): ()
	local packed: number
	if value ~= value then
		packed = 0x7E00
	elseif value == HUGE then
		packed = 0x7C00
	elseif value == NHUGE then
		packed = 0xFC00
	elseif value == 0 then
		packed = 0
	else
		const sign: number = if value < 0 then 1 else 0
		const m: number, e: number = FREXP(ABS(value))
		const biasedExp: number = e + 14
		if biasedExp >= 0x1F then
			packed = OR(LSHIFT(sign, 15), 0x7C00)
		elseif biasedExp <= 0 then
			packed = LSHIFT(sign, 15)
		else
			const mant10: number = ((m * 2 - 1) * 1024 + 0.5) // 1
			packed = OR(LSHIFT(sign, 15), LSHIFT(biasedExp, 10), AND(mant10, 0x3FF))
		end
	end
	WRITE_U16(bigBuffer, cursor, packed)
	cursor += 2
end

@native
const function writeu24(value: number): ()
	WRITE_U16(bigBuffer, cursor, AND(value, 0xFFFF))
	WRITE_U8(bigBuffer, cursor + 2, EXTRACT(value, 16, 8))
	cursor += 3
end

--[[
	Float24 write operation: 1s | 7e(bias63) | 16m
	Layout in buffer: [lo16 of mantissa] [sign(1) | exp(7)]
]]
@native
const function writef24(value: number): ()
	local mant16: number
	local byte2: number
	if value ~= value then
		mant16 = 0x8000
		byte2 = 0x7F
	elseif value == HUGE then
		mant16 = 0
		byte2 = 0x7F
	elseif value == NHUGE then
		mant16 = 0
		byte2 = 0xFF
	elseif value == 0 then
		mant16 = 0
		byte2 = 0
	else
		const sign: number = if value < 0 then 1 else 0
		const m: number, e: number = FREXP(ABS(value))
		const biasedExp: number = e + 62
		if biasedExp >= 0x7F then
			mant16 = 0
			byte2 = OR(LSHIFT(sign, 7), 0x7F)
		elseif biasedExp <= 0 then
			mant16 = 0
			byte2 = LSHIFT(sign, 7)
		else
			const frac: number = m * 2 - 1
			mant16 = AND((frac * 65536 + 0.5) // 1, 0xFFFF)
			byte2 = OR(LSHIFT(sign, 7), biasedExp)
		end
	end
	WRITE_U16(bigBuffer, cursor, mant16)
	WRITE_U8(bigBuffer, cursor + 2, byte2)
	cursor += 3
end

@native
const function writeu32(value: number): ()
	WRITE_U32(bigBuffer, cursor, value)
	cursor += 4
end

@native
const function writei32(value: number): ()
	WRITE_I32(bigBuffer, cursor, value)
	cursor += 4
end

@native
const function writef32(value: number): ()
	WRITE_F32(bigBuffer, cursor, value)
	cursor += 4
end

@native
const function writef64(value: number): ()
	WRITE_F64(bigBuffer, cursor, value)
	cursor += 8
end

@native
const function writes255(value: string, len: number): ()
	WRITE_U8(bigBuffer, cursor, len)
	cursor += 1
	WRITE_STRING(bigBuffer, cursor, value)
	cursor += len
end

@native
const function writes65(value: string, len: number): ()
	WRITE_U16(bigBuffer, cursor, len)
	cursor += 2
	WRITE_STRING(bigBuffer, cursor, value)
	cursor += len
end

@native 
const function writeu40(value: number): ()
	const lower: number = value % 0x100000000
	const upper: number = value // 0x100000000
	WRITE_U32(bigBuffer, cursor, lower)
	cursor += 4
	WRITE_U8(bigBuffer, cursor, upper)
	cursor += 1
end

@native
const function writeu48(value: number): ()
	const lower: number = value % 0x100000000
	const upper: number = AND(value // 0x100000000, 0xFFFF)
	WRITE_U32(bigBuffer, cursor, lower)
	cursor += 4
	WRITE_U16(bigBuffer, cursor, upper)
	cursor += 2
end

@native
const function writev2f32(value: Vector2): ()
	WRITE_F32(bigBuffer, cursor, value.X)
	cursor += 4
	WRITE_F32(bigBuffer, cursor, value.Y)
	cursor += 4
end

@native
const function writev2f24(value: Vector2): ()
	writef24(value.X)
	writef24(value.Y)
end

@native
const function writev2f16(value: Vector2): ()
	writef16(value.X)
	writef16(value.Y)
end

@native
const function writevf32(value: vector | Vector3): ()
	WRITE_F32(bigBuffer, cursor, value.x)
	cursor += 4
	WRITE_F32(bigBuffer, cursor, value.y)
	cursor += 4
	WRITE_F32(bigBuffer, cursor, value.z)
	cursor += 4
end

@native
const function writevf24(value: vector | Vector3): ()
	writef24(value.x)
	writef24(value.y)
	writef24(value.z)
end

@native
const function writevf16(value: vector | Vector3): ()
	writef16(value.x)
	writef16(value.y)
	writef16(value.z)
end

@native
const function writecolor3(value: Color3): ()
	WRITE_U8(bigBuffer, cursor, value.R * 255 // 1)
	cursor += 1
	WRITE_U8(bigBuffer, cursor, value.G * 255 // 1)
	cursor += 1
	WRITE_U8(bigBuffer, cursor, value.B * 255 // 1)
	cursor += 1
end

@native
const function writecf32(value: CFrame): ()
	const x: number, y: number, z: number, R0: number, R01: number, R02: number, R10: number, R11: number, R12: number, R20: number, R21: number, R22: number =
		value:GetComponents()
	
	WRITE_F32(bigBuffer, cursor, x)
	cursor += 4
	WRITE_F32(bigBuffer, cursor, y)
	cursor += 4
	WRITE_F32(bigBuffer, cursor, z)
	cursor += 4
	WRITE_F32(bigBuffer, cursor, R0)
	cursor += 4
	WRITE_F32(bigBuffer, cursor, R01)
	cursor += 4
	WRITE_F32(bigBuffer, cursor, R02)
	cursor += 4
	WRITE_F32(bigBuffer, cursor, R10)
	cursor += 4
	WRITE_F32(bigBuffer, cursor, R11)
	cursor += 4
	WRITE_F32(bigBuffer, cursor, R12)
	cursor += 4
	WRITE_F32(bigBuffer, cursor, R20)
	cursor += 4
	WRITE_F32(bigBuffer, cursor, R21)
	cursor += 4
	WRITE_F32(bigBuffer, cursor, R22)
	cursor += 4
end

@native
const function writecf24(value: CFrame): ()
	const x: number, y: number, z: number, R0: number, R01: number, R02: number, R10: number, R11: number, R12: number, R20: number, R21: number, R22: number =
		value:GetComponents()
	
	writef24(x)
	writef24(y)
	writef24(z)
	writef24(R0)
	writef24(R01)
	writef24(R02)
	writef24(R10)
	writef24(R11)
	writef24(R12)
	writef24(R20)
	writef24(R21)
	writef24(R22)
end

@native
const function writecf16(value: CFrame): ()
	const x: number, y: number, z: number, R0: number, R01: number, R02: number, R10: number, R11: number, R12: number, R20: number, R21: number, R22: number =
		value:GetComponents()
	
	writef16(x)
	writef16(y)
	writef16(z)
	writef16(R0)
	writef16(R01)
	writef16(R02)
	writef16(R10)
	writef16(R11)
	writef16(R12)
	writef16(R20)
	writef16(R21)
	writef16(R22)
end

@native const function writeqcf32(value: CFrame): ()
	-- inline quaternion extracting
	const x: number, y: number, z: number, R0: number, R01: number, R02: number, R10: number, R11: number, R12: number, R20: number, R21: number, R22: number =
        value:GetComponents()

    const trace: number = R0 + R11 + R22
    local qx: number, qy: number, qz: number, qw: number

    if trace > 0 then
        const root = SQRT(trace + 1)
        qw = 0.5 * root
        const invS = 0.5 / root
        qx = (R21 - R12) * invS
        qy = (R02 - R20) * invS
        qz = (R10 - R01) * invS
    elseif (R0 > R11) and (R0 > R22) then
        const root = SQRT(1 + R0 - R11 - R22)
        qx = 0.5 * root
        const invS = 0.5 / root
        qw = (R21 - R12) * invS
        qy = (R01 + R10) * invS
        qz = (R02 + R20) * invS
    elseif R11 > R22 then
        const root = SQRT(1 + R11 - R0 - R22)
        qy = 0.5 * root
        const invS = 0.5 / root
        qw = (R02 - R20) * invS
        qx = (R01 + R10) * invS
        qz = (R12 + R21) * invS
    else
        const root = SQRT(1 + R22 - R0 - R11)
        qz = 0.5 * root
        const invS = 0.5 / root
        qw = (R10 - R01) * invS
        qx = (R02 + R20) * invS
        qy = (R12 + R21) * invS
    end
	-----------------------------------------------------------

	WRITE_F32(bigBuffer, cursor, x)
	cursor += 4
	WRITE_F32(bigBuffer, cursor, y)
	cursor += 4
	WRITE_F32(bigBuffer, cursor, z)
	cursor += 4
	WRITE_F32(bigBuffer, cursor, qx)
	cursor += 4
	WRITE_F32(bigBuffer, cursor, qy)
	cursor += 4
	WRITE_F32(bigBuffer, cursor, qz)
	cursor += 4
	WRITE_F32(bigBuffer, cursor, qw)
	cursor += 4
end

@native const function writeqcf24(value: CFrame): ()
	-- inline quaternion extracting
	const x: number, y: number, z: number, R0: number, R01: number, R02: number, R10: number, R11: number, R12: number, R20: number, R21: number, R22: number =
        value:GetComponents()

    const trace: number = R0 + R11 + R22
    local qx: number, qy: number, qz: number, qw: number

    if trace > 0 then
        const root = SQRT(trace + 1)
        qw = 0.5 * root
        const invS = 0.5 / root
        qx = (R21 - R12) * invS
        qy = (R02 - R20) * invS
        qz = (R10 - R01) * invS
    elseif (R0 > R11) and (R0 > R22) then
        const root = SQRT(1 + R0 - R11 - R22)
        qx = 0.5 * root
        const invS = 0.5 / root
        qw = (R21 - R12) * invS
        qy = (R01 + R10) * invS
        qz = (R02 + R20) * invS
    elseif R11 > R22 then
        const root = SQRT(1 + R11 - R0 - R22)
        qy = 0.5 * root
        const invS = 0.5 / root
        qw = (R02 - R20) * invS
        qx = (R01 + R10) * invS
        qz = (R12 + R21) * invS
    else
        const root = SQRT(1 + R22 - R0 - R11)
        qz = 0.5 * root
        const invS = 0.5 / root
        qw = (R10 - R01) * invS
        qx = (R02 + R20) * invS
        qy = (R12 + R21) * invS
    end
	-----------------------------------------------------------

	writef24(x)
	writef24(y)
	writef24(z)
	writef24(qx)
	writef24(qy)
	writef24(qz)
	writef24(qw)
end

@native 
const function writeqcf16(value: CFrame): ()
	-- inline quaternion extracting
	const x: number, y: number, z: number, R0: number, R01: number, R02: number, R10: number, R11: number, R12: number, R20: number, R21: number, R22: number =
        value:GetComponents()

    const trace: number = R0 + R11 + R22
    local qx: number, qy: number, qz: number, qw: number

    if trace > 0 then
        const root = SQRT(trace + 1)
        qw = 0.5 * root
        const invS = 0.5 / root
        qx = (R21 - R12) * invS
        qy = (R02 - R20) * invS
        qz = (R10 - R01) * invS
    elseif (R0 > R11) and (R0 > R22) then
        const root = SQRT(1 + R0 - R11 - R22)
        qx = 0.5 * root
        const invS = 0.5 / root
        qw = (R21 - R12) * invS
        qy = (R01 + R10) * invS
        qz = (R02 + R20) * invS
    elseif R11 > R22 then
        const root = SQRT(1 + R11 - R0 - R22)
        qy = 0.5 * root
        const invS = 0.5 / root
        qw = (R02 - R20) * invS
        qx = (R01 + R10) * invS
        qz = (R12 + R21) * invS
    else
        const root = SQRT(1 + R22 - R0 - R11)
        qz = 0.5 * root
        const invS = 0.5 / root
        qw = (R10 - R01) * invS
        qx = (R02 + R20) * invS
        qy = (R12 + R21) * invS
    end
	-----------------------------------------------------------

	writef16(x)
	writef16(y)
	writef16(z)
	writef16(qx)
	writef16(qy)
	writef16(qz)
	writef16(qw)
end

@native 
const function getcursor(): number
	return cursor
end

@native
const function updateBigBuffer(): ()
	const cap = config.maxBufferSize
	if cap == bigCap then
		return
	end
	const prev = bigBuffer
	bigBuffer = CREATE(cap)
	COPY(bigBuffer, 0, prev, 0, bigCap)
	bigCap = cap
end

return table.freeze({
	START = start,
	FINISH = finish,
	NEED = need,
	GETCURSOR = getcursor,
	UPDATEBIGBUFFER = updateBigBuffer,

	U8 = writeu8,
	I8 = writei8,
	U16 = writeu16,
	I16 = writei16,
	F16 = writef16,
	F24 = writef24,
	U24 = writeu24,
	I24 = writeu24, -- write process is the same, the read isn't
	U32 = writeu32,
	I32 = writei32,
	U40 = writeu40,
	I40 = writeu40, -- same thing here, the same write process
	U48 = writeu48,
	I48 = writeu48,
	F32 = writef32,
	F64 = writef64,
	STR_S = writes255,
	STR = writes65,

	V2F32 = writev2f32,
	V2F24 = writev2f24,
	V2F16 = writev2f16,
	VF32 = writevf32,
	VF24 = writevf24,
	VF16 = writevf16,
	COLOR3 = writecolor3,
	CF32 = writecf32,
	CF24 = writecf24,
	CF16 = writecf16,
	QCF32 = writeqcf32,
	QCF24 = writeqcf24,
	QCF16 = writeqcf16,
})
