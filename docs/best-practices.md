---
sidebar_position: 6
---

# Best practices

## Localize library methods

By localizing library methods, you avoid table lookup every time you need to call the function

```lua
local Serialize = Dynamo.Serialize

for i = 1, 1e5 do
	-- ...
	Serialize(...) -- avoid table lookups in hot paths
end
```

## Prefer `Serialize1` / `Deserialize1` for single values

Variadic `Serialize` / `Deserialize` are ideal for multi-value packets. For one value, the `*1` APIs avoid packing/unpacking overhead and return the next offset when you need framing.

## Account for type tags in size budgets

Every value costs **+1 byte** for its tag, including nested array elements and map keys/values. Schemaless flexibility trades some bandwidth versus a fixed schema with known field types.

## Instance references vs value schemas

- **References** (`RefInstance`, default): same instance identity across the network when `_VSID` is replicated. Use `SetConstant("InstanceRefMode", "Extended")` if you need more than 65,535 live ids.
- **SerInstance**: property snapshot into a **new** instance; requires `DefineSerInstanceSchema` and `SetConstant("SerInstanceSerialization", true)`.

Do not mix expectations: a reference does not recreate missing instances, and SerInstance does not preserve the original Instance object. Both peers must agree on these constants.

## CFrame size vs precision

With quaternion mode enabled (default via `UseQuaternion`), CFrames use 28 payload bytes plus a tag. Matrix mode (`SetConstant("UseQuaternion", false)`) uses 48 payload bytes. Quaternion reconstruction is lossy relative to a full matrix; measure against your accuracy needs.

## UDim scale quantization

`UDim` / `UDim2` scales are quantized to 16 bits over `QuantizedScaleMin`…`QuantizedScaleMax` (default `0`…`1`). Offsets use `i16`. Widen the range with `SetConstant` if you need scales outside `0`…`1`, and test GUI values that matter if you need exact floats.
