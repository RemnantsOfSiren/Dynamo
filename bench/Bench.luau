--!native
const BenchTypes = require("./Types")
const Benchmark = require("./BenchHelper")

const Dynamo = require("../Dynamo")

const DefaultIterations = 10_000
const Results: BenchTypes.Results = {}
local CurrentSection: BenchTypes.Section? = nil

const Separator = ("_"):rep(50)
const SmallSeparator = "________________________"
const MedSeparator = "______________________________________"

const function Case(Name: string, Func: () -> (), Iterations: number)
	if not CurrentSection then
		return
	end

	const Result = Benchmark(Func, Iterations)

	table.insert(CurrentSection.Nodes, {
		Name = Name,
		Result = Result,
	})
end

const function Section(Name: string)
	CurrentSection = {
		SectionName = Name,
		Nodes = {},
	}
	table.insert(Results, CurrentSection)
end

const function PrintResults(Iterations: number)
	print(Separator)
	print("* DYNAMO BENCH RESULTS")
	print(`* ITERATIONS: {Iterations}`)
	for _, SectionData in Results do
		print(`** {SectionData.SectionName}:`)
		for _, Entry in SectionData.Nodes do
			print(SmallSeparator)
			print(`*** {Entry.Name}:`)
			print(`**** Total: {string.format("%.2f", Entry.Result.Total)}ms`)
			print(`**** Avg: {string.format("%.2f", Entry.Result.Avg)}μs`)
			print(`**** Min: {string.format("%.2f", Entry.Result.Min)}μs`)
			print(`**** Max: {string.format("%.2f", Entry.Result.Max)}μs`)
			print(`**** Med: {string.format("%.2f", Entry.Result.Med)}μs`)
			print(SmallSeparator)
		end
		print(MedSeparator)
	end
	print(Separator)
end

const function Bench(Log: boolean?, Iterations: number?): BenchTypes.Results
	table.clear(Results)
	const Serialize1 = Dynamo.Serialize1
	const Deserialize1 = Dynamo.Deserialize1
	const Iter = Iterations or DefaultIterations

	const function Run(Name: string, Value: any)
		Case(`{Name} Serialize`, function()
			Serialize1(Value)
		end, Iter)

		const Buf = Serialize1(Value)
		Case(`{Name} Deserialize`, function()
			Deserialize1(Buf)
		end, Iter)

		Case(`{Name} RoundTrip`, function()
			Deserialize1(Serialize1(Value))
		end, Iter)
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

	const Payload = buffer.create(32)
	const Payload8 = buffer.create(8)
	const TestCFrame = CFrame.new(1, 2, 3) * CFrame.Angles(0.5, 1, 0.25)
	const TestColor3 = Color3.fromRGB(255, 128, 64)
	const TestVector3 = Vector3.new(1, 2, 3)
	const TestVector2 = Vector2.new(1, 2)
	const TestUDim = UDim.new(0.5, 10)
	const TestUDim2 = UDim2.new(0.5, 10, 0.25, 20)

	Section("Number Types")
	Run("U8", 42)
	Run("I8", -42)
	Run("U16", 1000)
	task.wait()
	Run("I16", -1000)
	Run("U24", 100_000)
	Run("I24", -100_000)
	task.wait()
	Run("U32", 100_000_000)
	Run("I32", -100_000_000)
	Run("U40", 2 ^ 33)
	task.wait()
	Run("I40", -(2 ^ 33))
	Run("U48", 2 ^ 40)
	Run("I48", -(2 ^ 40))
	task.wait()
	Run("F32", 3.14)
	Run("F64", 1e40)

	Section("Buffer Types")
	Run("Buf (32b)", Payload)
	Run("Buf8 (8b)", Payload8)
	task.wait()

	Section("Other Primitives")
	Run("Bool", true)
	Run("Nil", nil)
	Run("Void", {})
	task.wait()
	Run("String (1 char)", "a")
	Run("String (10 chars)", "aaaaaaaaaa")
	Run("String (100 chars)", ("a"):rep(100))
	task.wait()

	Section("Collection Types")
	Run("Array (1 elem)", MakeU8Array(1))
	Run("Map (1 elem)", MakeU8Map(1))
	task.wait()
	Run("Array (10 elem)", MakeU8Array(10))
	Run("Map (10 elem)", MakeU8Map(10))
	task.wait()
	Run("Array (100 elem)", MakeU8Array(100))
	Run("Map (100 elem)", MakeU8Map(100))
	task.wait()

	Section("Vector Types")
	Run("Vector3", TestVector3)
	Run("Vector2", TestVector2)
	task.wait()

	Section("CFrame Types")
	Run("CFrame", TestCFrame)
	task.wait()

	const BenchPart = Instance.new("Part")
	BenchPart.Size = Vector3.new(4, 2, 1)
	BenchPart.Color = TestColor3
	BenchPart.Parent = workspace
	task.wait()

	Section("Instance Types")
	Run("Instance", BenchPart)
	task.wait()

	Section("Other Roblox Types")
	Run("Color3", TestColor3)
	Run("UDim", TestUDim)
	Run("UDim2", TestUDim2)
	Run("Enum", Enum.Material)
	Run("EnumItem", Enum.Material.Plastic)

	if Log then
		PrintResults(Iter)
	end

	return table.clone(Results)
end

return Bench
