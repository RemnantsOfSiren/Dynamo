---
sidebar_position: 5
---

# Examples

## Round trip a table

```lua
local Dynamo = require(path.to.Dynamo)

local original = {
	Coins = 12_500,
	DisplayName = "Elentium",
	EquippedItem = 17,
}

local bytes = Dynamo.Serialize1(original)
local restored = Dynamo.Deserialize1(bytes)

print(restored.DisplayName, restored.Coins, restored.EquippedItem)
```

## Multiple values in one buffer

```lua
local packet = Dynamo.Serialize(
	player.UserId,
	character:GetPivot(),
	{ 4, 9, 23, 71 }
)

local userId, pivot, inventory = Dynamo.Deserialize(packet)
```

## Compact inventory array

```lua
local itemIds = { 4, 9, 23, 71 }
local bytes = Dynamo.Serialize1(itemIds)
local restored = Dynamo.Deserialize1(bytes)
```

With four small integers, Dynamo picks `Array8` and `U8` elements. Each element still carries a type tag.

## RemoteEvent payload

```lua
-- server
local bytes = Dynamo.Serialize1({
	Amount = 25,
	Critical = false,
	Origin = Vector3.new(10, 2, -4),
	Target = targetPart,
})

DamageEvent:FireClient(player, bytes)
```

```lua
-- client
DamageEvent.OnClientEvent:Connect(function(bytes: buffer)
	local message = Dynamo.Deserialize1(bytes)
	print(message.Target, message.Amount, message.Critical)
end)
```

`Target` serializes as an Instance **reference** when both sides share `_VSID` maps for that instance.

## Serializable instance by value

```lua
local Dynamo = require(path.to.Dynamo)
local T = Dynamo.Types

Dynamo.DefineSerInstanceSchema("Part", {
	Anchored = T.Bool,
	Color = T.Color,
	Name = T.Str8,
	Position = T.Vec,
	Size = T.Vec,
})

Dynamo.SetConstant("SerInstanceSerialization", true)

local bytes = Dynamo.Serialize1(somePart)
local clone = Dynamo.Deserialize1(bytes) -- new Part with schema properties
```

When `SerInstanceSerialization` is `true`, matching Parts serialize listed properties and deserialize into a new `Part`. Parent is not included unless you add it yourself after deserialize. Leave the constant `false` (default) for `_VSID` instance references instead.

## Switch CFrame / ref layout

```lua
Dynamo.SetConstant("UseQuaternion", false) -- matrix CFrame (larger, less lossy)
Dynamo.SetConstant("InstanceRefMode", "Extended") -- u24 instance ids
```

Keep constants in sync on every peer that shares buffers.

## Preserve an application header

```lua
local bytes = Dynamo.Serialize1WOffset({
	Id = 7,
	Message = "ready",
}, 2)

buffer.writeu8(bytes, 0, 1)
buffer.writeu8(bytes, 1, 9)

local payload = Dynamo.Deserialize1WOffset(bytes, 2)
```

## Push into a preallocated buffer

```lua
local out = buffer.create(256)
local nextOffset = Dynamo.Push1(out, 0, {
	Kind = "ping",
	At = os.clock(),
})
```

`Push1` returns the cursor after the written value.
