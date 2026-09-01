--!optimize 2
--[[
	InferValueType V0.1.2

	Infers value type in a switch-like style

	supported types:
	- int8
	- int16
	- int32
	- int40
	- int48
	- uint8
	- uint16
	- uint32
	- uint40
	- uint48
	- float32
	- float64
	- boolean
	- string
	- string255
	- array
	- array255
	- map
	- void
	- nothing
	- vector/vector3 (configurable)
	- vector2
	- cframe
	- enum
	- color3
	- instance
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const config = require("./config")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const UNKNOWN: number = config.unknownType
const typeSigns = config.typeSigns
const VECTOR: number = typeSigns.vector
const VECTOR3: number = typeSigns.vector3
const INSTANCE: number = typeSigns.instance
const SERINSTANCE: number = typeSigns.serInstance
const INT48: number = typeSigns.int48
const INT40: number = typeSigns.int40
const INT32: number = typeSigns.int32
const INT16: number = typeSigns.int16
const INT8: number = typeSigns.int8
const UINT48: number = typeSigns.uint48
const UINT40: number = typeSigns.uint40
const UINT32: number = typeSigns.uint32
const UINT16: number = typeSigns.uint16
const UINT8: number = typeSigns.uint8
const FLOAT: number = typeSigns.float32
const FLOAT64: number = typeSigns.float64
const BOOL: number = typeSigns.boolean
const STR: number = typeSigns.string
const STR255: number = typeSigns.string255
const VOID: number = typeSigns.void
const ARRAY: number = typeSigns.array
const MAP: number = typeSigns.map
const ARRAY255: number = typeSigns.array255
const CFRAME: number = typeSigns.cframe
const VECTOR2: number = typeSigns.vector2
const COLOR3: number = typeSigns.color3
const ENUM: number = typeSigns.enum
-----------------------------------------------------
-- LOCALIZATIONS                                   --
-----------------------------------------------------
const TYPE: <T>(T) -> string = typeof
const NEXT: <K, V>({ [K]: V }, K?) -> (K?, V) = next

@native
const function inferValueType<T>(element: T): number
	const vType: string = TYPE(element)

	if vType == "number" then
		const isInteger: boolean = element // 1 == element
		if isInteger then
			if element >= 0 then
				-- unsigned logic
				if element <= 0xFF then
					return UINT8
				elseif element <= 0xFFFF then
					return UINT16
				elseif element <= 0xFFFFFFFF then
					return UINT32
				elseif element <= 1099511627775 then
					return UINT40
				elseif element <= 281474976710655 then
					return UINT48
				end
			else
				-- signed logic
				if element >= -128 then
					return INT8
				elseif element >= -32768 then
					return INT16
				elseif element >= -2147483648 then
					return INT32
				elseif element >= -549755813888 then
					return INT40
				elseif element >= -140737488355328 then
					return INT48
				end
			end

			return FLOAT64
		end

		if element >= -3.4028234663852886e38 and element <= 3.4028234663852886e38 then
			return FLOAT
		end

		return FLOAT64
	elseif vType == "boolean" then
		return BOOL
	elseif vType == "string" then
		return #element <= 255 and STR255 or STR
	elseif vType == "table" then
		const len: number = #element
		-- empty table or a map
		if len == 0 then
			return NEXT(element) == nil and VOID or MAP
		end

		const isMap: boolean = NEXT(element, #element) ~= nil
		return if isMap then MAP else len <= 255 and ARRAY255 or ARRAY
	elseif vType == "Vector3" then
		return config.dynamicVectorType == "vector" and VECTOR or VECTOR3
	elseif vType == "Vector2" then
		return VECTOR2
	elseif vType == "CFrame" then
		return CFRAME
	elseif vType == "Color3" then
		return COLOR3
	elseif vType == "Instance" then
		return config.dynamicInstanceType == "instance" and INSTANCE or SERINSTANCE
	elseif vType == "EnumItem" then
		return ENUM
	end

	return UNKNOWN
end

return inferValueType
