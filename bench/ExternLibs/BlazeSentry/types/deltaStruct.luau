--!strict
--!optimize 2
--[[
	deltaStruct
	1 + n*(1 + field) bytes

	Sparse struct: serializes present input keys only.
	u8 present-count and u8 field ids (max 255 present fields).
	Field ids are 1-based into lexicographically sorted schema keys;
	entry order follows the input table.
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const writer = require("../buffer/writer")
const reader = require("../buffer/reader")
const exports = require("../shared/exports")

-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------
type typeNode<T = any> = exports.typeNode<T>

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const SORT: <V>({ V }, ((V, V) -> boolean)?) -> () = table.sort
const CREATE: <V>(number, V?) -> {V} = table.create
const WRITE_LEN: (number) -> () = writer.U8
const READ_LEN: () -> number = reader.U8
const WRITE_ID: (number) -> () = writer.U8
const READ_ID: () -> number = reader.U8

@native
const function deltaStructNodeBuild<T>(struct: T & { [string]: typeNode }): typeNode<T>
	const keys: { string } = {}
	local idx: number = 0
	for key: string in struct :: { [string]: typeNode } do
		idx += 1
		keys[idx] = key
	end
	SORT(keys)

	const writes = CREATE<<<V>(V) -> ()>>(idx)
	const reads = CREATE<<() -> any>>(idx)
	const lookup: { [string]: number } = {}

	for i: number, key: string in keys do
		const node: typeNode = (struct :: { [string]: typeNode })[key]
		writes[i] = node.write
		reads[i] = node.read
		lookup[key] = i
	end

	-----------------------------------------------------
	-- READ/WRITE                                      --
	-----------------------------------------------------
	@native
	const function deltaStruct_write<V>(value: { [string]: V }): ()
		local len: number = 0
		-- this is very slow, but there is currently no other way to solve that other than changing the library structure; maybe in the next updates
		for key: string in value do
			if lookup[key] ~= nil then
				len += 1
			end
		end
		WRITE_LEN(len)
		for key: string, field: V in value do
			const id: number? = lookup[key]
			if id ~= nil then
				WRITE_ID(id)
				writes[id](field)
			end
		end
	end

	@native
	const function deltaStruct_read(): T
		const out: { [string]: any } = {}
		local len: number = READ_LEN()
		for _ = 1, len do
			const id: number = READ_ID()
			out[keys[id]] = reads[id]()
		end
		return out
	end

	return table.freeze({
		write = deltaStruct_write,
		read = deltaStruct_read,
		exType = "map"
	}) :: typeNode<T>
end

return deltaStructNodeBuild
