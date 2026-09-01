--!strict
--!optimize 2
--[[
	Static V0.1.0

	Schematized serializer for BlazeSentry
	Faster compared to Dynamic serializer as it has no type inferring overhead
]]
-----------------------------------------------------
-- SERVICES                                        --
-----------------------------------------------------
const EncodingService = game:GetService("EncodingService")

-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const exports = require("../shared/exports")
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const ALG: Enum.CompressionAlgorithm = Enum.CompressionAlgorithm.Zstd
-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------
type serializer = exports.staticSerializer
type typeNode<T = any> = exports.typeNode<T>
type extractTypeFromTypeNode<T> = exports.extractTypeFromTypeNode<T>
-----------------------------------------------------
-- LOCALIZE                                        --
-----------------------------------------------------
const W_FINISH: () -> buffer = writer.FINISH
const W_START: (number?) -> () = writer.START
const R_FINISH: () -> () = reader.FINISH
const R_START: (buffer, number?) -> () = reader.START
-----------------------------------------------------
-- API                                             --
-----------------------------------------------------
const static = {}

@native
function static.deserialize<T>(serdes: typeNode & T, input: buffer, offset: number?, wasCompressed: boolean?): extractTypeFromTypeNode<T>?
	if wasCompressed then
		input = EncodingService:DecompressBuffer(input, ALG)
	end
	R_START(input, offset)
	const result: T? = serdes.read()
	R_FINISH()

	return result
end

@native
function static.serialize<T>(serdes: typeNode<T>, input: T, offset: number?, compressionLevel: number?): buffer?
	W_START(offset)
	serdes.write(input)
	local b: buffer = W_FINISH()
	if compressionLevel then
		b = EncodingService:CompressBuffer(b, ALG, compressionLevel)
	end
	return b
end

return table.freeze(static)
