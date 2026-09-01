--!strict
--[[
	BlazeSentry Type Exports Module
]]
export type possibleNode = typeNode | (...any) -> typeNode
export type typeNode<T = any> = {
	write: (value: T) -> (),
	read: () -> (T),
	_T: T,
	exType: string
}

export type staticSerializer = {
	serialize: <T>(serdes: typeNode<T>, input: T, offset: number?, compressionLevel: number?) -> buffer,
	deserialize: <T>(serdes: T, input: buffer, offset: number?, wasCompressed: boolean?) -> extractTypeFromTypeNode<T>,
}

export type dynamicSerializer = {
	serialize: <T...>(compressionLevel: number?, offset: number?, T...) -> buffer?,
	deserialize: (wasCompressed: boolean?, offset: number?, input: buffer) -> ...any?,
}

export type instanceSchemas = {
	[string]: {
		[string]: any,
	},
}

export type function getItemType(input: type): type
	if input.tag ~= "extern" then
		error(`Expected input tag to be extern, but got {input.tag}`, 0)
	end
	
	for _, value in input:properties() do
		const read = value.read
		if read and read.tag == "extern" then
			return read
		end
	end

	error(`Provided input type does not contain extern properties`)
end

export type function extractTypeFromTypeNode(input: type): type
	if input.tag ~= "table" then
		error(`Expected input tag to be table, but got {input.tag}`, 0)
	end
	
	const singleton = types.singleton("_T")
	const readresult = input:readproperty(singleton)
	if not readresult then
		error(`Read result is nil`, 0)
	end
	return readresult
end

export type function extractTypesFromTypeNodes(input: type)
	if input.tag ~= "table" then
		error(`Expected input tag to be table, but got {input.tag}`, 0)
	end
    local tbl = types.newtable()
    for key, value in input:properties() do
        tbl:setproperty(key, extractTypeFromTypeNode(value.read))
    end
    return tbl
end

export type function unionOfPack(input: type)
	if input.tag ~= "function" then
		error(`Expected input tag to be function, but got {input.tag}, 0`)
	end
	const head: { type }? = input:parameters().head
	if not head then
		error(`Head does not exist`)
	end

	const tbl: { type } = {}
	const tmap: { [type]: boolean } = {}
	for _, typeNode in head do
		const extracted: type = extractTypeFromTypeNode(typeNode)
		local flag: boolean = false
		for t in tmap do
			if t == extracted then
				flag = true
				break
			end
		end
		if flag then
			continue 
		end
		tmap[extracted] = true
		tbl[#tbl + 1] = extracted
	end
	return types.unionof(table.unpack(tbl))
end

export type table<KEY = any, VALUE = any> = { [KEY]: VALUE }
export type blazeSentryTypes = {
	-- NUMBER TYPES --
	int8: typeNode<number>,
	uint8: typeNode<number>,
	int16: typeNode<number>,
	uint16: typeNode<number>,
	float16: typeNode<number>,
	int24: typeNode<number>,
	uint24: typeNode<number>,
	float24: typeNode<number>,
	int32: typeNode<number>,
	uint32: typeNode<number>,
	int40: typeNode<number>,
	uint40: typeNode<number>,
	int48: typeNode<number>,
	uint48: typeNode<number>,
	float32: typeNode<number>,
	float64: typeNode<number>,

	-- PRIMITIVE TYPES --
	boolean: typeNode<boolean>,
	string: typeNode<string>,
	string255: typeNode<string>,
	vector: typeNode<vector>,
	nothing: typeNode<nil>,

	-- COLLECTION TYPES --
	array: <V>(valueType: V) -> typeNode<{ extractTypeFromTypeNode<V> }>,
	array255: <V>(valueType: V) -> typeNode<{ extractTypeFromTypeNode<V> }>,
	map: <K, V>(keyType: K, valueType: V) -> typeNode<{ [extractTypeFromTypeNode<K>]: extractTypeFromTypeNode<V> }>,
	map255: <K, V>(keyType: K, valueType: V) -> typeNode<{ [extractTypeFromTypeNode<K>]: extractTypeFromTypeNode<V> }>,

	-- ROBLOX TYPES --
	vector3: typeNode<Vector3>,
	cframe: typeNode<CFrame>,
	vector2: typeNode<Vector2>,
	color3: typeNode<Color3>,

	vector3f24: typeNode<Vector3>,
	vector3f16: typeNode<Vector3>,

	vector2f24: typeNode<Vector2>,
	vector2f16: typeNode<Vector2>,

	qcframe: typeNode<CFrame>,
	qcframef24: typeNode<CFrame>,
	qcframef16: typeNode<CFrame>,
	cframef24: typeNode<CFrame>,
	cframef16: typeNode<CFrame>,

	instance: typeNode<Instance>,
	serInstance: (className: string) -> typeNode<Instance>,

	enum: <T>(enum: T & Enum) -> typeNode<getItemType<T>>,

	-- SPECIAL TYPES --
	struct: <T>(struct: T) -> typeNode<extractTypesFromTypeNodes<T>>,
	deltaStruct: <T>(struct: T) -> typeNode<extractTypesFromTypeNodes<T>>,
	deltaStruct16: <T>(struct: T) -> typeNode<extractTypesFromTypeNodes<T>>,
	void: typeNode<{}>,
	any: typeNode<any>,
	optional: <V>(v: V) -> typeNode<extractTypeFromTypeNode<V>?>,
	union: <T...>(T...) -> typeNode<unionOfPack<(T...) -> ()>>,
	boolPacked: typeNode<{ boolean }>
}

export type blazeSentryConstants = "maxBufferSize" | "dynamicVectorType" | "dynamicInstanceType" | "unsupportedUnionExTypes"

export type BlazeSentry = {
	static: staticSerializer,
	dynamic: dynamicSerializer,
	types: blazeSentryTypes,
	combine: <T1, T2>(t1: T1 & table, t2: T2 & table) -> T1 & T2,
	registerInstanceSchema: (className: string, schema: { [string]: any }) -> (),
	writeStart: (offset: number?) -> (),
	readStart: (buf: buffer, offset: number?) -> (),
	writeFinish: () -> buffer,
	readFinish: () -> (),
	getWriteCursor: () -> number,
	getReadCursor: () -> number,
	updateBigBuffer: () -> (),
	setConstant: <T>(constant: blazeSentryConstants, value: T) -> (),
}

return {}
