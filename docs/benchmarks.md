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
| `U8` | 0.06 | 0.02 | 0.09 |
| `I8` | 0.07 | 0.03 | 0.09 |
| `U16` | 0.07 | 0.02 | 0.09 |
| `F32` | ~0.06 | ~0.02 | 0.09 |
| `F64` | ~0.06 | ~0.02 | 0.09 |
| `Bool` | ~0.06 | ~0.02 | ~0.09 |
| `Nil` | — | — | 0.09 |

### Strings, buffers, and datatypes

| Type | RoundTrip (μs) |
| --- | ---: |
| String (10 chars) | 0.25 |
| String (100 chars) | 0.19 |
| Buf (32b) | 0.17 |
| Vector3 | — (see compare) |
| CFrame (quat) | 0.18 |
| Color3 | ~0.12 |
| UDim2 | 0.13 |
| EnumItem | 0.24 |

### Collections

| Type | RoundTrip (μs) |
| --- | ---: |
| Array (1) | 0.20 |
| Array (10) | 0.58 |
| Array (100) | 4.12 |
| Map (1) | 0.25 |
| Map (10) | 1.29 |
| Map (100) | 10.57 |

Primitive round trips stay near **0.09 μs**. Cost grows mainly with collection size (per-element tags + payloads).

## Versus VoidSentryUltimate and Sera

This comparison is a bit unfair since VoidSentryUltimate and Sera do not infer types at runtime, but Dynamo still managed to keep up well

Source: `benchresult/compare.txt`  
Harness: `bench/Compare.luau`  
Iterations: **10,000** per timed batch

Sera only serializes through schemas; the comparator wraps values in a single-field schema. VoidSentryUltimate uses typed nodes. Dynamo is schemaless (type tags on the wire).

**RoundTrip wins in this run:** VoidSentry **23**, Dynamo **0**, Sera **0** (of 23 cases).

### Typical RoundTrip ratios (Dynamo ÷ VoidSentry)

| Case | Approx. ratio |
| --- | ---: |
| Scalars / Bool | ~1.3× |
| String8 / Buffer / Color3 / CFrame quat | ~1.1–1.2× |
| Vector3 | ~2.4× |
| Array (10) | ~1.9× |
| Map (10) | ~1.7× |
| UDim2 | ~1.4× (Dynamo smaller on wire: 9b vs 16b) |

### Versus Sera

On shared primitives and buffers, Dynamo is generally **faster than Sera** on RoundTrip (often ~1.5–2×). Sera’s Buffer16 RoundTrip was an outlier (~0.72 μs) in this run.

### How to read this

- Schemaless tags cost **~1 byte** and a small infer/dispatch cost versus schema-fixed VoidSentry nodes.
- Collection gaps are dominated by **per-element tags** (size and time).
- Prefer Dynamo when you want dynamic values without maintaining schemas; prefer a schema library when every field type is known and bandwidth/CPU are tighter.

## Versus other dynamic serializers

Source: `benchresult/comparedynamic.txt`  
Harness: `bench/CompareDynamic.luau`  
Iterations: **10,000** per timed batch

Compares Dynamo to BlazeSentry `dynamic`, BufferEncoder, MessagePack, and `HttpService:JSONEncode` / `JSONDecode`. Each library only runs on types it actually supports (Blaze has no `nil` / `buffer` / `UDim2`; MessagePack/JSON skip Roblox datatypes; BufferEncoder wraps non-tables and skips bare `nil`).

**RoundTrip wins in this run:** Dynamo **18**, MessagePack **2**, Blaze **0**, BufferEncoder **0**, JSON **0** (of 20).

MessagePack’s two wins: `I8` (essentially tied at ~0.10 μs) and `Array (10)`.

### RoundTrip (μs)

| Case | Dynamo | Blaze | BE | MsgPack | JSON |
| --- | ---: | ---: | ---: | ---: | ---: |
| U8 | **0.09** | 0.30 | 0.52 | 0.10 | 0.44 |
| I8 | 0.10 | 0.29 | 0.52 | **0.10** | 0.43 |
| U16 | **0.09** | 0.30 | 0.52 | 0.14 | 0.44 |
| I16 | **0.09** | 0.29 | 0.52 | 0.14 | 0.43 |
| U32 | **0.09** | 0.29 | 0.52 | 0.18 | 0.44 |
| I32 | **0.10** | 0.30 | 0.52 | 0.18 | 0.46 |
| F32 | **0.09** | 0.29 | 0.51 | 0.28 | 0.43 |
| F64 | **0.10** | 0.30 | 0.51 | 0.29 | 0.44 |
| Bool | **0.09** | 0.30 | 0.51 | 0.10 | 0.37 |
| Nil | **0.08** | — | — | 0.10 | 0.38 |
| String (10) | **0.12** | 0.33 | 0.55 | 0.14 | 0.44 |
| Array (10) | 0.90 | 1.27 | 0.95 | **0.75** | 1.18 |
| Map (10) | **1.57** | 2.62 | 2.04 | 1.80 | 1.66 |
| Buffer (8b) | **0.16** | — | 0.65 | 0.17 | — |
| Buffer (32b) | **0.17** | — | 0.63 | 0.20 | — |
| Vector3 | **0.09** | 0.31 | 0.54 | — | — |
| Vector2 | **0.10** | 0.32 | 0.55 | — | — |
| Color3 | **0.11** | 0.34 | 0.56 | — | — |
| CFrame | **0.17** | 0.43 | 0.72 | — | — |
| UDim2 | **0.13** | — | 0.57 | — | — |

### Wire size (bytes)

| Case | Dynamo | Blaze | BE | MsgPack | JSON |
| --- | ---: | ---: | ---: | ---: | ---: |
| U8 | 2 | 2 | 5 | **1** | 2 |
| Array (10) | 22 | 22 | 22 | **11** | 22 |
| Map (10) | 63 | 64 | 63 | **42** | 73 |
| CFrame | 29 | 49 | **23** | — | — |
| UDim2 | **9** | — | 20 | — | — |

### Takeaways

- Against other **schemaless / dynamic** encoders, Dynamo leads RoundTrip on almost every shared case (~3× Blaze on scalars, ~5× BufferEncoder, ~4× JSON).
- MessagePack stays competitive on small integers and wins dense numeric arrays (no per-element type tags). Dynamo stays ahead on maps and Roblox datatypes MessagePack cannot encode.
- BufferEncoder pays for a table root + richer type system; size and time trail Dynamo on these fixtures.
- Blaze dynamic matches Dynamo’s wire size on many scalars but is ~3× slower RoundTrip here.
- Prefer Dynamo for mixed Roblox + Luau payloads without schemas; prefer MessagePack when the payload is MsgPack-only Luau data and array density matters.

Re-run locally:

```lua
require(path.to.Bench)(true)
require(path.to.Compare)(true)
require(path.to.CompareDynamic)(true)
```
