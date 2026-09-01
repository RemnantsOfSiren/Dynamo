--!strict
--!optimize 2
--[[
	SerializedInstance
	struct bytes

    If the instance is supported (the class struct is defined) it will serialize the defined properties.
    On deserialization creates a new instance and sets up the properties.
]]
-----------------------------------------------------
-- DEPENDENCIES                                    --
-----------------------------------------------------
const exports = require("../shared/exports")
const struct = require("./struct") -- manual require to avoid recursive requires
const instanceSchemas = require("../static/instanceSchemas")

-----------------------------------------------------
-- TYPES                                           --
-----------------------------------------------------
type typeNode<T = any> = exports.typeNode<T>

-----------------------------------------------------
-- CONSTANTS                                       --
-----------------------------------------------------
-----------------------------------------------------
-- STATE                                           --
-----------------------------------------------------
-- Compiled struct nodes keyed by className, built on first call per class.
-- instanceSchemas is populated by src/init.luau after all type nodes exist,
-- so compilation is deferred to first use to guarantee nodes are non-nil.
const compiledSchemas: { [string]: typeNode & { T: { [string]: typeNode } } } = {}

-----------------------------------------------------
-- LOCALIZING                                      --
-----------------------------------------------------
const NEW: (string, Instance?) -> Instance = Instance.new

@native
const function serInstanceNodeBuild(className: string): typeNode<Instance>
	const cached: typeNode & { T: { [string]: typeNode } } = compiledSchemas[className]
	if cached then
		return cached
	end

	const propertiesSchema: { [string]: typeNode } = instanceSchemas[className]
	if not propertiesSchema then
		error(
			`[BlazeSentry]: Failed to serialize SerInstance type – Unsupported/Undefined Schema for ClassName {className}`,
			0
		)
	end

	const structNode = struct(propertiesSchema)
	const schema: typeNode & { T: { [string]: typeNode } } = table.freeze({
		write = structNode.write,
		read = structNode.read,
		T = propertiesSchema,
	}) :: typeNode & { T: { [string]: typeNode } }
	compiledSchemas[className] = schema

	-----------------------------------------------------
	-- READ/WRITE                                      --
	-----------------------------------------------------
	@native
	const function serInstance_write(value: Instance): ()
		const tbl: { [string]: any } = {}
		for property: string in schema.T do
			tbl[property] = (value :: any)[property]
		end
		schema.write(tbl)
	end

	@native
	const function serInstance_read(): Instance
		const tbl: { [string]: any } = schema.read()
		const inst: Instance = NEW(className)
		for property: string, value: any in tbl do
			(inst :: any)[property] = value
		end
		return inst
	end

	return table.freeze({
		write = serInstance_write,
		read = serInstance_read,
		exType = "Instance"
	}) :: typeNode
end

return serInstanceNodeBuild
