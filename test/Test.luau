--!native
const TestTypes = require("./Types")
const TestHelper = require("./TestHelper")

const Dynamo = require("../Dynamo")

const Results: TestTypes.Results = {}
local CurrentSection: TestTypes.Section? = nil

const Separator = ("_"):rep(50)
const SmallSeparator = "________________________"
const MedSeparator = "______________________________________"

const function Section(Name: string)
	CurrentSection = {
		SectionName = Name,
		Nodes = {},
	}
	table.insert(Results, CurrentSection)
end

const function AddTest(Result: TestTypes.TestResult)
	if not CurrentSection then
		return
	end
	table.insert(CurrentSection.Nodes, Result)
end

const function Deserialize1(Buf: buffer): any
	const Value = Dynamo.Deserialize1(Buf)
	return Value
end

const function RunTest(
	Name: string,
	Value: any,
	ExpectedSize: number,
	Compare: (any, any) -> boolean
)
	AddTest(TestHelper.RunTest(Name, {
		Serialize = Dynamo.Serialize1,
		Deserialize = Deserialize1,
		Value = Value,
		ExpectedSize = ExpectedSize,
		Compare = Compare,
	}))
end

const function PrintResults()
	print(Separator)
	print("* DYNAMO TEST RESULTS")
	for _, SectionData in Results do
		print(`** {SectionData.SectionName}:`)
		for _, Result in SectionData.Nodes do
			print(SmallSeparator)
			print(`*** {Result.Name}: {if Result.Valid then "PASS" else "FAIL"}`)
		end
		print(MedSeparator)
	end
	const Passed, Total = TestHelper.CountResults(Results)
	const Percent = if Total == 0 then 0 else (Passed / Total) * 100
	print(`* SUCCESS: {Passed}/{Total} ({string.format("%.1f", Percent)}%)`)
	print(Separator)
end

const function Test(Log: boolean?): TestTypes.Results
	table.clear(Results)

	const PayloadSize = 16
	const Payload = buffer.create(PayloadSize)
	buffer.fill(Payload, 0, 0xAB)

	const Payload300 = buffer.create(300)
	buffer.fill(Payload300, 0, 0xCD)

	const BigArray = table.create(300)
	for i = 1, 300 do
		BigArray[i] = i % 256
	end

	const BigMap: { [number]: number } = {}
	for i = 1, 300 do
		-- keys 1001..1300 stay U16 (not array-like, not mixed widths)
		BigMap[1000 + i] = i % 256
	end

	const TestCFrame = CFrame.new(1, 2, 3) * CFrame.Angles(0.5, 1, 0.25)
	const TestColor3 = Color3.fromRGB(255, 128, 64)
	const TestVector3 = Vector3.new(1, 2, 3)
	const TestVector2 = Vector2.new(1, 2)
	const TestUDim = UDim.new(0.5, 10)
	const TestUDim2 = UDim2.new(0.5, 10, 0.25, 20)

	Section("Number Types")
	RunTest("U8", 42, 2, TestHelper.NumbersEq)
	RunTest("I8", -42, 2, TestHelper.NumbersEq)
	RunTest("U16", 1000, 3, TestHelper.NumbersEq)
	RunTest("I16", -1000, 3, TestHelper.NumbersEq)
	RunTest("U24", 100_000, 4, TestHelper.NumbersEq)
	RunTest("I24", -100_000, 4, TestHelper.NumbersEq)
	RunTest("U32", 100_000_000, 5, TestHelper.NumbersEq)
	RunTest("I32", -100_000_000, 5, TestHelper.NumbersEq)
	RunTest("U40", 2 ^ 33, 6, TestHelper.NumbersEq)
	RunTest("I40", -(2 ^ 33), 6, TestHelper.NumbersEq)
	RunTest("U48", 2 ^ 40, 7, TestHelper.NumbersEq)
	RunTest("I48", -(2 ^ 40), 7, TestHelper.NumbersEq)
	RunTest("F32", 3.14, 5, TestHelper.NumbersApprox)
	RunTest("F64", 1e40, 9, TestHelper.NumbersApprox)

	Section("Buffer Types")
	RunTest("Buf8", Payload, 1 + 1 + PayloadSize, TestHelper.BuffersEq)
	RunTest("Buf", Payload300, 1 + 2 + 300, TestHelper.BuffersEq)

	Section("Other Primitives")
	RunTest("Bool", true, 2, TestHelper.BoolsEq)
	RunTest("Nil", nil, 1, TestHelper.NilsEq)
	RunTest("Void", {}, 1, TestHelper.VoidsEq)
	RunTest("Str8", "hello", 1 + 1 + 5, TestHelper.StringsEq)
	RunTest("Str", ("a"):rep(300), 1 + 2 + 300, TestHelper.StringsEq)

	Section("Collection Types")
	RunTest("Array8", { 1, 2, 3 }, 1 + 1 + 3 * 2, function(A, B)
		return TestHelper.ArraysEq(A, B, TestHelper.NumbersEq)
	end)
	RunTest("Array", BigArray, 1 + 2 + 300 * 2, function(A, B)
		return TestHelper.ArraysEq(A, B, TestHelper.NumbersEq)
	end)
	RunTest("Map8", { [100] = 2, [200] = 4 }, 1 + 1 + 2 * 4, function(A, B)
		return TestHelper.MapsEq(A, B, TestHelper.NumbersEq)
	end)
	-- Map: sign + u16 len + 300 * (U16 key + U8 value)
	RunTest("Map", BigMap, 1 + 2 + 300 * (3 + 2), function(A, B)
		return TestHelper.MapsEq(A, B, TestHelper.NumbersEq)
	end)

	Section("Vector Types")
	RunTest("Vector3", TestVector3, 1 + 12, TestHelper.Vector3sEq)
	RunTest("Vector2", TestVector2, 1 + 8, TestHelper.Vector2sEq)

	Section("CFrame Types")
	RunTest("CFrame", TestCFrame, 1 + 28, TestHelper.CFramesApprox)

	const BenchPart = Instance.new("Part")
	BenchPart.Size = Vector3.new(4, 2, 1)
	BenchPart.Color = TestColor3
	BenchPart.Parent = workspace
	task.wait()

	Section("Instance Types")
	RunTest("Instance", BenchPart, 1 + 2, TestHelper.InstancesEq)

	Section("Other Roblox Types")
	RunTest("Color3", TestColor3, 1 + 3, TestHelper.Color3sEq)
	RunTest("UDim", TestUDim, 1 + 4, TestHelper.UDimsApprox)
	RunTest("UDim2", TestUDim2, 1 + 8, TestHelper.UDim2sApprox)
	RunTest("Enum", Enum.Material, 1 + 2, TestHelper.EnumsEq)
	RunTest("EnumItem", Enum.Material.Plastic, 1 + 4, TestHelper.EnumItemsEq)

	Section("SetConstant")
	const T = Dynamo.Types

	-- UseQuaternion false → matrix CFrame (48 payload + tag)
	Dynamo.SetConstant("UseQuaternion", false)
	RunTest("CFrame (matrix)", TestCFrame, 1 + 48, TestHelper.CFramesApprox)
	Dynamo.SetConstant("UseQuaternion", true)
	RunTest("CFrame (quat restore)", TestCFrame, 1 + 28, TestHelper.CFramesApprox)

	-- InstanceRefMode Extended → u24 id
	Dynamo.SetConstant("InstanceRefMode", "Extended")
	RunTest("Instance (Extended)", BenchPart, 1 + 3, TestHelper.InstancesEq)
	Dynamo.SetConstant("InstanceRefMode", "Normal")
	RunTest("Instance (Normal restore)", BenchPart, 1 + 2, TestHelper.InstancesEq)

	-- SerInstanceSerialization → value snapshot (new instance, not same ref)
	Dynamo.DefineSerInstanceSchema("Part", {
		Color = T.Color,
		Size = T.Vec,
	})
	Dynamo.SetConstant("SerInstanceSerialization", true)
	-- tag + schemaId + Color(tag+3) + Size(tag+12); keys sorted Color, Size
	RunTest("SerInstance Part", BenchPart, 1 + 1 + (1 + 3) + (1 + 12), function(A, B)
		return A ~= B
			and A.ClassName == B.ClassName
			and TestHelper.Vector3sEq(A.Size, B.Size)
			and TestHelper.Color3sEq(A.Color, B.Color)
	end)
	Dynamo.SetConstant("SerInstanceSerialization", false)
	RunTest("RefInstance restore", BenchPart, 1 + 2, TestHelper.InstancesEq)

	-- QuantizedScale range widened for scales outside 0..1
	Dynamo.SetConstant("QuantizedScaleMin", 0)
	Dynamo.SetConstant("QuantizedScaleMax", 2)
	const WideUDim = UDim.new(1.5, 10)
	RunTest("UDim (wide scale)", WideUDim, 1 + 4, TestHelper.UDimsApprox)
	Dynamo.SetConstant("QuantizedScaleMax", 1)
	RunTest("UDim (default scale restore)", TestUDim, 1 + 4, TestHelper.UDimsApprox)

	-- DoMapCompute false → always Map (u16 len), not Map8
	Dynamo.SetConstant("DoMapCompute", false)
	RunTest("Map (DoMapCompute off)", { [100] = 2, [200] = 4 }, 1 + 2 + 2 * 4, function(A, B)
		return TestHelper.MapsEq(A, B, TestHelper.NumbersEq)
	end)
	Dynamo.SetConstant("DoMapCompute", true)
	RunTest("Map8 (DoMapCompute restore)", { [100] = 2, [200] = 4 }, 1 + 1 + 2 * 4, function(A, B)
		return TestHelper.MapsEq(A, B, TestHelper.NumbersEq)
	end)

	if Log then
		PrintResults()
	end

	return table.clone(Results)
end

return Test
