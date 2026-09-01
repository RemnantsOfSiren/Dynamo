--!native
--[[
	Compares Dynamo vs VoidSentryUltimate vs Sera on overlapping types only.
	Sera is schematized (single-field schemas). Dynamo is schemaless.
	Cases Sera cannot express (Array/Map/Vector2/UDim2) compare Dynamo vs VS only.
]]

const BenchTypes = require("./Types")
const Benchmark = require("./BenchHelper")

const Dynamo = require("../Dynamo")
const VoidSentry = require("./ExternLibs/VoidSentryUltimate")
const Sera = require("./ExternLibs/Sera")

const VSTypes = VoidSentry.Types

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
	VoidSentry: LibResult?,
	Sera: LibResult?,
}

const Results: { CaseResult } = {}

-- Pre-serialize once for deserialize-only timing (matches Bench.luau style)
const function BenchLibCached(
	MakeBuf: () -> buffer,
	Deserialize: (Buf: buffer) -> (),
	SerializeOnly: () -> (),
	RoundTrip: () -> (),
	Iter: number
): LibResult
	const Cached = MakeBuf()
	return {
		Serialize = Benchmark(SerializeOnly, Iter),
		Deserialize = Benchmark(function()
			Deserialize(Cached)
		end, Iter),
		RoundTrip = Benchmark(RoundTrip, Iter),
		Size = buffer.len(Cached),
	}
end

const function SeraField(Type: any)
	return Sera.Schema({ v = Type })
end

const function FormatUs(N: number): string
	return string.format("%.2f", N)
end

const function Winner(A: number, B: number?, C: number?): string
	local BestName = "Dynamo"
	local Best = A
	if B ~= nil and B < Best then
		Best = B
		BestName = "VoidSentry"
	end
	if C ~= nil and C < Best then
		Best = C
		BestName = "Sera"
	end
	return BestName
end

const function PrintCase(Entry: CaseResult)
	print(SmallSeparator)
	print(`*** {Entry.Name}:`)
	print(
		`**** Size: Dynamo={Entry.Dynamo.Size}b`
			.. (if Entry.VoidSentry then ` VS={Entry.VoidSentry.Size}b` else "")
			.. (if Entry.Sera then ` Sera={Entry.Sera.Size}b` else "")
	)

	const DSer = Entry.Dynamo.Serialize.Avg
	const VSer = if Entry.VoidSentry then Entry.VoidSentry.Serialize.Avg else nil
	const SSer = if Entry.Sera then Entry.Sera.Serialize.Avg else nil
	print(
		`**** Serialize μs: Dynamo={FormatUs(DSer)}`
			.. (if VSer then ` VS={FormatUs(VSer)}` else "")
			.. (if SSer then ` Sera={FormatUs(SSer)}` else "")
			.. ` | win={Winner(DSer, VSer, SSer)}`
	)

	const DDes = Entry.Dynamo.Deserialize.Avg
	const VDes = if Entry.VoidSentry then Entry.VoidSentry.Deserialize.Avg else nil
	const SDes = if Entry.Sera then Entry.Sera.Deserialize.Avg else nil
	print(
		`**** Deserialize μs: Dynamo={FormatUs(DDes)}`
			.. (if VDes then ` VS={FormatUs(VDes)}` else "")
			.. (if SDes then ` Sera={FormatUs(SDes)}` else "")
			.. ` | win={Winner(DDes, VDes, SDes)}`
	)

	const DRt = Entry.Dynamo.RoundTrip.Avg
	const VRt = if Entry.VoidSentry then Entry.VoidSentry.RoundTrip.Avg else nil
	const SRt = if Entry.Sera then Entry.Sera.RoundTrip.Avg else nil
	print(
		`**** RoundTrip μs: Dynamo={FormatUs(DRt)}`
			.. (if VRt then ` VS={FormatUs(VRt)}` else "")
			.. (if SRt then ` Sera={FormatUs(SRt)}` else "")
			.. ` | win={Winner(DRt, VRt, SRt)}`
	)
end

const function PrintResults()
	print(Separator)
	print("* DYNAMO vs VOIDSENTRY vs SERA")
	for _, Entry in Results do
		PrintCase(Entry)
	end
	print(MedSeparator)

	-- Aggregate wins by RoundTrip avg
	local DynamoWins, VSWins, SeraWins, Cases = 0, 0, 0, 0
	for _, Entry in Results do
		Cases += 1
		const W = Winner(
			Entry.Dynamo.RoundTrip.Avg,
			if Entry.VoidSentry then Entry.VoidSentry.RoundTrip.Avg else nil,
			if Entry.Sera then Entry.Sera.RoundTrip.Avg else nil
		)
		if W == "Dynamo" then
			DynamoWins += 1
		elseif W == "VoidSentry" then
			VSWins += 1
		else
			SeraWins += 1
		end
	end
	print(`* RoundTrip wins: Dynamo={DynamoWins} VoidSentry={VSWins} Sera={SeraWins} (of {Cases})`)
	print(Separator)
end

const function Compare(Log: boolean?, Iterations: number?): { CaseResult }
	table.clear(Results)
	const Iter = Iterations or DefaultIterations

	const DSer = Dynamo.Serialize1
	const DDes = Dynamo.Deserialize1
	const VSer = VoidSentry.Serialize
	const VDes = VoidSentry.Deserialize

	const function RunThree(Name: string, Value: any, VSSchema: any, SeraType: any)
		const SeraSchema = SeraField(SeraType)
		const SeraValue = { v = Value }

		const DynamoResult = BenchLibCached(function()
			return DSer(Value)
		end, function(Buf)
			DDes(Buf)
		end, function()
			DSer(Value)
		end, function()
			DDes(DSer(Value))
		end, Iter)

		const VSResult = BenchLibCached(function()
			return VSer(VSSchema, Value)
		end, function(Buf)
			VDes(VSSchema, Buf)
		end, function()
			VSer(VSSchema, Value)
		end, function()
			VDes(VSSchema, VSer(VSSchema, Value))
		end, Iter)

		const SeraResult = BenchLibCached(function()
			const Buf, Err = Sera.Serialize(SeraSchema, SeraValue)
			if not Buf then
				error(Err or "Sera.Serialize failed")
			end
			return Buf
		end, function(Buf)
			Sera.Deserialize(SeraSchema, Buf)
		end, function()
			Sera.Serialize(SeraSchema, SeraValue)
		end, function()
			const Buf = Sera.Serialize(SeraSchema, SeraValue)
			Sera.Deserialize(SeraSchema, Buf :: buffer)
		end, Iter)

		table.insert(Results, {
			Name = Name,
			Dynamo = DynamoResult,
			VoidSentry = VSResult,
			Sera = SeraResult,
		})
	end

	const function RunDynamoVS(Name: string, Value: any, VSSchema: any, VSValue: any?)
		const V = if VSValue ~= nil then VSValue else Value

		const DynamoResult = BenchLibCached(function()
			return DSer(Value)
		end, function(Buf)
			DDes(Buf)
		end, function()
			DSer(Value)
		end, function()
			DDes(DSer(Value))
		end, Iter)

		const VSResult = BenchLibCached(function()
			return VSer(VSSchema, V)
		end, function(Buf)
			VDes(VSSchema, Buf)
		end, function()
			VSer(VSSchema, V)
		end, function()
			VDes(VSSchema, VSer(VSSchema, V))
		end, Iter)

		table.insert(Results, {
			Name = Name,
			Dynamo = DynamoResult,
			VoidSentry = VSResult,
			Sera = nil,
		})
	end

	const function MakeU8Array(Count: number): { number }
		local Arr: { number } = {}
		for i = 1, Count do
			Arr[i] = i % 256
		end
		return Arr
	end

	const function MakeU8Map(Count: number): { [number]: number }
		local Map: { [number]: number } = {}
		for i = 1, Count do
			Map[1000 + i] = i % 256
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

	-- All three libraries
	RunThree("U8", 42, VSTypes.U8, Sera.Uint8)
	task.wait()
	RunThree("I8", -42, VSTypes.I8, Sera.Int8)
	RunThree("U16", 1000, VSTypes.U16, Sera.Uint16)
	task.wait()
	RunThree("I16", -1000, VSTypes.I16, Sera.Int16)
	RunThree("U32", 100_000_000, VSTypes.U32, Sera.Uint32)
	task.wait()
	RunThree("I32", -100_000_000, VSTypes.I32, Sera.Int32)
	RunThree("F32", 3.14, VSTypes.F32, Sera.Float32)
	task.wait()
	RunThree("F64", 1e40, VSTypes.F64, Sera.Float64)
	RunThree("Bool", true, VSTypes.Bool, Sera.Boolean)
	task.wait()
	RunThree("String8 (10)", "aaaaaaaaaa", VSTypes.String8, Sera.String8)
	RunThree("Buffer8 (8b)", Payload8, VSTypes.Buffer8, Sera.Buffer8)
	task.wait()
	RunThree("Buffer16 (32b)", Payload32, VSTypes.Buffer, Sera.Buffer16)
	RunThree("Vector3", TestVector3, VSTypes.Vector, Sera.Vector3)
	task.wait()
	RunThree("Color3", TestColor3, VSTypes.Color3, Sera.Color3)
	-- Dynamo uses quaternion CFrame when UseQuaternion; match with Lossy/QCFrame
	RunThree("CFrame (quat)", TestCFrame, VSTypes.QCFrame, Sera.LossyCFrame)
	task.wait()

	-- Dynamo + VoidSentry only (no Sera equivalent)
	RunDynamoVS("U24", 100_000, VSTypes.U24)
	RunDynamoVS("I24", -100_000, VSTypes.I24)
	task.wait()
	RunDynamoVS("Array8 (10)", MakeU8Array(10), VSTypes.Array8(VSTypes.U8))
	RunDynamoVS("Array (10)", MakeU8Array(10), VSTypes.Array(VSTypes.U8))
	task.wait()
	RunDynamoVS("Map8 (10)", MakeU8Map(10), VSTypes.Map8(VSTypes.U16, VSTypes.U8))
	RunDynamoVS("Map (10)", MakeU8Map(10), VSTypes.Map(VSTypes.U16, VSTypes.U8))
	task.wait()
	RunDynamoVS("Vector2", TestVector2, VSTypes.Vector2)
	RunDynamoVS("UDim2", TestUDim2, VSTypes.UDim2)

	if Log then
		PrintResults()
	end

	return table.clone(Results)
end

return Compare
