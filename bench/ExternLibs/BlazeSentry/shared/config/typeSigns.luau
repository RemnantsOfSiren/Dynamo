--!strict
--!optimize 2
--[[
	BlazeSentry Type Signs
	Maps type names to their 1-byte discriminator values written on the wire.
]]
return {
	-- NUMBER TYPES
	int8 = 1,
	uint8 = 2,
	int16 = 3,
	uint16 = 4,
	float16 = 5,
	int24 = 6,
	uint24 = 7,
	float24 = 8,
	int32 = 9,
	uint32 = 10,
	float32 = 11,
	int40 = 12,
	uint40 = 13,
	int48 = 14,
	uint48 = 15,
	float64 = 16,

	-- PRIMITIVE TYPES
	string = 17,
	string255 = 18,
	boolean = 19,
	vector = 20,

	-- COLLECTION TYPES
	array = 21,
	array255 = 22,
	map = 23,
	map255 = 24,

	-- SPECIAL TYPES
	void = 25,
	struct = 26,
	any = 27,
	nothing = 28,
	optional = 29,

	-- ROBLOX TYPES
	vector3 = 30,
	cframe = 31,
	cframef24 = 32,
	cframef16 = 33,
	qcframe = 34,
	qcframef24 = 35,
	qcframef16 = 36,
	color3 = 37,
	vector2 = 38,
	vector2f24 = 39,
	vector2f16 = 40,
	vector3f24 = 41,
	vector3f16 = 42,
	instance = 43,
	serInstance = 44,
	enum = 45,
	union = 46,
	boolPacked = 47,
	deltaStruct = 48,
	deltaStruct16 = 49,
}
