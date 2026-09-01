---
sidebar_position: 1
---

# Dynamo

Dynamo is a schemaless buffer serializer optimized for low overhead. You pass values; Dynamo picks a compact wire representation and tags each value so it can be reconstructed without a shared schema.

## Basic workflow

1. Serialize one or more values into a buffer.
2. Send or store that buffer.
3. Deserialize the buffer back into values.

```lua
local Dynamo = require(path.to.Dynamo)

local encoded = Dynamo.Serialize1({
	Health = 100,
	Name = "Builder",
	Position = Vector3.new(4, 8, 15),
})

local decoded = Dynamo.Deserialize1(encoded)
print(decoded.Name, decoded.Health, decoded.Position)
```

Unlike schema-driven libraries, the buffer is self-describing at the type level: each value begins with a type tag, then its payload. Nested tables, arrays, and maps carry tags for every element and key.

## What Dynamo is for

- Dynamic payloads where a fixed schema would be awkward.
- Mixed-type packets (`Serialize` / `Deserialize` accept multiple values).
- Game datatypes such as `Vector3`, `CFrame`, `Color3`, `UDim2`, `Enum`, and Instance references.


Continue with [Installation](./installation.md), then the [API](./api.md) and [Type catalog](./types.md). Measured throughput and comparisons are in [Benchmarks](./benchmarks.md).
