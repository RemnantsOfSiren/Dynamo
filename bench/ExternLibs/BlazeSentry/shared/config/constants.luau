--!strict
--!optimize 2
--[[
	BlazeSentry Constants
	Static configuration values with no dependencies.
]]
return {
	-- When serializing, BlazeSentry writes into a single reusable scratch buffer.
	-- FINISH copies bytes [0, cursor) into an exact-sized buffer.
	-- NOTE: Scratch buffer capacity; writes past this are unchecked.
	maxBufferSize = 10_000_000,

	-- Which type will be inferred when the input value is a vector
	dynamicVectorType = "vector" :: "Vector3" | "vector",
	-- Which value will be inferred when the input value is an instance
	dynamicInstanceType = "instance" :: "serInstance" | "instance",

	-- Instance unique id attribute name
	instanceIdAttribute = "_VSID",

	unknownType = 0,
	unsupportedUnionExTypes = {
		union = true,
		any = true,
		void = true,
		optional = true,
	},
}
