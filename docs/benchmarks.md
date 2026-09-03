---
sidebar_position: 7
---

# Benchmarks

These numbers come from the in-repo benches under `bench/`. Absolute times vary by hardware, Studio build, and load; use the ratios and relative ordering as the main takeaway.

Each operation is timed with `BenchHelper`: 50 warm-up calls, then 10 timed batches of **10,000** iterations. Reported **Avg** is mean microseconds per call across those batches.

## Dynamo throughput

Source: `benchresult/bench.txt`  
Harness: `bench/Bench.luau`

Values are average microseconds per call (μs). Lower is faster.

### Scalars

| Type | Serialize | Deserialize | RoundTrip |
| --- | ---: | ---: | ---: |
| `U8` | 0.06 | 0.02 | 0.08 |
| `I8` | 0.05 | 0.02 | 0.08 |
| `U16` | 0.06 | 0.02 | 0.08 |
| `F32` | 0.05 | 0.02 | 0.08 |
| `F64` | 0.06 | 0.02 | 0.08 |
| `Bool` | 0.06 | 0.02 | 0.08 |
| `Nil` | 0.05 | 0.02 | 0.07 |

### Strings, buffers, and datatypes

| Type | RoundTrip (μs) |
| --- | ---: |
| String (10 chars) | 0.12 |
| String (100 chars) | 0.16 |
| Buf (32b) | 0.15 |
| Vector3 | 0.08 |
| CFrame (quat) | 0.16 |
| Color3 | 0.10 |
| UDim2 | 0.12 |
| EnumItem | 0.21 |

### Collections

| Type | RoundTrip (μs) |
| --- | ---: |
| Array (1) | 0.18 |
| Array (10) | 0.49 |
| Array (100) | 3.24 |
| Map (1) | 0.22 |
| Map (10) | 1.03 |
| Map (100) | 8.30 |

Primitive round trips sit around **0.08 μs**. Cost grows mainly with collection size (per-element tags + payloads).

## Versus VoidSentryUltimate and Sera

This comparison is a bit unfair since VoidSentryUltimate and Sera do not infer types at runtime, but Dynamo still managed to keep up well.

Source: `benchresult/compare.txt`  
Harness: `bench/Compare.luau`  
Iterations: **10,000** per timed batch

Sera only serializes through schemas; the comparator wraps values in a single-field schema. VoidSentryUltimate uses typed nodes. Dynamo is schemaless (type tags on the wire).

**RoundTrip wins in this run:** VoidSentry **23**, Dynamo **0**, Sera **0** (of 23 cases).

### Typical RoundTrip ratios (Dynamo ÷ VoidSentry)

| Case | Approx. ratio |
| --- | ---: |
| Scalars / Bool / Vector3 | ~1.14× |
| String8 / Buffer / Color3 / CFrame quat | ~1.07–1.20× |
| Array (10) | ~1.6× |
| Map (10) | ~1.4× |
| UDim2 | ~1.3× (Dynamo smaller on wire: 9b vs 16b) |

### Versus Sera

On shared primitives and buffers, Dynamo is about **2×** faster than Sera on RoundTrip (scalars ~0.08 μs vs ~0.16 μs). Sera stays slower on CFrame quat (~0.28 μs vs Dynamo 0.16 μs).

### How to read this

- Schemaless tags cost **~1 byte** and a small infer/dispatch cost versus schema-fixed VoidSentry nodes.
- Collection gaps are dominated by **per-element tags** (size and time).
- Prefer Dynamo when you want dynamic values without maintaining schemas; prefer a schema library when every field type is known and bandwidth/CPU are tighter.

## Versus other dynamic serializers

Source: `benchresult/comparedynamic.txt`  
Harness: `bench/CompareDynamic.luau`  
Iterations: **10,000** per timed batch

Compares Dynamo to BlazeSentry `dynamic`, BufferEncoder, MessagePack, and `HttpService:JSONEncode` / `JSONDecode`. Each library only runs on types it actually supports (Blaze has no `nil` / `buffer` / `UDim2`; MessagePack/JSON skip Roblox datatypes; BufferEncoder wraps non-tables and skips bare `nil`).

**RoundTrip wins in this run:** Dynamo **20**, Blaze **0**, BufferEncoder **0**, MessagePack **0**, JSON **0** (of 20).

### RoundTrip (μs)

| Case | Dynamo | Blaze | BE | MsgPack | JSON |
| --- | ---: | ---: | ---: | ---: | ---: |
| U8 | **0.08** | 0.30 | 0.52 | 0.11 | 0.41 |
| I8 | **0.08** | 0.30 | 0.52 | 0.10 | 0.42 |
| U16 | **0.08** | 0.30 | 0.52 | 0.14 | 0.43 |
| I16 | **0.08** | 0.30 | 0.52 | 0.14 | 0.42 |
| U32 | **0.08** | 0.31 | 0.52 | 0.19 | 0.43 |
| I32 | **0.09** | 0.30 | 0.53 | 0.19 | 0.44 |
| F32 | **0.08** | 0.30 | 0.51 | 0.29 | 0.43 |
| F64 | **0.12** | 0.30 | 0.52 | 0.30 | 0.43 |
| Bool | **0.08** | 0.31 | 0.52 | 0.10 | 0.36 |
| Nil | **0.08** | — | — | 0.11 | 0.37 |
| String (10) | **0.11** | 0.34 | 0.56 | 0.15 | 0.43 |
| Array (10) | **0.50** | 1.24 | 0.95 | 0.76 | 1.16 |
| Map (10) | **1.32** | 2.66 | 2.03 | 1.93 | 1.61 |
| Buffer (8b) | **0.14** | — | 0.59 | 0.17 | — |
| Buffer (32b) | **0.15** | — | 0.60 | 0.19 | — |
| Vector3 | **0.08** | 0.31 | 0.53 | — | — |
| Vector2 | **0.09** | 0.33 | 0.55 | — | — |
| Color3 | **0.11** | 0.33 | 0.56 | — | — |
| CFrame | **0.16** | 0.45 | 0.72 | — | — |
| UDim2 | **0.12** | — | 0.57 | — | — |

### Wire size (bytes)

| Case | Dynamo | Blaze | BE | MsgPack | JSON |
| --- | ---: | ---: | ---: | ---: | ---: |
| U8 | 2 | 2 | 5 | **1** | 2 |
| Array (10) | 22 | 22 | 22 | **11** | 22 |
| Map (10) | 63 | 64 | 63 | **42** | 73 |
| CFrame | 29 | 49 | **23** | — | — |
| UDim2 | **9** | — | 20 | — | — |

### Takeaways

- Against other **schemaless / dynamic** encoders, Dynamo leads RoundTrip on every shared case in this run (~3.7× Blaze on scalars, ~6× BufferEncoder, ~5× JSON).
- MessagePack stays closest on small integers and dense numeric arrays (no per-element type tags). Dynamo still wins those cases here and leads on maps and Roblox datatypes MessagePack cannot encode.
- BufferEncoder pays for a table root + richer type system; size and time trail Dynamo on these fixtures.
- Blaze dynamic matches Dynamo’s wire size on many scalars but is ~3–4× slower RoundTrip here.
- Prefer Dynamo for mixed Roblox + Luau payloads without schemas; prefer MessagePack when the payload is MsgPack-only Luau data and array density matters.

Re-run locally:

```lua
require(path.to.Bench)(true)
require(path.to.Compare)(true)
require(path.to.CompareDynamic)(true)
```
