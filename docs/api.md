---
sidebar_position: 3
---

# API

All functions live on the module returned by `require`. Type tag constants are under `Dynamo.Types` for `DefineSerInstanceSchema` and advanced use.

## Serialize

```lua
Dynamo.Serialize(...: any) -> buffer
Dynamo.Serialize1(Value: any) -> buffer
```

Writes one or more values into a new buffer. Each value is prefixed with a type tag.

```lua
local packet = Dynamo.Serialize(player.UserId, character.HumanoidRootPart.CFrame)
local one = Dynamo.Serialize1("ready")
```

## Serialize with offset

```lua
Dynamo.SerializeWOffset(Offset: number, ...: any) -> buffer
Dynamo.Serialize1WOffset(Value: any, Offset: number) -> buffer
```

Same as serialize, but writing starts at `Offset`. The returned buffer has length equal to the final cursor (so it includes leading bytes reserved for a header). Leading bytes before `Offset` are zero-filled until you write them.

```lua
local bytes = Dynamo.Serialize1WOffset(payload, 2)
buffer.writeu8(bytes, 0, 1) -- version
buffer.writeu8(bytes, 1, 9) -- opcode
```

## Deserialize

```lua
Dynamo.Deserialize(Buf: buffer) -> ...any
Dynamo.Deserialize1(Buf: buffer) -> (any, number)
```

`Deserialize` reads from the start of the buffer until the end and returns every top-level value.

`Deserialize1` reads a single top-level value and returns `(value, nextOffset)`.

```lua
local a, b = Dynamo.Deserialize(packet)
local value, nextOffset = Dynamo.Deserialize1(one)
```

## Deserialize with range / offset

```lua
Dynamo.DeserializeRange(Buf: buffer, Start: number, End: number?) -> ...any
Dynamo.Deserialize1WOffset(Buf: buffer, Offset: number) -> (any, number)
```

`DeserializeRange` reads top-level values while `Cursor < End` (default end is `buffer.len(Buf)`).

`Deserialize1WOffset` starts at `Offset` and returns `(value, nextOffset)`.

## Push

```lua
Dynamo.Push(Buf: buffer, Offset: number, ...: any) -> number
Dynamo.Push1(Buf: buffer, Offset: number, Value: any) -> number
```

Writes into an existing buffer starting at `Offset` and returns the cursor after the write. Useful for filling preallocated packets.

If a push errors mid-write, call `Dynamo.Restore()` so the internal scratch buffer is reset to the safe copy.

## Scratch buffer size

```lua
Dynamo.SetWriteBufferSize(Size: number)
```

Replaces the internal write scratch buffer (default **1,000,000** bytes). Copy of existing content up to the previous size is preserved when possible.

## Runtime constants

```lua
Dynamo.SetConstant(Constant: Constants, Value: any)
```

Tunes inference and wire layout. Name must be one of:

| Constant | Type | Default | Effect |
| --- | --- | --- | --- |
| `SerInstanceSerialization` | `boolean` | `false` | `false` → Instances use `RefInstance`; `true` → `SerInstance` (needs `DefineSerInstanceSchema`) |
| `InstanceRefMode` | `string` | `"Normal"` | `"Normal"` → `u16` ref id; `"Extended"` → `u24` ref id |
| `UseQuaternion` | `boolean` | `true` | `true` → `QCframe` (28b); `false` → matrix `Cframe` (48b) |
| `DoMapCompute` | `boolean` | `true` | When `true`, map length picks `Map8` / `Map` / `Map24`; when `false`, maps default to `Map` |
| `QuantizedScaleMin` | `number` | `0` | Lower bound for UDim/UDim2 scale quantization |
| `QuantizedScaleMax` | `number` | `1` | Upper bound for UDim/UDim2 scale quantization |

```lua
Dynamo.SetConstant("UseQuaternion", false)
Dynamo.SetConstant("SerInstanceSerialization", true)
Dynamo.SetConstant("InstanceRefMode", "Extended")
```

Both ends of a session must use the same constants for buffers to round-trip correctly. Changing a constant does not rewrite already-encoded buffers.

## Serializable instances

```lua
Dynamo.DefineSerInstanceSchema(ClassName: string, Schema: { [string]: number })
```

*This is slightly contradicting the library purpose (schemaless), but while developing the library, I could not find a better way to efficiently serialize instances, the main purpose of this design is to stay performant and let users choose which properties to serialize.*

Registers a property schema for value-style instance serialization (`SerInstance`). Schema values are type tag ids from `Dynamo.Types` (for example `Dynamo.Types.Vec`, `Dynamo.Types.Color`).

Enable with `Dynamo.SetConstant("SerInstanceSerialization", true)`. Up to **255** schemas may be registered. Property writers use the same Ser/Des paths as normal values (including type tags).

Instance **references** (`RefInstance`) do not use this API; they use the `_VSID` attribute maps maintained at module init (`SerInstanceSerialization` left `false`, the default).

## Types table

`Dynamo.Types` exposes numeric type tags (`U8`, `Str8`, `Array`, `Vec`, `Cframe`, `QCframe`, `RefInstance`, `SerInstance`, and the rest). This is only used for defining SerInstance schemas.