--!optimize 2
--!native
--[[
	================================================================================
	  BlazeSentry  |  v0.1.7  |  Apache-2.0  |  by IAMNOTULTRA3
	================================================================================
	  Buffer serialization library for Roblox. Converts Luau & Roblox values into
	buffers and back. Supports schema-based (static) and schemaless
	  (dynamic) serialization with optional Zstd compression.

	  Performance Oriented Fork Of VoidSentry2, removes validations for pure performance
	================================================================================
	  API
	================================================================================
	  BlazeSentry.types              -- named type nodes/factories; pass as schema arguments
	  BlazeSentry.static             -- schema-based serializer; fastest, layout known upfront
	  BlazeSentry.dynamic            -- schemaless serializer; tags each value at runtime
	  BlazeSentry.registerInstanceSchema(className, schema) -> ()  -- register layouts for types.serInstance(...)
	  BlazeSentry.combine(t1, t2) -> T1 & T2                       -- shallow merge two tables
	  BlazeSentry.writeStart(offset?) -> ()						  -- start the write operation
	  writeFinish() -> buffer									  -- finish the write operation
	  getWriteCursor() -> number								  -- get the current write position
	  readStart(buf, offset?) -> ()								  -- start the read operation
	  readFinish() -> ()										  -- finish the read operation
	  getReadCursor() -> number								      -- get the current read position
	  updateBigBuffer() -> ()                                     -- resize scratch buffer after maxBufferSize changes
	  setConstant(constant, value) -> ()                          -- update runtime configuration

	  static.serialize(serdes, value, offset?, compressionLevel?) -> buffer?
	  static.deserialize(serdes, buf, offset?, wasCompressed?) -> value?

	  dynamic.serialize(compressionLevel: number?, offset: number?, ...values) -> buffer?
	  dynamic.deserialize(wasCompressed: boolean?, offset: number?, buf: buffer)     -> ...values?
	================================================================================
	  TYPES
	================================================================================
	  INTEGERS            size     range
	    int8              1 B      -128 .. 127
	    uint8             1 B      0 .. 255
	    int16             2 B      -32768 .. 32767
	    uint16            2 B      0 .. 65535
	    int24             3 B      -8388608 .. 8388607
	    uint24            3 B      0 .. 16777215
	    int32             4 B      -2147483648 .. 2147483647
	    uint32            4 B      0 .. 4294967295
	    int40             5 B      -549755813888 .. 549755813887
	    uint40            5 B      0 .. 1099511627775
	    int48             6 B      -140737488355328 .. 140737488355327
	    uint48            6 B      0 .. 281474976710655

	  FLOATS              size     notes
	    float16           2 B      half-precision (IEEE 754)
	    float24           3 B      24-bit custom encoding
	    float32           4 B      single-precision (IEEE 754)
	    float64           8 B      double-precision (IEEE 754)

	  PRIMITIVES          size     notes
	    boolean           1 B      true or false
	    boolPacked        1 B      eight booleans packed in one byte
	    string            2+n B    raw byte string; max 65535 bytes
	    string255         1+n B    raw byte string; max 255 bytes
	    vector            12 B     Luau vector (X Y Z as float32)
	    nothing           0 B      nil; writes and reads nothing

	  COLLECTIONS         size     notes
	    array(T)          2+T(n)   ordered list; max 65535 elements
	    array255(T)       1+T(n)    ordered list; max 255 elements
	    map(K,V)          2+n(K+V)  uint16 n, then n (key,value) pairs; K,V sized per entry if fixed
	    map255(K,V)       1+n (K+V)  uint8 n; max 255 pairs; same layout

	  SPECIAL             size     notes
	    void              0 B      empty table {}; no bytes written
	    struct({k=T})     sum(T)   values only, keys sorted, no names on wire
	    deltaStruct({k=T}) 1+n(1+T) present keys only; u8 count + u8 field ids (max 255)
	    deltaStruct16({k=T}) 2+n(2+T) present keys only; u16 count + u16 field ids (max 65535)
	    optional(T)       1+T?     1 B presence flag; inner T only if present
	    union(T...)       1+T      1 B variant index (max 255 variants); each variant must have a unique exType
	    any               1+T      1 B discriminator + dynamically inferred value

	  ROBLOX TYPES        size     notes
	    vector3           12 B     Vector3 (X Y Z as float32)
	    vector3f24         9 B     Vector3 (X Y Z as float24)
	    vector3f16         6 B     Vector3 (X Y Z as float16)
	    vector2            8 B     Vector2 (X Y as float32)
	    vector2f24         6 B     Vector2 (X Y as float24)
	    vector2f16         4 B     Vector2 (X Y as float16)
	    color3             3 B     Color3 (R G B as uint8, 0-255 per channel)
	    cframe            48 B     CFrame 3x4 matrix (float32 components)
	    cframef24         36 B     CFrame 3x4 matrix (float24 components)
	    cframef16         24 B     CFrame 3x4 matrix (float16 components)
	    qcframe           28 B     CFrame quaternion + position (float32)
	    qcframef24        21 B     CFrame quaternion + position (float24)
	    qcframef16        14 B     CFrame quaternion + position (float16)
		enum			  2  B     Roblox Enumeration (2 bytes for writing the EnumItem Value)
	================================================================================
	  LINKS
	================================================================================
	• Github: https://github.com/Elentium/BlazeSentry
	• Wally: "elentium/BlazeSentry@0.1.7" https://wally.run/package/elentium/BlazeSentry
	• Creator Store: https://create.roblox.com/store/asset/109800466320728
	• Pesde: "pesde add elentium/BlazeSentry" https://pesde.dev/packages/elentium/BlazeSentry
]]
-----------------------------------------------------
-- SERVICES                                        --
-----------------------------------------------------
local RunService = game:GetService("RunService")

-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
local exports = require("@self/shared/exports")
local static = require("@self/serializers/static")
local dynamic = require("@self/serializers/dynamic")
local typeSigns = require("@self/shared/config/typeSigns")
local instanceSchemas = require("@self/static/instanceSchemas")
local typesModule = require("@self/types")
local config = require("@self/shared/config")
local serInstanceSigns = require("@self/static/serInstanceSigns")
local writer = require("@self/buffer/writer")
local reader = require("@self/buffer/reader")

-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------
export type staticSerializer = exports.staticSerializer
export type dynamicSerializer = exports.dynamicSerializer
export type types = exports.blazeSentryTypes
export type BlazeSentry = exports.BlazeSentry
export type constants = exports.blazeSentryConstants
export type possibleNode = exports.possibleNode
export type typeNode<T = any> = exports.typeNode<T>

-----------------------------------------------------
-- VARIABLES                                       --
-----------------------------------------------------
local signMap: { possibleNode } = typesModule.signMap
local types: types = typesModule.types
local editableConstants: { [string]: boolean } = config.editableConstants

-----------------------------------------------------
-- INIT                                            --
-----------------------------------------------------
for name: string, sign: number in typeSigns :: { [string]: number } do
	local node = require(`@self/types/{name}`)
	signMap[sign] = node
	types[name] = node
end

-----------------------------------------------------
-- API					                           --
-----------------------------------------------------
--[[
	Combines 2 tables together (shallow copy)
	@param t1 – the first table
	@param t2 – the second table
	@returns t3 – a new table that contains data of both tables
]]
local function combine<T1, T2>(t1: T1, t2: T2): T1 & T2
	local t3: T1 & T2 = {}
	for key, value in t1 do
		t3[key] = value
	end
	for key, value in t2 do
		t3[key] = value
	end
	return t3
end

--[[
	Registers classname schema & sign in @instanceSchemas and @serInstanceSigns
	@param className – the instance class name to register
	@param schema – the class schema
	@returns ()
]]
local function registerInstanceSchema(className: string, schema: { [string]: typeNode }): ()
	instanceSchemas[className] = schema
	local idx: number = #serInstanceSigns.signLookup + 1
	serInstanceSigns.signLookup[idx] = className
	serInstanceSigns.nameLookup[className] = idx
end

local updateBigBuffer = writer.UPDATEBIGBUFFER

local function setConstant<T>(constant: constants, value: T): ()
	if not editableConstants[constant] then
		return
	end

	if type(value) == "table" then
		local tbl = config[constant]
		for k, v in value :: any do
			tbl[k] = v
		end
	else
		config[constant] = value
		if constant == "maxBufferSize" then
			updateBigBuffer()
		end
	end
end

-----------------------------------------------------
-- MODULE                                          --
-----------------------------------------------------
local BlazeSentry = {
	types = types,
	static = static,
	dynamic = dynamic,
	registerInstanceSchema = registerInstanceSchema,
	combine = combine,
	writeStart = writer.START,
	readStart = reader.START,
	writeFinish = writer.FINISH,
	readFinish = reader.FINISH,
	getWriteCursor = writer.GETCURSOR,
	getReadCursor = reader.GETCURSOR,
	updateBigBuffer = updateBigBuffer,
	setConstant = setConstant,
}

if RunService:IsClient() then
	require("@self/static/instanceMap/client")
else
	require("@self/static/instanceMap/server")
end

return BlazeSentry :: BlazeSentry
