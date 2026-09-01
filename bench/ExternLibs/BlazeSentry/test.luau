--!strict
--[[
	BlazeSentry performance benchmarks — one round-trip bench per type.

	Static: `static.serialize` / `static.deserialize` per BlazeSentry type node.
	Dynamic: `dynamic.serialize` / `dynamic.deserialize` per inferred wire type.
]]
--------------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------------
local CONFIG = {
	PERF_ITERATIONS = 2_000,
	PERF_BUDGET_SCALE = 1.0,
	SEPARATOR_WIDTH = 80,

	BUDGETS = {
		-- static
		["int8"] = 5,
		["uint8"] = 5,
		["int16"] = 5,
		["uint16"] = 5,
		["int24"] = 5,
		["uint24"] = 5,
		["int32"] = 5,
		["uint32"] = 5,
		["int40"] = 5,
		["uint40"] = 5,
		["int48"] = 5,
		["uint48"] = 5,
		["float16"] = 8,
		["float24"] = 8,
		["float32"] = 8,
		["float64"] = 8,
		["boolean"] = 5,
		["string"] = 10,
		["string255"] = 10,
		["void"] = 5,
		["nothing"] = 5,
		["boolPacked"] = 8,
		["vector3"] = 10,
		["vector"] = 10,
		["vector2"] = 10,
		["vector2f24"] = 10,
		["vector2f16"] = 10,
		["vector3f24"] = 10,
		["vector3f16"] = 10,
		["cframe"] = 15,
		["cframef24"] = 15,
		["cframef16"] = 15,
		["qcframe"] = 15,
		["qcframef24"] = 15,
		["qcframef16"] = 15,
		["color3"] = 8,
		["enum"] = 8,
		["array"] = 15,
		["array255"] = 20,
		["map"] = 25,
		["map255"] = 30,
		["optional"] = 8,
		["struct"] = 12,
		["deltaStruct"] = 14,
		["deltaStruct16"] = 16,
		["union"] = 12,
		["any"] = 10,
		["instance"] = 12,
		["serInstance"] = 35,
		-- dynamic
		["dynamic int8"] = 8,
		["dynamic uint8"] = 8,
		["dynamic int32"] = 8,
		["dynamic float32"] = 8,
		["dynamic boolean"] = 8,
		["dynamic string"] = 10,
		["dynamic void"] = 8,
		["dynamic array"] = 15,
		["dynamic map"] = 18,
		["dynamic vector3"] = 15,
		["dynamic vector"] = 15,
		["dynamic vector2"] = 12,
		["dynamic cframe"] = 35,
		["dynamic color3"] = 10,
		["dynamic enum"] = 12,
		["dynamic instance"] = 18,
		["dynamic serInstance"] = 35,
	} :: { [string]: number },
}

--------------------------------------------------------------------------------
-- DEPENDENCY
--------------------------------------------------------------------------------
local BlazeSentry = require("./")
local vsConfig = require("./shared/config")
local types = BlazeSentry.types
local static = BlazeSentry.static
local dynamic = BlazeSentry.dynamic

--------------------------------------------------------------------------------
-- VARIABLES
--------------------------------------------------------------------------------
local colors = {
	bg = Color3.fromHex("0b0d14"),
	panel = Color3.fromHex("13151f"),
	card = Color3.fromHex("1c2030"),
	border = Color3.fromHex("282d45"),
	accent = Color3.fromHex("6c63ff"),
	accentDim = Color3.fromHex("3b3880"),
	textPri = Color3.fromHex("e8eaf6"),
	textSec = Color3.fromHex("8b8fc4"),
	textDim = Color3.fromHex("454870"),
	pass = Color3.fromHex("3fb87a"),
	fail = Color3.fromHex("e05555"),
	slow = Color3.fromHex("e0a040"),
	crash = Color3.fromHex("c03030"),
}

--------------------------------------------------------------------------------
-- FRAMEWORK
--------------------------------------------------------------------------------
type TestResult = {
	name: string,
	section: string,
	pass: boolean,
	avgUs: number,
	budgetUs: number,
	crashed: boolean,
	crashMsg: string,
}

type SectionInfo = {
	name: string,
	tests: { TestResult },
}

type SuiteStats = {
	totalTests: number,
	passPct: number,
}

local allSections: { SectionInfo } = {}
local currentSection: SectionInfo = { name = "", tests = {} }

local SEP = string.rep("─", CONFIG.SEPARATOR_WIDTH)

@native
local function computeSuiteStats(): SuiteStats
	local total = 0
	local ok = 0
	for _, sec in allSections do
		for _, r in sec.tests do
			total += 1
			if r.pass and not r.crashed then
				ok += 1
			end
		end
	end
	if total == 0 then
		return { totalTests = 0, passPct = 100 }
	end
	return { totalTests = total, passPct = (ok / total) * 100 }
end

@native
local function bench(iters: number, fn: () -> ()): number
	fn()
	local t0 = os.clock()
	for _ = 1, iters do
		fn()
	end
	return ((os.clock() - t0) / iters) * 1_000_000
end

@native
local function section(name: string)
	currentSection = { name = name, tests = {} }
	table.insert(allSections, currentSection)
end

@native
local function test(name: string, perfFn: () -> ())
	local budgetUs = CONFIG.BUDGETS[name]
	if budgetUs == nil then
		error(`[BlazeSentry tests]: missing CONFIG.BUDGETS entry for "{name}"`, 0)
	end
	local scaledBudget = budgetUs * CONFIG.PERF_BUDGET_SCALE

	local crashed = false
	local crashMsg = ""
	local avgUs = 0.0
	local ok, err = pcall(function()
		avgUs = bench(CONFIG.PERF_ITERATIONS, perfFn)
	end)
	if not ok then
		crashed = true
		crashMsg = tostring(err):sub(1, 120)
	end

	table.insert(currentSection.tests, {
		name = name,
		section = currentSection.name,
		pass = not crashed and avgUs <= scaledBudget,
		avgUs = avgUs,
		budgetUs = scaledBudget,
		crashed = crashed,
		crashMsg = crashMsg,
	} :: TestResult)
end

--------------------------------------------------------------------------------
-- CONSOLE PRINT
--------------------------------------------------------------------------------
local function printResults()
	local st = computeSuiteStats()
	print(SEP)
	print(
		string.format(
			"  BlazeSentry Benchmarks   %d iters/test   scale ×%.1f   |   Pass %.1f%%   (n=%d)",
			CONFIG.PERF_ITERATIONS,
			CONFIG.PERF_BUDGET_SCALE,
			st.passPct,
			st.totalTests
		)
	)
	print(SEP)

	for _, sec in allSections do
		print("")
		print(SEP)
		print(string.format("  %s", sec.name))

		local secPass = true
		for _, r in sec.tests do
			if r.crashed or not r.pass then
				secPass = false
			end
		end
		print(string.format("  Pass: %s", tostring(secPass)))
		print(SEP)

		for _, r in sec.tests do
			if r.crashed then
				print(string.format("  [CRASH] %-50s  %s", r.name, r.crashMsg))
			else
				local tag = if r.pass then "PASS" else "SLOW"
				print(
					string.format(
						"  [%s] %-50s  avg %7.2f µs  (budget %7.2f µs)",
						tag,
						r.name,
						r.avgUs,
						r.budgetUs
					)
				)
			end
		end
	end

	print("")
	print(SEP)
	print("  End of report")
	print(SEP)
end

--------------------------------------------------------------------------------
-- UI BUILDER
--------------------------------------------------------------------------------
local function frame(props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	for k, v in props do
		(f :: any)[k] = v
	end
	return f
end

local function label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextSize = 13
	l.TextColor3 = colors.textPri
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	for k, v in props do
		(l :: any)[k] = v
	end
	return l
end

local function uiPadding(parent: Instance, h: number, v: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, h)
	p.PaddingRight = UDim.new(0, h)
	p.PaddingTop = UDim.new(0, v)
	p.PaddingBottom = UDim.new(0, v)
	p.Parent = parent
end

local function uiList(parent: Instance, spacing: number, dir: Enum.FillDirection?)
	local l = Instance.new("UIListLayout")
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, spacing)
	l.Parent = parent
end

local function uiCorner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function uiStroke(parent: Instance, clr: Color3, thick: number)
	local s = Instance.new("UIStroke")
	s.Color = clr
	s.Thickness = thick
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function buildUI()
	local sg = Instance.new("ScreenGui")
	sg.Name = "BlazeSentryTestResults"
	sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.DisplayOrder = 100

	local bg = frame({
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = colors.bg,
		Parent = sg,
	})

	local win = frame({
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 860, 0.94, 0),
		BackgroundColor3 = colors.panel,
		Parent = bg,
	})
	uiCorner(win, 14)
	uiStroke(win, colors.border, 1)

	local titleBar = frame({
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = colors.card,
		Parent = win,
	})
	uiCorner(titleBar, 14)
	frame({
		Name = "BottomFill",
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 1, -14),
		BackgroundColor3 = colors.card,
		BorderSizePixel = 0,
		Parent = titleBar,
	})
	label({
		Name = "Title",
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Text = "  BlazeSentry  ·  Benchmarks",
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextColor3 = colors.textPri,
		Parent = titleBar,
	})

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Body"
	scroll.Position = UDim2.new(0, 0, 0, 54)
	scroll.Size = UDim2.new(1, 0, 1, -54)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 5
	scroll.ScrollBarImageColor3 = colors.accentDim
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ElasticBehavior = Enum.ElasticBehavior.Never
	scroll.BorderSizePixel = 0
	scroll.Parent = win
	uiPadding(scroll, 14, 10)
	uiList(scroll, 10)

	local statsBar = frame({
		Name = "StatsBar",
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = colors.card,
		LayoutOrder = 0,
		Parent = scroll,
	})
	uiCorner(statsBar, 6)
	uiPadding(statsBar, 12, 0)
	local suiteStats = computeSuiteStats()
	label({
		Name = "StatsTextLeft",
		Size = UDim2.new(0.48, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Text = string.format(
			"Iterations per test: %d    Budget scale: ×%.1f",
			CONFIG.PERF_ITERATIONS,
			CONFIG.PERF_BUDGET_SCALE
		),
		TextSize = 12,
		Font = Enum.Font.Gotham,
		TextColor3 = colors.textSec,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = statsBar,
	})
	label({
		Name = "StatsTextRight",
		Size = UDim2.new(0.52, 0, 1, 0),
		Position = UDim2.new(0.48, 0, 0, 0),
		Text = string.format("Pass %.1f%%  ·  n=%d", suiteStats.passPct, suiteStats.totalTests),
		TextSize = 12,
		Font = Enum.Font.Gotham,
		TextColor3 = colors.textSec,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = statsBar,
	})

	for sIdx, sec in allSections do
		local card = frame({
			Name = "Section_" .. sIdx,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = colors.card,
			LayoutOrder = sIdx,
			Parent = scroll,
		})
		uiCorner(card, 8)
		uiStroke(card, colors.border, 1)
		uiPadding(card, 12, 10)
		uiList(card, 0)

		local hdrRow = frame({
			Name = "Header",
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			LayoutOrder = 0,
			Parent = card,
		})

		label({
			Name = "SectionName",
			Size = UDim2.new(0.55, 0, 1, 0),
			Text = sec.name,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = colors.textPri,
			Parent = hdrRow,
		})

		local secPass = true
		for _, r in sec.tests do
			if r.crashed or not r.pass then
				secPass = false
			end
		end

		local badge = frame({
			Name = "Badge",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0, 0, 0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = if secPass then colors.pass else colors.slow,
			Parent = hdrRow,
		})
		uiCorner(badge, 5)
		uiPadding(badge, 7, 0)
		label({
			Name = "Lbl",
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = if secPass then "PASS" else "FAIL",
			TextSize = 11,
			Font = Enum.Font.GothamBold,
			TextColor3 = colors.bg,
			Parent = badge,
		})

		frame({
			Name = "Divider",
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = colors.border,
			LayoutOrder = 1,
			Parent = card,
		})

		local colHdr = frame({
			Name = "ColHeaders",
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Parent = card,
		})
		local function colLabel(txt: string, xPos: number, xSize: number)
			label({
				Name = txt,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(xPos, 0, 0.5, 0),
				Size = UDim2.new(xSize, 0, 0.8, 0),
				Text = txt,
				TextSize = 10,
				Font = Enum.Font.Gotham,
				TextColor3 = colors.textDim,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = colHdr,
			})
		end
		colLabel("Test", 0, 0.55)
		colLabel("Perf", 0.57, 0.08)
		colLabel("Avg µs", 0.66, 0.18)
		colLabel("Budget", 0.85, 0.15)

		for rIdx, r in sec.tests do
			local rowBg = if rIdx % 2 == 0 then colors.bg else colors.card
			local row = frame({
				Name = "Row_" .. rIdx,
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundColor3 = rowBg,
				BackgroundTransparency = if rIdx % 2 == 0 then 0.6 else 0,
				LayoutOrder = rIdx + 10,
				Parent = card,
			})
			uiCorner(row, 4)

			if r.crashed then
				label({
					Name = "Crash",
					Size = UDim2.fromScale(1, 1),
					Text = "  ⚠  " .. r.name .. "  —  " .. r.crashMsg,
					TextSize = 11,
					TextColor3 = colors.crash,
					Parent = row,
				})
			else
				label({
					Name = "Name",
					Position = UDim2.new(0, 4, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					Size = UDim2.new(0.54, 0, 0.85, 0),
					Text = r.name,
					TextSize = 11,
					Font = Enum.Font.Gotham,
					TextColor3 = colors.textPri,
					Parent = row,
				})

				local pColor = if r.pass then colors.pass else colors.slow
				local pDot = frame({
					Name = "PDot",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0.57, 0, 0.5, 0),
					Size = UDim2.new(0, 10, 0, 10),
					BackgroundColor3 = pColor,
					Parent = row,
				})
				uiCorner(pDot, 5)

				label({
					Name = "Avg",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0.66, 0, 0.5, 0),
					Size = UDim2.new(0.18, 0, 0.85, 0),
					Text = string.format("%.2f", r.avgUs),
					TextSize = 11,
					Font = Enum.Font.GothamMedium,
					TextColor3 = if r.pass then colors.textPri else colors.slow,
					Parent = row,
				})

				label({
					Name = "Budget",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0.85, 0, 0.5, 0),
					Size = UDim2.new(0.15, 0, 0.85, 0),
					Text = string.format("%.2f", r.budgetUs),
					TextSize = 11,
					Font = Enum.Font.Gotham,
					TextColor3 = colors.textSec,
					Parent = row,
				})
			end
		end
	end

	local footerCard = frame({
		Name = "Footer",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = colors.accentDim,
		LayoutOrder = 9999,
		Parent = scroll,
	})
	uiCorner(footerCard, 8)
	uiPadding(footerCard, 18, 0)

	label({
		Name = "FooterNote",
		Size = UDim2.fromScale(1, 1),
		Text = "Per row: performance · avg µs · budget µs",
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = colors.textPri,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = footerCard,
	})

	sg.Parent = game:GetService("StarterGui")
	local lp = game:GetService("Players").LocalPlayer
	if lp then
		local pg = lp:FindFirstChildOfClass("PlayerGui")
		if pg then
			sg:Clone().Parent = pg
		end
	end
end

--------------------------------------------------------------------------------
-- TEST RUNNER
--------------------------------------------------------------------------------
@native
local function BlazeSentry_Test(createUI: boolean?): number
	table.clear(allSections)
	currentSection = { name = "", tests = {} }

	BlazeSentry.registerInstanceSchema("Part", {
		Name = types.string255,
		Material = (types.enum :: any)(Enum.Material),
		Transparency = types.float32,
		CFrame = types.qcframe,
		Size = types.vector3,
		CanCollide = types.boolean,
		CanTouch = types.boolean,
		Color = types.color3,
		Reflectance = types.float32,
		Anchored = types.boolean,
	})

	local materialEnum: BlazeSentry.typeNode = (types.enum :: any)(Enum.Material) :: BlazeSentry.typeNode
	local pointStruct = types.struct({ x = types.float32, y = types.float32 })
	local pointDeltaStruct = types.deltaStruct({ x = types.float32, y = types.float32, z = types.float32 })
	local pointDeltaStruct16 = types.deltaStruct16({ x = types.float32, y = types.float32, z = types.float32 })
	local intArray = types.array(types.int32)
	local uint8Array255 = types.array255(types.uint8)
	local strMap = types.map(types.string255, types.uint8)
	local idxMap255 = types.map255(types.uint8, types.boolean)
	local optInt32 = types.optional(types.int32)
	local intOrStr = types.union(types.int32, types.string255)

	local instanceMap = require("./static/instanceMap")
	local benchPart = Instance.new("Part")
	benchPart:SetAttribute("_VSID", 9001)
	instanceMap[9001] = benchPart

	local serPart = Instance.new("Part")
	serPart.Name = "BenchPart"
	serPart.Material = Enum.Material.Plastic
	serPart.Transparency = 0
	serPart.CFrame = CFrame.new(0, 5, 0)
	serPart.Size = Vector3.new(4, 1, 2)
	serPart.CanCollide = true
	serPart.CanTouch = true
	serPart.Color = Color3.fromRGB(128, 128, 128)
	serPart.Reflectance = 0
	serPart.Anchored = true

	--------------------------------------------------------------------------------
	-- Static
	--------------------------------------------------------------------------------
	section("Static")

	test("int8", function()
		local s, v = types.int8, -42
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("uint8", function()
		local s, v = types.uint8, 200
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("int16", function()
		local s, v = types.int16, -1000
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("uint16", function()
		local s, v = types.uint16, 50000
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("int24", function()
		local s, v = types.int24, -8388608
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("uint24", function()
		local s, v = types.uint24, 16777215
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("int32", function()
		local s, v = types.int32, -2147483648
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("uint32", function()
		local s, v = types.uint32, 4294967295
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("int40", function()
		local s, v = types.int40, -549755813888
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("uint40", function()
		local s, v = types.uint40, 1099511627775
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("int48", function()
		local s, v = types.int48, -140737488355328
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("uint48", function()
		local s, v = types.uint48, 281474976710655
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("float16", function()
		local s, v = types.float16, 1.5
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("float24", function()
		local s, v = types.float24, math.pi
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("float32", function()
		local s, v = types.float32, math.pi
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("float64", function()
		local s, v = types.float64, 1 / 3
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("boolean", function()
		local s, v = types.boolean, true
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("string", function()
		local s, v = types.string, "hello"
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("string255", function()
		local s, v = types.string255, string.rep("x", 100)
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("void", function()
		local s, v = types.void, {}
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("nothing", function()
		local s, v = types.nothing, nil
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("boolPacked", function()
		local s = types.boolPacked
		local v = { true, false, true, false, true, false, true, false }
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("vector3", function()
		local s, v = types.vector3, Vector3.new(1, 2, 3)
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("vector", function()
		local s, v = types.vector, vector.create(1, 2, 3)
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("vector2", function()
		local s, v = types.vector2, Vector2.new(1, 2)
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("vector2f24", function()
		local s, v = types.vector2f24, Vector2.new(1, 2)
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("vector2f16", function()
		local s, v = types.vector2f16, Vector2.new(1, 2)
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("vector3f24", function()
		local s, v = types.vector3f24, Vector3.new(1, 2, 3)
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("vector3f16", function()
		local s, v = types.vector3f16, Vector3.new(1, 2, 3)
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("cframe", function()
		local s, v = types.cframe, CFrame.new(1, 2, 3)
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("cframef24", function()
		local s, v = types.cframef24, CFrame.new(1, 2, 3)
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("cframef16", function()
		local s, v = types.cframef16, CFrame.new(1, 2, 3)
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("qcframe", function()
		local s, v = types.qcframe, CFrame.new(1, 2, 3)
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("qcframef24", function()
		local s, v = types.qcframef24, CFrame.new(1, 2, 3)
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("qcframef16", function()
		local s, v = types.qcframef16, CFrame.new(1, 2, 3)
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("color3", function()
		local s, v = types.color3, Color3.fromRGB(100, 150, 200)
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("enum", function()
		local s = materialEnum
		local v: any = Enum.Material.Plastic
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("array", function()
		local s, v = intArray, { 1, -2, 3 }
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("array255", function()
		local s, v = uint8Array255, { 1, 2, 3 }
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("map", function()
		local s = strMap
		local v: any = { hello = 1, world = 2 }
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("map255", function()
		local s, v = idxMap255, { [1] = true, [2] = false }
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("optional", function()
		local s, v = optInt32, 42
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("struct", function()
		local s, v = pointStruct, { x = 1.5, y = -2.5 }
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("deltaStruct", function()
		local s = pointDeltaStruct
		local v: any = { x = 1.5, z = 3.25 }
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("deltaStruct16", function()
		local s = pointDeltaStruct16
		local v: any = { y = -2.5 }
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("union", function()
		local s = intOrStr
		local v: any = 42
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("any", function()
		local s, v = types.any, Vector3.new(1, 2, 3)
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("instance", function()
		local s, v = types.instance, benchPart
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	test("serInstance", function()
		local s, v = types.serInstance("Part"), serPart
		local b = static.serialize(s, v, nil, nil)
		if b ~= nil then
			static.deserialize(s, b, nil, nil)
		end
	end)

	--------------------------------------------------------------------------------
	-- Dynamic
	--------------------------------------------------------------------------------
	section("Dynamic")

	test("dynamic int8", function()
		local v = -50
		local b = dynamic.serialize(nil, nil, v)
		if b ~= nil then
			dynamic.deserialize(nil, nil, b)
		end
	end)

	test("dynamic uint8", function()
		local v = 200
		local b = dynamic.serialize(nil, nil, v)
		if b ~= nil then
			dynamic.deserialize(nil, nil, b)
		end
	end)

	test("dynamic int32", function()
		local v = 100000
		local b = dynamic.serialize(nil, nil, v)
		if b ~= nil then
			dynamic.deserialize(nil, nil, b)
		end
	end)

	test("dynamic float32", function()
		local v = 1.5
		local b = dynamic.serialize(nil, nil, v)
		if b ~= nil then
			dynamic.deserialize(nil, nil, b)
		end
	end)

	test("dynamic boolean", function()
		local v = true
		local b = dynamic.serialize(nil, nil, v)
		if b ~= nil then
			dynamic.deserialize(nil, nil, b)
		end
	end)

	test("dynamic string", function()
		local v = "dynamic"
		local b = dynamic.serialize(nil, nil, v)
		if b ~= nil then
			dynamic.deserialize(nil, nil, b)
		end
	end)

	test("dynamic void", function()
		local v = {}
		local b = dynamic.serialize(nil, nil, v)
		if b ~= nil then
			dynamic.deserialize(nil, nil, b)
		end
	end)

	test("dynamic array", function()
		local v = { 1, 2, 3 }
		local b = dynamic.serialize(nil, nil, v)
		if b ~= nil then
			dynamic.deserialize(nil, nil, b)
		end
	end)

	test("dynamic map", function()
		local v = { k = 1 }
		local b = dynamic.serialize(nil, nil, v)
		if b ~= nil then
			dynamic.deserialize(nil, nil, b)
		end
	end)

	if vsConfig.dynamicVectorType == "Vector3" then
		test("dynamic vector3", function()
			local v = Vector3.new(1, 2, 3)
			local b = dynamic.serialize(nil, nil, v)
			if b ~= nil then
				dynamic.deserialize(nil, nil, b)
			end
		end)
	else
		test("dynamic vector", function()
			local v = vector.create(1, 2, 3)
			local b = dynamic.serialize(nil, nil, v)
			if b ~= nil then
				dynamic.deserialize(nil, nil, b)
			end
		end)
	end

	test("dynamic vector2", function()
		local v = Vector2.new(1, 2)
		local b = dynamic.serialize(nil, nil, v)
		if b ~= nil then
			dynamic.deserialize(nil, nil, b)
		end
	end)

	test("dynamic cframe", function()
		local v = CFrame.new(1, 2, 3)
		local b = dynamic.serialize(nil, nil, v)
		if b ~= nil then
			dynamic.deserialize(nil, nil, b)
		end
	end)

	test("dynamic color3", function()
		local v = Color3.fromRGB(10, 20, 30)
		local b = dynamic.serialize(nil, nil, v)
		if b ~= nil then
			dynamic.deserialize(nil, nil, b)
		end
	end)

	test("dynamic enum", function()
		local v = Enum.Material.Plastic
		local b = dynamic.serialize(nil, nil, v)
		if b ~= nil then
			dynamic.deserialize(nil, nil, b)
		end
	end)

	if vsConfig.dynamicInstanceType == "instance" then
		test("dynamic instance", function()
			local v = benchPart
			local b = dynamic.serialize(nil, nil, v)
			if b ~= nil then
				dynamic.deserialize(nil, nil, b)
			end
		end)
	else
		test("dynamic serInstance", function()
			local v = serPart
			local b = dynamic.serialize(nil, nil, v)
			if b ~= nil then
				dynamic.deserialize(nil, nil, b)
			end
		end)
	end

	printResults()
	if createUI then
		buildUI()
	end

	return 0
end

return BlazeSentry_Test
