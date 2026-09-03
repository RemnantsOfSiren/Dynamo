---
sidebar_position: 4
---

# Type catalog

Every top-level and nested value is written as **1 type-tag byte** plus a payload. Sizes below are **payload** sizes unless noted; add **+1** for the tag on the wire.

Inference chooses the smallest fitting representation.

## Numbers

| Tag | When inferred | Payload |
| --- | --- | ---: |
| `U8` / `I8` | integer in unsigned/signed 8-bit range | 1 |
| `U16` / `I16` | integer in 16-bit range | 2 |
| `U24` / `I24` | integer in 24-bit range | 3 |
| `U32` / `I32` | integer in 32-bit range | 4 |
| `U40` / `I40` | integer in 40-bit range | 5 |
| `U48` / `I48` | integer in 48-bit range | 6 |
| `F32` | non-integer within F32 magnitude | 4 |
| `F64` | other numbers (including oversized integers) | 8 |

Signed ranges use two’s-complement style bounds (for example `I8` from `-128`). Unsigned ranges are non-negative up to `2^n - 1`.

## Booleans, nil, empty table

| Tag | Payload |
| --- | ---: |
| `Bool` | 1 (`0` or `1`) |
| `Nil` | 0 |
| `Void` | 0 (empty table `{}`) |

## Strings

| Tag | Length prefix | Max length |
| --- | ---: | ---: |
| `Str8` | u8 | 255 |
| `Str` | u16 | 65,535 |
| `Str24` | u24 | 16,777,215 |

Lengths are **bytes**, not UTF-8 characters. Payload is the raw string bytes.

## Buffers

| Tag | Length prefix | Max length |
| --- | ---: | ---: |
| `Buf8` | u8 | 255 |
| `Buf` | u16 | 65,535 |
| `Buf24` | u24 | 16,777,215 |

Payload is a raw byte copy of the buffer.

## Arrays and maps

Tables with a non-zero array length (`#t ~= 0`) & no hash elements serialize as arrays. Otherwise non-empty tables serialize as maps (when map-length compute is enabled, length picks `Map8` / `Map` / `Map24`).

| Tag | Count prefix | Max entries |
| --- | ---: | ---: |
| `Array8` / `Map8` | u8 | 255 |
| `Array` / `Map` | u16 | 65,535 |
| `Array24` / `Map24` | u24 | 16,777,215 |

Each array element is a full tagged value. Each map entry is a tagged key followed by a tagged value.

## Vectors and Color3

| Tag | Payload |
| --- | --- |
| `Vec` (`Vector3`) | 3 × `f32` (12) |
| `Vec2` (`Vector2`) | 2 × `f32` (8) |
| `Color` (`Color3`) | RGB as 3 × `u8` (3) |

## CFrame

Controlled by `Dynamo.SetConstant("UseQuaternion", …)` (default **true**):

| Tag | Payload |
| --- | --- |
| `QCframe` | position + quaternion, 7 × `f32` (28) |
| `Cframe` | position + 3×3 matrix, 12 × `f32` (48) |

## UDim / UDim2

| Tag | Payload |
| --- | --- |
| `Udim` | quantized scale `u16` + offset `i16` (4) |
| `Udim2` | two UDim payloads (8) |

Scale is quantized into `[QuantizedScaleMin, QuantizedScaleMax]` (default `0`…`1`) across `0`…`65535`. Change the range with `SetConstant("QuantizedScaleMin" | "QuantizedScaleMax", …)`.

## Enums

| Tag | Payload |
| --- | --- |
| `EnumType` (`Enum`) | `u16` enum id |
| `EnumItem` | `u16` parent enum id + `u16` item value |

Enum ids are assigned from `Enum:GetEnums()` at module init.

## Instances

| Tag | Payload |
| --- | --- |
| `RefInstance` | `u16` id (`Normal`) or `u24` id (`Extended`) |
| `SerInstance` | schema id `u8`, then each property as an untagged payload (schema supplies the type) |

Default instance path is **reference** serialization (`Inst` → `RefInstance` when `SerInstanceSerialization` is `false`). Switch with:

```lua
Dynamo.SetConstant("SerInstanceSerialization", true)  -- value schemas
Dynamo.SetConstant("InstanceRefMode", "Extended")     -- u24 refs
```

References use the `_VSID` attribute and in-memory maps:

- Server assigns ids to descendants and can reuse ids when instances are removed.
- Client mirrors replicated `_VSID` attributes into local maps.

`DefineSerInstanceSchema` registers value-style schemas for `SerInstance` (creates a new instance on deserialize).

## Type tag constants

All public tags are on `Dynamo.Types` (`U8`, `Str8`, `Array`, `Vec`, `QCframe`, `RefInstance`, `SerInstance`, …). Tags are stable within a Dynamo version; do not hard-code numeric ids across major versions without checking the module.
