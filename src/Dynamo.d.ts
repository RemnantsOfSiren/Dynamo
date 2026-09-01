declare namespace Dynamo {
	export type Constants =
		| "SerInstanceSerialization"
		| "DoMapCompute"
		| "InstanceRefMode"
		| "UseQuaternion"
		| "QuantizedScaleMin"
		| "QuantizedScaleMax"

	export type InstanceRefMode = "Normal" | "Extended"

	export interface Types {
		readonly U8: number
		readonly I8: number
		readonly U16: number
		readonly I16: number
		readonly U24: number
		readonly I24: number
		readonly U32: number
		readonly I32: number
		readonly F32: number
		readonly F64: number
		readonly Str: number
		readonly Str8: number
		readonly Str24: number
		readonly Bool: number
		readonly Array: number
		readonly Array8: number
		readonly Array24: number
		readonly Map: number
		readonly Map8: number
		readonly Map24: number
		readonly Buf: number
		readonly Buf8: number
		readonly Buf24: number
		readonly Vec: number
		readonly Void: number
		readonly Nil: number
		readonly Cframe: number
		readonly QCframe: number
		readonly RefInstance: number
		readonly SerInstance: number
		readonly Color: number
		readonly Udim2: number
		readonly Udim: number
		readonly Vec2: number
		readonly EnumItem: number
		readonly EnumType: number
		readonly U40: number
		readonly I40: number
		readonly U48: number
		readonly I48: number
	}
}

interface Dynamo {
	readonly Types: Dynamo.Types

	readonly Serialize: (...values: unknown[]) => buffer
	readonly SerializeWOffset: (offset: number, ...values: unknown[]) => buffer
	readonly Serialize1: (value: unknown) => buffer
	readonly Serialize1WOffset: (value: unknown, offset: number) => buffer

	readonly Deserialize: (buf: buffer) => LuaTuple<Array<unknown>>
	readonly Deserialize1: (buf: buffer) => LuaTuple<[unknown, number]>
	readonly DeserializeRange: (buf: buffer, start: number, end?: number) => LuaTuple<Array<unknown>>
	readonly Deserialize1WOffset: (buf: buffer, offset: number) => LuaTuple<[unknown, number]>

	readonly Push: (buf: buffer, offset: number, ...values: unknown[]) => number
	readonly Push1: (buf: buffer, offset: number, value: unknown) => number

	readonly Restore: () => void
	readonly SetWriteBufferSize: (size: number) => void

	readonly DefineSerInstanceSchema: (
		className: string,
		schema: { readonly [key: string]: number },
	) => void

	readonly SetConstant: {
		(constant: "SerInstanceSerialization" | "DoMapCompute" | "UseQuaternion", value: boolean): void
		(constant: "InstanceRefMode", value: Dynamo.InstanceRefMode): void
		(constant: "QuantizedScaleMin" | "QuantizedScaleMax", value: number): void
	}
}

declare const Dynamo: Dynamo
export = Dynamo
