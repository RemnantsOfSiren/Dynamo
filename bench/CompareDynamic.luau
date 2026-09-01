--!native
--[[
	Compares schemaless / dynamic serializers:
	Dynamo, BlazeSentry.dynamic, BufferEncoder, MessagePack, HttpService JSON.

	Participation is gated by each library's real type support (see Supports*).

	Blaze dynamic (inferValueType): number, boolean, string, table,
	Vector3, Vector2, CFrame, Color3, Instance, EnumItem.
	Not: nil, buffer, UDim/UDim2, …

	BufferEncoder: table root only (scalars wrapped as `{ Value }`);
	supports buffer + many Roblox datatypes. Bare nil is skipped.

	MessagePack: nil, boolean, number, string, table, buffer.

	JSON (HttpService): nil, boolean, number, string, JSON-safe tables
	(string-keyed maps). Not buffers / Roblox datatypes.
]]

const BenchTypes = require("./Types")
const Benchmark = require("./BenchHelper")

const Dynamo = require("../Dynamo")
const BlazeSentry = require("./ExternLibs/BlazeSentry")
const BufferEncoder = require("./ExternLibs/BufferEncoder")
const MessagePack = require("./ExternLibs/MessagePack")

const HttpService = game:GetService("HttpService")
const BlazeDynamic = BlazeSentry.dynamic

const DefaultIterations = 10_000

const Separator = ("_"):rep(50)
const SmallSeparator = "________________________"
const MedSeparator = "______________________________________"

type LibResult = {
	Serialize: BenchTypes.BenchmarkResult,
	Deserialize: BenchTypes.BenchmarkResult,
	RoundTrip: BenchTypes.BenchmarkResult,
	Size: number,
}

type CaseResult = {
	Name: string,
	Dynamo: LibResult,
	Blaze: LibResult?,
	BufferEncoder: LibResult?,
	MessagePack: LibResult?,
	JSON: LibResult?,
}

const Results: { CaseResult } = {}

-- BlazeSentry shared/inferValueType.luau "supported types"
const function SupportsBlaze(Value: any): boolean
	const T = typeof(Value)
	return T == "number"
		or T == "boolean"
		or T == "string"
		or T == "table"
		or T == "Vector3"
		or T == "Vector2"
		or T == "CFrame"
		or T == "Color3"
		or T == "Instance"
		or T == "EnumItem"
end

-- MessagePack.lua encode/computeLength (type())
const function SupportsMessagePack(Value: any): boolean
	const T = type(Value)
	return T == "nil" or T == "boolean" or T == "number" or T == "string" or T == "table" or T == "buffer"
end

-- HttpService JSONEncode-compatible values only
const function SupportsJSON(Value: any): boolean
	const T = typeof(Value)
	return T == "nil" or T == "boolean" or T == "number" or T == "string" or T == "table"
end

-- BufferEncoder.write requires a table root; `{ nil }` is useless
const function SupportsBufferEncoder(Value: any): boolean
	return Value ~= nil
end

const function ForBufferEncoder(Value: any): { any }
	if type(Value) == "table" then
		return Value
	end
	return { Value }
end

const function PayloadSize(Payload: buffer | string): number
	if typeof(Payload) == "buffer" then
		return buffer.len(Payload)
	end
	return #(Payload :: string)
end

const function BenchLibCached(
	MakePayload: () -> (buffer | string),
	Deserialize: (Payload: buffer | string) -> (),
	SerializeOnly: () -> (),
	RoundTrip: () -> (),
	Iter: number
): LibResult
	const Cached = MakePayload()
	return {
		Serialize = Benchmark(SerializeOnly, Iter),
		Deserialize = Benchmark(function()
			Deserialize(Cached)
		end, Iter),
		RoundTrip = Benchmark(RoundTrip, Iter),
		Size = PayloadSize(Cached),
	}
end

const function FormatUs(N: number): string
	return string.format("%.2f", N)
end

const function Winner(Times: { [string]: number? }): string
	local BestName = "?"
	local Best = math.huge
	for Name, Time in Times do
		if Time ~= nil and Time < Best then
			Best = Time
			BestName = Name
		end
	end
	return BestName
end

const function CaseTimes(Entry: CaseResult, Field: "Serialize" | "Deserialize" | "RoundTrip"): { [string]: number? }
	return {
		Dynamo = Entry.Dynamo[Field].Avg,
		Blaze = if Entry.Blaze then Entry.Blaze[Field].Avg else nil,
		BufferEncoder = if Entry.BufferEncoder then Entry.BufferEncoder[Field].Avg else nil,
		MessagePack = if Entry.MessagePack then Entry.MessagePack[Field].Avg else nil,
		JSON = if Entry.JSON then Entry.JSON[Field].Avg else nil,
	}
end

const function FormatSizes(Entry: CaseResult): string
	local Parts = { `Dynamo={Entry.Dynamo.Size}b` }
	if Entry.Blaze then
		table.insert(Parts, `Blaze={Entry.Blaze.Size}b`)
	end
	if Entry.BufferEncoder then
		table.insert(Parts, `BE={Entry.BufferEncoder.Size}b`)
	end
	if Entry.MessagePack then
		table.insert(Parts, `MsgPack={Entry.MessagePack.Size}b`)
	end
	if Entry.JSON then
		table.insert(Parts, `JSON={Entry.JSON.Size}b`)
	end
	return table.concat(Parts, " ")
end

const function FormatAvgs(Entry: CaseResult, Field: "Serialize" | "Deserialize" | "RoundTrip"): string
	local Parts = { `Dynamo={FormatUs(Entry.Dynamo[Field].Avg)}` }
	if Entry.Blaze then
		table.insert(Parts, `Blaze={FormatUs(Entry.Blaze[Field].Avg)}`)
	end
	if Entry.BufferEncoder then
		table.insert(Parts, `BE={FormatUs(Entry.BufferEncoder[Field].Avg)}`)
	end
	if Entry.MessagePack then
		table.insert(Parts, `MsgPack={FormatUs(Entry.MessagePack[Field].Avg)}`)
	end
	if Entry.JSON then
		table.insert(Parts, `JSON={FormatUs(Entry.JSON[Field].Avg)}`)
	end
	return table.concat(Parts, " ") .. ` | win={Winner(CaseTimes(Entry, Field))}`
end

const function PrintCase(Entry: CaseResult)
	print(SmallSeparator)
	print(`*** {Entry.Name}:`)
	print(`**** Size: {FormatSizes(Entry)}`)
	print(`**** Serialize μs: {FormatAvgs(Entry, "Serialize")}`)
	print(`**** Deserialize μs: {FormatAvgs(Entry, "Deserialize")}`)
	print(`**** RoundTrip μs: {FormatAvgs(Entry, "RoundTrip")}`)
end

const function PrintResults()
	print(Separator)
	print("* DYNAMO vs BLAZE DYNAMIC vs BUFFERENCODER vs MESSAGEPACK vs JSON")
	for _, Entry in Results do
		PrintCase(Entry)
	end
	print(MedSeparator)

	local Wins: { [string]: number } = {
		Dynamo = 0,
		Blaze = 0,
		BufferEncoder = 0,
		MessagePack = 0,
		JSON = 0,
	}
	local Cases = 0
	for _, Entry in Results do
		Cases += 1
		const W = Winner(CaseTimes(Entry, "RoundTrip"))
		Wins[W] = (Wins[W] or 0) + 1
	end
	print(
		`* RoundTrip wins: Dynamo={Wins.Dynamo} Blaze={Wins.Blaze} BufferEncoder={Wins.BufferEncoder} MessagePack={Wins.MessagePack} JSON={Wins.JSON} (of {Cases})`
	)
	print(Separator)
end

const function CompareDynamic(Log: boolean?, Iterations: number?): { CaseResult }
	table.clear(Results)
	const Iter = Iterations or DefaultIterations

	const DSer = Dynamo.Serialize1
	const DDes = Dynamo.Deserialize1

	const function BenchDynamo(Value: any): LibResult
		return BenchLibCached(function()
			return DSer(Value)
		end, function(Payload)
			DDes(Payload :: buffer)
		end, function()
			DSer(Value)
		end, function()
			DDes(DSer(Value))
		end, Iter)
	end

	const function BenchBlaze(Value: any): LibResult
		return BenchLibCached(function()
			return BlazeDynamic.serialize(nil, nil, Value) :: buffer
		end, function(Payload)
			BlazeDynamic.deserialize(nil, nil, Payload :: buffer)
		end, function()
			BlazeDynamic.serialize(nil, nil, Value)
		end, function()
			BlazeDynamic.deserialize(nil, nil, BlazeDynamic.serialize(nil, nil, Value) :: buffer)
		end, Iter)
	end

	const function BenchBufferEncoder(Wrapped: { any }): LibResult
		return BenchLibCached(function()
			return BufferEncoder.write(Wrapped)
		end, function(Payload)
			BufferEncoder.read(Payload :: buffer)
		end, function()
			BufferEncoder.write(Wrapped)
		end, function()
			BufferEncoder.read(BufferEncoder.write(Wrapped))
		end, Iter)
	end

	const function BenchMessagePack(Value: any): LibResult
		return BenchLibCached(function()
			return MessagePack.encode(Value)
		end, function(Payload)
			MessagePack.decode(Payload :: string)
		end, function()
			MessagePack.encode(Value)
		end, function()
			MessagePack.decode(MessagePack.encode(Value))
		end, Iter)
	end

	const function BenchJSON(Value: any): LibResult
		return BenchLibCached(function()
			return HttpService:JSONEncode(Value)
		end, function(Payload)
			HttpService:JSONDecode(Payload :: string)
		end, function()
			HttpService:JSONEncode(Value)
		end, function()
			HttpService:JSONDecode(HttpService:JSONEncode(Value))
		end, Iter)
	end

	const function Run(Name: string, Value: any)
		table.insert(Results, {
			Name = Name,
			Dynamo = BenchDynamo(Value),
			Blaze = if SupportsBlaze(Value) then BenchBlaze(Value) else nil,
			BufferEncoder = if SupportsBufferEncoder(Value) then BenchBufferEncoder(ForBufferEncoder(Value)) else nil,
			MessagePack = if SupportsMessagePack(Value) then BenchMessagePack(Value) else nil,
			JSON = if SupportsJSON(Value) then BenchJSON(Value) else nil,
		})
	end

	const function MakeU8Array(Count: number): { number }
		local Arr: { number } = {}
		for i = 1, Count do
			Arr[i] = i % 256
		end
		return Arr
	end

	-- String keys so JSON can participate
	const function MakeStringMap(Count: number): { [string]: number }
		local Map: { [string]: number } = {}
		for i = 1, Count do
			Map[`k{i}`] = i % 256
		end
		return Map
	end

	const Payload8 = buffer.create(8)
	const Payload32 = buffer.create(32)
	const TestVector3 = Vector3.new(1, 2, 3)
	const TestVector2 = Vector2.new(1, 2)
	const TestColor3 = Color3.fromRGB(255, 128, 64)
	const TestCFrame = CFrame.new(1, 2, 3) * CFrame.Angles(0.5, 1, 0.25)
	const TestUDim2 = UDim2.new(0.5, 10, 0.25, 20)

	Run("U8", 42)
	task.wait()
	Run("I8", -42)
	Run("U16", 1000)
	task.wait()
	Run("I16", -1000)
	Run("U32", 100_000_000)
	task.wait()
	Run("I32", -100_000_000)
	Run("F32", 3.14)
	task.wait()
	Run("F64", 1e40)
	Run("Bool", true)
	task.wait()
	Run("Nil", nil)
	Run("String (10)", "aaaaaaaaaa")
	task.wait()
	Run("Array (10)", MakeU8Array(10))
	Run("Map (10)", MakeStringMap(10))
	task.wait()

	-- Blaze: no buffer. JSON: no buffer. MsgPack + BE + Dynamo.
	Run("Buffer (8b)", Payload8)
	Run("Buffer (32b)", Payload32)
	task.wait()

	-- Blaze: Vector3/2, Color3, CFrame. No UDim2. MsgPack/JSON: no Roblox types.
	Run("Vector3", TestVector3)
	Run("Vector2", TestVector2)
	task.wait()
	Run("Color3", TestColor3)
	Run("CFrame", TestCFrame)
	task.wait()
	Run("UDim2", TestUDim2)

	if Log then
		PrintResults()
	end

	return table.clone(Results)
end

return CompareDynamic
