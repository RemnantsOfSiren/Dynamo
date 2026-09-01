--!strict
--!optimize 2
--[[
	Dynamic V0.1.0

	Schemaless serializer for BlazeSentry
	Uses dynanode for dynamic behaviour
]]
-----------------------------------------------------
-- SERVICES                                        --
-----------------------------------------------------
const EncodingService = game:GetService("EncodingService")
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const dynanode = require("../shared/dynanode")
const reader = require("../buffer/reader")
const writer = require("../buffer/writer")

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
const ALG: Enum.CompressionAlgorithm = Enum.CompressionAlgorithm.Zstd

-----------------------------------------------------
-- LOCALIZATIONS                                   --
-----------------------------------------------------
const PACK: <V>(...V) -> { [number]: V, n: number } = table.pack
const UNPACK: <V>({ V }, number?, number?) -> ...V = table.unpack
const DYNANODE_WRITE: (any) -> () = dynanode.write
const W_START: (number?) -> () = writer.START
const W_FINISH: () -> buffer = writer.FINISH
const R_START: (buffer, number?) -> () = reader.START
const R_FINISH: () -> () = reader.FINISH
const LEN: (buffer) -> number = buffer.len
const ISFULL: () -> boolean = reader.ISFULL

-----------------------------------------------------
-- API                                             --
-----------------------------------------------------
const dynamic = {}

@native
function dynamic.serialize(compressionLevel: number?, offset: number?, ...: any): buffer?
	const input: { [number]: any, n: number } = PACK(...)
	const n: number = input.n

	W_START(offset)
	for i = 1, n do
		const value: any = input[i]
		DYNANODE_WRITE(value)
	end
	local b: buffer = W_FINISH()
	if compressionLevel then
		b = EncodingService:CompressBuffer(b, ALG, compressionLevel)
	end

	return b
end

@native
function dynamic.deserialize(wasCompressed: boolean?, offset: number?, input: buffer): ...any
	const output: { any } = {}
	if wasCompressed then
		input = EncodingService:DecompressBuffer(input, ALG)
	end
	if LEN(input) - (offset or 0) == 0 then
		-- empty buffer
		return
	end
	R_START(input, offset)
	local i: number = 0
	while true do
		if ISFULL() then
			break
		end
		i += 1
		output[i] = dynanode.read()
	end
	R_FINISH()
	return UNPACK(output, 1, i)
end

return table.freeze(dynamic)
