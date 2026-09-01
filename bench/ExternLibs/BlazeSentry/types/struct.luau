--!strict
--!optimize 2
--[[
	struct
	nodeSize per node bytes

	predefined schema which does not serialize keys, only values
	better than map if the keys are known on both sides
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const exports = require("../shared/exports")

-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------
type typeNode<T = any> = exports.typeNode<T>

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const SORT: <V>({ V }, ((V, V) -> boolean)?) -> () = table.sort

@native
const function structNodeBuild<T>(struct: T & { [string]: typeNode }): typeNode<T>
	const keys: { string } = {}
	const writes: { [string]: <T>(T) -> () } = {}
	const reads: { [string]: () -> any } = {}
	for key: string, value: typeNode in struct :: { [string]: typeNode } do
		keys[#keys + 1] = key
		writes[key] = value.write
		reads[key] = value.read
	end
	SORT(keys)

	-----------------------------------------------------
	-- READ/WRITE                                      --
	-----------------------------------------------------
	@native
	const function struct_write<V>(value: { [string]: V } & T): ()
		for _, key: string in keys do
			writes[key](value[key])
		end
	end

	@native
	const function struct_read(): T
		const out: { [string]: any } = {}

		for _, key: string in keys do
			out[key] = reads[key]()
		end

		return out
	end

	return table.freeze({
		write = struct_write,
		read = struct_read,
		exType = "map"
	}) :: typeNode<T>
end

return structNodeBuild
