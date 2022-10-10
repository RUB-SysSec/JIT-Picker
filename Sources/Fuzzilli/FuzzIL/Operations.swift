// Copyright 2019 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// An operation in the FuzzIL language.
///
/// Operations can be shared between different programs since they do not contain any
/// program specific data.
public class Operation {
    /// The attributes of this operation.
    let attributes: Attributes

    /// The context in which the operation can exist
    let requiredContext: Context

    /// The context that this operations opens
    let contextOpened: Context

    /// The number of input variables to this operation.
    private let numInputs_: UInt16
    var numInputs: Int {
        return Int(numInputs_)
    }

    /// The number of newly created variables in the current scope.
    private let numOutputs_: UInt16
    var numOutputs: Int {
        return Int(numOutputs_)
    }

    /// The number of newly created variables in the inner scope if one is created.
    private let numInnerOutputs_: UInt16
    var numInnerOutputs: Int {
        return Int(numInnerOutputs_)
    }

    /// The index of the first variadic input.
    private let firstVariadicInput_: UInt16
    var firstVariadicInput: Int {
        Assert(attributes.contains(.isVariadic))
        return Int(firstVariadicInput_)
    }

    fileprivate init(numInputs: Int, numOutputs: Int, numInnerOutputs: Int = 0, firstVariadicInput: Int = -1, attributes: Attributes = [], requiredContext: Context = .script, contextOpened: Context = .empty) {
        Assert(attributes.contains(.isVariadic) == (firstVariadicInput != -1))
        Assert(firstVariadicInput == -1 || firstVariadicInput <= numInputs)
        self.attributes = attributes
        self.requiredContext = requiredContext
        self.contextOpened = contextOpened
        self.numInputs_ = UInt16(numInputs)
        self.numOutputs_ = UInt16(numOutputs)
        self.numInnerOutputs_ = UInt16(numInnerOutputs)
        self.firstVariadicInput_ = attributes.contains(.isVariadic) ? UInt16(firstVariadicInput) : 0
    }

    /// Possible attributes of an operation.
    struct Attributes: OptionSet {
        let rawValue: UInt16

        // The operation is pure, i.e. returns the same output given
        // the same inputs (in practice, for simplicity we only mark
        // operations without inputs as pure) and doesn't have any
        // side-effects. As such, two identical pure operations can
        // always be replaced with just one.
        static let isPure             = Attributes(rawValue: 1 << 0)
        // This operation can be mutated in a meaningful way.
        // The rough rule of thumbs is that every Operation subclass that has additional members should be mutable.
        // Example include integer values (LoadInteger), string values (LoadProperty and CallMethod), or Arrays (CallFunctionWithSpread).
        // However, if mutations are not interesting or meaningful, or if the value space is very small (e.g. a boolean), it may make sense
        // to not make the operation mutable to not degrade mutation performance (by causing many meaningless mutations).
        // An example of such an exception is the isStrict member of function definitions: the value space is two (true or false)
        // and mutating the isStrict member is probably not very interesting compared to mutations on other operations.
        static let isMutable          = Attributes(rawValue: 1 << 1)
        // The operation performs a subroutine call.
        static let isCall             = Attributes(rawValue: 1 << 2)
        // The operation is the start of a block.
        static let isBlockStart       = Attributes(rawValue: 1 << 3)
        // The operation is the end of a block.
        static let isBlockEnd         = Attributes(rawValue: 1 << 4)
        // The block opened or closed by this operation is some form of loop.
        static let isLoop             = Attributes(rawValue: 1 << 5)
        // The operation is used for internal purposes and should not
        // be visible to the user (e.g. appear in emitted samples).
        static let isInternal         = Attributes(rawValue: 1 << 7)
        // The operation behaves like an (unconditional) jump. Any
        // code until the next block end is therefore dead code.
        static let isJump             = Attributes(rawValue: 1 << 8)
        // The operation can take a variable number of inputs.
        // The firstVariadicInput contains the index of the first variadic input.
        static let isVariadic          = Attributes(rawValue: 1 << 9)
        // The operation propagates the surrounding context
        static let propagatesSurroundingContext = Attributes(rawValue: 1 << 10)
    }
}

class LoadInteger: Operation {
    let value: Int64

    init(value: Int64) {
        self.value = value
        super.init(numInputs: 0, numOutputs: 1, attributes: [.isPure, .isMutable])
    }
}

class LoadBigInt: Operation {
    // This could be a bigger integer type, but it's most likely not worth the effort
    let value: Int64

    init(value: Int64) {
        self.value = value
        super.init(numInputs: 0, numOutputs: 1, attributes: [.isPure, .isMutable])
    }
}

class LoadFloat: Operation {
    let value: Double

    init(value: Double) {
        self.value = value
        super.init(numInputs: 0, numOutputs: 1, attributes: [.isPure, .isMutable])
    }
}

class LoadString: Operation {
    let value: String

    init(value: String) {
        self.value = value
        super.init(numInputs: 0, numOutputs: 1, attributes: [.isPure, .isMutable])
    }
}

class LoadBoolean: Operation {
    let value: Bool

    init(value: Bool) {
        self.value = value
        super.init(numInputs: 0, numOutputs: 1, attributes: [.isPure, .isMutable])
    }
}

class LoadUndefined: Operation {
    init() {
        super.init(numInputs: 0, numOutputs: 1, attributes: [.isPure])
    }
}

class LoadNull: Operation {
    init() {
        super.init(numInputs: 0, numOutputs: 1, attributes: [.isPure])
    }
}

class LoadThis: Operation {
    init() {
        super.init(numInputs: 0, numOutputs: 1, attributes: [.isPure])
    }
}

class LoadArguments: Operation {
    init() {
        super.init(numInputs: 0, numOutputs: 1, attributes: [.isPure], requiredContext: [.script, .function])
    }
}

public struct RegExpFlags: OptionSet, Hashable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public func asString() -> String {
        var strRepr = ""
        for (flag, char) in RegExpFlags.flagToCharDict {
            if contains(flag) {
                strRepr += char
            }
        }
        return strRepr
    }

    static let caseInsensitive = RegExpFlags(rawValue: 1 << 0)
    static let global          = RegExpFlags(rawValue: 1 << 1)
    static let multiline       = RegExpFlags(rawValue: 1 << 2)
    static let dotall          = RegExpFlags(rawValue: 1 << 3)
    static let unicode         = RegExpFlags(rawValue: 1 << 4)
    static let sticky          = RegExpFlags(rawValue: 1 << 5)

    public static func random() -> RegExpFlags {
        return RegExpFlags(rawValue: UInt32.random(in: 0..<(1<<6)))
    }

    private static let flagToCharDict: [RegExpFlags:String] = [
        .caseInsensitive: "i",
        .global:          "g",
        .multiline:       "m",
        .dotall:          "s",
        .unicode:         "u",
        .sticky:          "y",
    ]
}

class LoadRegExp: Operation {
    let flags: RegExpFlags
    let value: String

    init(value: String, flags: RegExpFlags) {
        self.value = value
        self.flags = flags
        super.init(numInputs: 0, numOutputs: 1, attributes: [.isPure, .isMutable])
    }
}

class CreateObject: Operation {
    let propertyNames: [String]

    init(propertyNames: [String]) {
        self.propertyNames = propertyNames
        var flags: Operation.Attributes = [.isVariadic]
        if propertyNames.count > 0 {
            flags.insert(.isMutable)
        }
        super.init(numInputs: propertyNames.count, numOutputs: 1, firstVariadicInput: 0, attributes: flags)
    }
}

class CreateArray: Operation {
    var numInitialValues: Int {
        return numInputs
    }

    init(numInitialValues: Int) {
        super.init(numInputs: numInitialValues, numOutputs: 1, firstVariadicInput: 0, attributes: [.isVariadic])
    }
}

class CreateObjectWithSpread: Operation {
    // The property names of the "regular" properties. The remaining input values will be spread.
    let propertyNames: [String]

    var numSpreads: Int {
        return numInputs - propertyNames.count
    }

    init(propertyNames: [String], numSpreads: Int) {
        self.propertyNames = propertyNames
        var flags: Operation.Attributes = [.isVariadic]
        if propertyNames.count > 0 {
            flags.insert([.isMutable])
        }
        super.init(numInputs: propertyNames.count + numSpreads, numOutputs: 1, firstVariadicInput: 0, attributes: flags)
    }
}

class CreateArrayWithSpread: Operation {
    // Which inputs to spread.
    let spreads: [Bool]

    init(spreads: [Bool]) {
        self.spreads = spreads
        var flags: Operation.Attributes = [.isVariadic]
        if spreads.count > 0 {
            flags.insert([.isMutable])
        }
        super.init(numInputs: spreads.count, numOutputs: 1, firstVariadicInput: 0, attributes: flags)
    }
}

class CreateTemplateString: Operation {
    // Stores the string elements of the template literal
    let parts: [String]

    var numInterpolatedValues: Int {
        return numInputs
    }

    // This operation isn't mutable since it will most likely mutate imported templates (which would mostly be valid JS snippets) and
    // replace them with random strings and/or other template strings that may not be syntactically and/or semantically valid.
    init(parts: [String]) {
        Assert(parts.count > 0)
        self.parts = parts
        super.init(numInputs: parts.count - 1, numOutputs: 1, firstVariadicInput: 0, attributes: [.isVariadic])
    }
}

class LoadBuiltin: Operation {
    let builtinName: String

    init(builtinName: String) {
        self.builtinName = builtinName
        super.init(numInputs: 0, numOutputs: 1, attributes: [.isMutable])
    }
}

class LoadProperty: Operation {
    let propertyName: String

    init(propertyName: String) {
        self.propertyName = propertyName
        super.init(numInputs: 1, numOutputs: 1, attributes: [.isMutable])
    }
}

class StoreProperty: Operation {
    let propertyName: String

    init(propertyName: String) {
        self.propertyName = propertyName
        super.init(numInputs: 2, numOutputs: 0, attributes: [.isMutable])
    }
}

class StorePropertyWithBinop: Operation {
    let propertyName: String
    let op: BinaryOperator

    init(propertyName: String, operator op: BinaryOperator) {
        self.propertyName = propertyName
        self.op = op
        super.init(numInputs: 2, numOutputs: 0, attributes: [.isMutable])
    }
}

class DeleteProperty: Operation {
    let propertyName: String

    init(propertyName: String) {
        self.propertyName = propertyName
        super.init(numInputs: 1, numOutputs: 1, attributes: [.isMutable])
    }
}

class LoadElement: Operation {
    let index: Int64

    init(index: Int64) {
        self.index = index
        super.init(numInputs: 1, numOutputs: 1, attributes: [.isMutable])
    }
}

class StoreElement: Operation {
    let index: Int64

    init(index: Int64) {
        self.index = index
        super.init(numInputs: 2, numOutputs: 0, attributes: [.isMutable])
    }
}

class StoreElementWithBinop: Operation {
    let index: Int64
    let op: BinaryOperator

    init(index: Int64, operator op: BinaryOperator) {
        self.index = index
        self.op = op
        super.init(numInputs: 2, numOutputs: 0, attributes: [.isMutable])
    }
}

class DeleteElement: Operation {
    let index: Int64

    init(index: Int64) {
        self.index = index
        super.init(numInputs: 1, numOutputs: 1, attributes: [.isMutable])
    }
}

class LoadComputedProperty: Operation {
    init() {
        super.init(numInputs: 2, numOutputs: 1)
    }
}

class StoreComputedProperty: Operation {
    init() {
        super.init(numInputs: 3, numOutputs: 0)
    }
}

class StoreComputedPropertyWithBinop: Operation {
    let op: BinaryOperator

    init(operator op: BinaryOperator) {
        self.op = op
        super.init(numInputs: 3, numOutputs: 0)
    }
}

class DeleteComputedProperty: Operation {
    init() {
        super.init(numInputs: 2, numOutputs: 1)
    }
}

class TypeOf: Operation {
    init() {
        super.init(numInputs: 1, numOutputs: 1)
    }
}

class TestInstanceOf: Operation {
    init() {
        super.init(numInputs: 2, numOutputs: 1)
    }
}

class TestIn: Operation {
    init() {
        super.init(numInputs: 2, numOutputs: 1)
    }
}

//
class Explore: Operation {
    let id: String

    init(id: String, numArguments: Int) {
        self.id = id
        super.init(numInputs: numArguments + 1, numOutputs: 0)
    }
}

// Function definitions.
// Functions beginnings are not considered mutable since it likely makes little sense to change the signature: we're not
// actually changing the program (the signature is not visible), but all calls and parameter uses are now potentially
// wrong, while we prefer to change a single "thing" at a time. It also likely makes little sense to switch a function
// into/out of strict mode. As such, these attributes are permanent.
class BeginAnyFunction: Operation {
    let signature: FunctionSignature
    let isStrict: Bool

    /// Whether the last parameter is a rest parameter.
    var hasRestParam: Bool {
        return signature.hasVarargsParameter()
    }

    init(signature: FunctionSignature, isStrict: Bool, contextOpened: Context = [.script, .function]) {
        self.signature = signature
        self.isStrict = isStrict
        super.init(numInputs: 0,
                   numOutputs: 1,
                   numInnerOutputs: signature.numOutputVariablesInCallee,
                   attributes: [.isBlockStart], contextOpened: contextOpened)
    }
}

class EndAnyFunction: Operation {
    init() {
        super.init(numInputs: 0, numOutputs: 0, attributes: [.isBlockEnd])
    }
}

// A plain function
class BeginPlainFunction: BeginAnyFunction {}
class EndPlainFunction: EndAnyFunction {}

// A ES6 arrow function
class BeginArrowFunction: BeginAnyFunction {}
class EndArrowFunction: EndAnyFunction {}

// A ES6 generator function
class BeginGeneratorFunction: BeginAnyFunction {
    init(signature: FunctionSignature, isStrict: Bool) {
        super.init(signature: signature, isStrict: isStrict, contextOpened: [.script, .function, .generatorFunction])
    }
}
class EndGeneratorFunction: EndAnyFunction {}

// A ES6 async function
class BeginAsyncFunction: BeginAnyFunction {
    init(signature: FunctionSignature, isStrict: Bool) {
        super.init(signature: signature, isStrict: isStrict, contextOpened: [.script, .function, .asyncFunction])
    }
}
class EndAsyncFunction: EndAnyFunction {}

// A ES6 async arrow function
class BeginAsyncArrowFunction: BeginAnyFunction {
    init(signature: FunctionSignature, isStrict: Bool) {
        super.init(signature: signature, isStrict: isStrict, contextOpened: [.script, .function, .asyncFunction])
    }
}
class EndAsyncArrowFunction: EndAnyFunction {}

// A ES6 async generator function
class BeginAsyncGeneratorFunction: BeginAnyFunction {
    init(signature: FunctionSignature, isStrict: Bool) {
        super.init(signature: signature, isStrict: isStrict, contextOpened: [.script, .function, .asyncFunction, .generatorFunction])
    }
}
class EndAsyncGeneratorFunction: EndAnyFunction {}

class Return: Operation {
    init() {
        super.init(numInputs: 1, numOutputs: 0, attributes: [.isJump], requiredContext: [.script, .function])
    }
}

class DifferentialHash: Operation {
    let allowInnerScope: Bool
    init(allowInnerScope: Bool) {
        self.allowInnerScope = allowInnerScope
        let requiredContext: Context = allowInnerScope ? [] : [.script]
        super.init(numInputs: 1, numOutputs: 0, attributes: [], requiredContext: requiredContext)
    }
}

// A yield expression in JavaScript
class Yield: Operation {
    init() {
        super.init(numInputs: 1, numOutputs: 1, attributes: [], requiredContext: [.script, .generatorFunction])
    }
}

// A yield* expression in JavaScript
class YieldEach: Operation {
    init() {
        super.init(numInputs: 1, numOutputs: 0, attributes: [], requiredContext: [.script, .generatorFunction])
    }
}

class Await: Operation {
    init() {
        super.init(numInputs: 1, numOutputs: 1, attributes: [], requiredContext: [.script, .asyncFunction])
    }
}

class CallFunction: Operation {
    var numArguments: Int {
        return numInputs - 1
    }

    init(numArguments: Int) {
        // The called function is the first input.
        super.init(numInputs: numArguments + 1, numOutputs: 1, firstVariadicInput: 1, attributes: [.isVariadic, .isCall])
    }
}

class CallFunctionWithSpread: Operation {
    let spreads: [Bool]

    var numArguments: Int {
        return numInputs - 1
    }

    init(numArguments: Int, spreads: [Bool]) {
        Assert(!spreads.isEmpty)
        Assert(spreads.count == numArguments)
        self.spreads = spreads
        // The called function is the first input.
        super.init(numInputs: numArguments + 1, numOutputs: 1, firstVariadicInput: 1, attributes: [.isVariadic, .isCall, .isMutable])
    }
}

class Construct: Operation {
    var numArguments: Int {
        return numInputs - 1
    }

    init(numArguments: Int) {
        // The constructor is the first input
        super.init(numInputs: numArguments + 1, numOutputs: 1, firstVariadicInput: 1, attributes: [.isVariadic, .isCall])
    }
}

class ConstructWithSpread: Operation {
    let spreads: [Bool]

    var numArguments: Int {
        return numInputs - 1
    }

    init(numArguments: Int, spreads: [Bool]) {
        Assert(!spreads.isEmpty)
        Assert(spreads.count == numArguments)
        self.spreads = spreads
        // The constructor is the first input
        super.init(numInputs: numArguments + 1, numOutputs: 1, firstVariadicInput: 1, attributes: [.isVariadic, .isCall, .isMutable])
    }
}

class CallMethod: Operation {
    let methodName: String

    var numArguments: Int {
        return numInputs - 1
    }

    init(methodName: String, numArguments: Int) {
        self.methodName = methodName
        // reference object is the first input
        super.init(numInputs: numArguments + 1, numOutputs: 1, firstVariadicInput: 1, attributes: [.isMutable, .isVariadic, .isCall])
    }
}

class CallMethodWithSpread: Operation {
    let methodName: String
    let spreads: [Bool]

    var numArguments: Int {
        return numInputs - 1
    }

    init(methodName: String, numArguments: Int, spreads: [Bool]) {
        Assert(!spreads.isEmpty)
        Assert(spreads.count == numArguments)
        self.methodName = methodName
        self.spreads = spreads
        // reference object is the first input
        super.init(numInputs: numArguments + 1, numOutputs: 1, firstVariadicInput: 1, attributes: [.isMutable, .isVariadic, .isCall])
    }
}

class CallComputedMethod: Operation {
    var numArguments: Int {
        return numInputs - 2
    }

    init(numArguments: Int) {
        // The reference object is the first input and method name is the second input
        super.init(numInputs: numArguments + 2, numOutputs: 1, firstVariadicInput: 2, attributes: [.isVariadic, .isCall])
    }
}

class CallComputedMethodWithSpread: Operation {
    let spreads: [Bool]

    var numArguments: Int {
        return numInputs - 2
    }

    init(numArguments: Int, spreads: [Bool]) {
        Assert(!spreads.isEmpty)
        Assert(spreads.count == numArguments)
        self.spreads = spreads
        // The reference object is the first input and the method name is the second input
        super.init(numInputs: numArguments + 2, numOutputs: 1, firstVariadicInput: 2, attributes: [.isVariadic, .isCall, .isMutable])
    }
}

public enum UnaryOperator: String, CaseIterable {
    case PreInc     = "++"
    case PreDec     = "--"
    case PostInc    = "++ "     // Raw value must be unique
    case PostDec    = "-- "     // Raw value must be unique
    case LogicalNot = "!"
    case BitwiseNot = "~"
    case Plus       = "+"
    case Minus      = "-"

    var token: String {
        return self.rawValue.trimmingCharacters(in: [" "])
    }

    var reassignsInput: Bool {
        return self == .PreInc || self == .PreDec || self == .PostInc || self == .PostDec
    }

    var isPostfix: Bool {
        return self == .PostInc || self == .PostDec
    }
}

// This array must be kept in sync with the UnaryOperator Enum in operations.proto
let allUnaryOperators = UnaryOperator.allCases

class UnaryOperation: Operation {
    let op: UnaryOperator

    init(_ op: UnaryOperator) {
        self.op = op
        super.init(numInputs: 1, numOutputs: 1, attributes: [.isMutable])
    }
}

public enum BinaryOperator: String, CaseIterable {
    case Add      = "+"
    case Sub      = "-"
    case Mul      = "*"
    case Div      = "/"
    case Mod      = "%"
    case BitAnd   = "&"
    case BitOr    = "|"
    case LogicAnd = "&&"
    case LogicOr  = "||"
    case Xor      = "^"
    case LShift   = "<<"
    case RShift   = ">>"
    case Exp      = "**"
    case UnRShift = ">>>"

    var token: String {
        return self.rawValue
    }
}

// This array must be kept in sync with the BinaryOperator Enum in operations.proto
let allBinaryOperators = BinaryOperator.allCases

class BinaryOperation: Operation {
    let op: BinaryOperator

    init(_ op: BinaryOperator) {
        self.op = op
        super.init(numInputs: 2, numOutputs: 1, attributes: [.isMutable])
    }
}

/// Assigns a value to its left operand based on the value of its right operand.
class ReassignWithBinop: Operation {
    let op: BinaryOperator

    init(_ op: BinaryOperator) {
        self.op = op
        super.init(numInputs: 2, numOutputs: 0)
    }
}

/// Duplicates a variable, essentially doing `output = input;`
class Dup: Operation {
    init() {
        super.init(numInputs: 1, numOutputs: 1)
    }
}

/// Reassigns an existing variable, essentially doing `input1 = input2;`
class Reassign: Operation {
    init() {
        super.init(numInputs: 2, numOutputs: 0)
    }
}

/// Destructs an array into n output variables
class DestructArray: Operation {
    let indices: [Int]
    let hasRestElement: Bool

    init(indices: [Int], hasRestElement: Bool) {
        Assert(indices == indices.sorted(), "Indices must be sorted in ascending order")
        Assert(indices.count == Set(indices).count, "Indices must not have duplicates")
        self.indices = indices
        self.hasRestElement = hasRestElement
        super.init(numInputs: 1, numOutputs: indices.count)
    }
}

/// Destructs an array and reassigns the output to n existing variables
class DestructArrayAndReassign: Operation {
    let indices: [Int]
    let hasRestElement: Bool

    init(indices: [Int], hasRestElement:Bool) {
        Assert(indices == indices.sorted(), "Indices must be sorted in ascending order")
        Assert(indices.count == Set(indices).count, "Indices must not have duplicates")
        self.indices = indices
        self.hasRestElement = hasRestElement
        // The first input is the array being destructed
        super.init(numInputs: 1 + indices.count, numOutputs: 0)
    }
}

/// Destructs an object into n output variables
class DestructObject: Operation {
    let properties: [String]
    let hasRestElement: Bool

    init(properties: [String], hasRestElement: Bool) {
        Assert(!properties.isEmpty || hasRestElement, "Must have at least one output")
        self.properties = properties
        self.hasRestElement = hasRestElement
        super.init(numInputs: 1, numOutputs: properties.count + (hasRestElement ? 1 : 0))
    }
}

/// Destructs an object and reassigns the output to n existing variables
class DestructObjectAndReassign: Operation {
    let properties: [String]
    let hasRestElement: Bool

    init(properties: [String], hasRestElement:Bool) {
        Assert(!properties.isEmpty || hasRestElement, "Must have at least one input variable to reassign")
        self.properties = properties
        self.hasRestElement = hasRestElement
        // The first input is the object being destructed
        super.init(numInputs: 1 + properties.count + (hasRestElement ? 1 : 0), numOutputs: 0)
    }
}

// This array must be kept in sync with the Comparator Enum in operations.proto
public enum Comparator: String {
    case equal              = "=="
    case strictEqual        = "==="
    case notEqual           = "!="
    case strictNotEqual     = "!=="
    case lessThan           = "<"
    case lessThanOrEqual    = "<="
    case greaterThan        = ">"
    case greaterThanOrEqual = ">="

    var token: String {
        return self.rawValue
    }
}

let allComparators: [Comparator] = [.equal, .strictEqual, .notEqual, .strictNotEqual, .lessThan, .lessThanOrEqual, .greaterThan, .greaterThanOrEqual]

class Compare: Operation {
    let op: Comparator

    init(_ comparator: Comparator) {
        self.op = comparator
        super.init(numInputs: 2, numOutputs: 1, attributes: [.isMutable])
    }
}

/// Allows generation of conditional (i.e. condition ? exprIfTrue : exprIfFalse) statements
class ConditionalOperation: Operation {
    init() {
        super.init(numInputs: 3, numOutputs: 1)
    }
}

/// An operation that will be lifted to a given string. The string can use %@ placeholders which
/// will be replaced by the expressions for the input variables during lifting.
class Eval: Operation {
    let code: String

    init(_ string: String, numArguments: Int) {
        self.code = string
        super.init(numInputs: numArguments, numOutputs: 0, numInnerOutputs: 0)
    }
}

class BeginWith: Operation {
    init() {
        super.init(numInputs: 1, numOutputs: 0, attributes: [.isBlockStart, .propagatesSurroundingContext], contextOpened: [.script, .with])
    }
}

class EndWith: Operation {
    init() {
        super.init(numInputs: 0, numOutputs: 0, attributes: [.isBlockEnd])
    }
}

class LoadFromScope: Operation {
    let id: String

    init(id: String) {
        self.id = id
        super.init(numInputs: 0, numOutputs: 1, attributes: [.isMutable], requiredContext: [.script, .with])
    }
}

class StoreToScope: Operation {
    let id: String

    init(id: String) {
        self.id = id
        super.init(numInputs: 1, numOutputs: 0, attributes: [.isMutable], requiredContext: [.script, .with])
    }
}

class Nop: Operation {
    // NOPs can have "pseudo" outputs. These should not be used by other instructions
    // and they should not be present in the lifted code, i.e. a NOP should just be
    // ignored during lifting.
    // These pseudo outputs are used to simplify some algorithms, e.g. minimization,
    // which needs to replace instructions with NOPs while keeping the variable numbers
    // contiguous. They can also serve as placeholders for future instructions.
    init(numOutputs: Int = 0) {
        super.init(numInputs: 0, numOutputs: numOutputs)
    }
}

///
/// Classes
///
/// Classes in FuzzIL look roughly as follows:
///
///     BeginClass superclass, properties, methods, constructor parameters
///         < constructor code >
///     BeginMethod
///         < code of first method >
///     BeginMethod
///         < code of second method >
///     EndClass
///
///  This design solves the following two requirements:
///  - All information about the instance type must be contained in the BeginClass operation so that
///    the AbstractInterpreter and other static analyzers have the instance type when processing the body
///  - Method definitions must be part of a block group and not standalone blocks. Otherwise, splicing might end
///    up copying only a method definition without the surrounding class definition, which would be syntactically invalid.
///
class BeginClass: Operation {
    let hasSuperclass: Bool
    let constructorParameters: [Parameter]
    let instanceProperties: [String]
    let instanceMethods: [(name: String, signature: FunctionSignature)]

    init(hasSuperclass: Bool,
         constructorParameters: [Parameter],
         instanceProperties: [String],
         instanceMethods: [(String, FunctionSignature)]) {
        self.hasSuperclass = hasSuperclass
        self.constructorParameters = constructorParameters
        self.instanceProperties = instanceProperties
        self.instanceMethods = instanceMethods
        super.init(numInputs: hasSuperclass ? 1 : 0,
                   numOutputs: 1,
                   numInnerOutputs: 1 + constructorParameters.count,    // Implicit this is first inner output
                   attributes: [.isBlockStart], contextOpened: [.script, .classDefinition, .function])
    }
}

// A class instance method. Always has the implicit |this| parameter as first inner output.
class BeginMethod: Operation {
    var numParameters: Int {
        return numInnerOutputs - 1
    }

    init(numParameters: Int) {
        super.init(numInputs: 0,
                   numOutputs: 0,
                   numInnerOutputs: 1 + numParameters,      // Implicit this is first inner output
                   attributes: [.isBlockStart, .isBlockEnd], requiredContext: .classDefinition, contextOpened: [.script, .classDefinition, .function])
    }
}

class EndClass: Operation {
    init() {
        super.init(numInputs: 0, numOutputs: 0, attributes: [.isBlockEnd])
    }
}

class CallSuperConstructor: Operation {
    var numArguments: Int {
        return numInputs
    }

    init(numArguments: Int) {
        super.init(numInputs: numArguments, numOutputs: 0, firstVariadicInput: 0, attributes: [.isVariadic, .isCall], requiredContext: [.script, .classDefinition])
    }
}

class CallSuperMethod: Operation {
    let methodName: String

    var numArguments: Int {
        return numInputs
    }

    init(methodName: String, numArguments: Int) {
        self.methodName = methodName
        super.init(numInputs: numArguments, numOutputs: 1, firstVariadicInput: 0, attributes: [.isCall, .isMutable, .isVariadic], requiredContext: [.script, .classDefinition])
    }
}

class LoadSuperProperty: Operation {
    let propertyName: String

    init(propertyName: String) {
        self.propertyName = propertyName
        super.init(numInputs: 0, numOutputs: 1, attributes: [.isMutable], requiredContext: [.script, .classDefinition])
    }
}

class StoreSuperProperty: Operation {
    let propertyName: String

    init(propertyName: String) {
        self.propertyName = propertyName
        super.init(numInputs: 1, numOutputs: 0, attributes: [.isMutable], requiredContext: [.script, .classDefinition])
    }
}

class StoreSuperPropertyWithBinop: Operation {
    let propertyName: String
    let op: BinaryOperator

    init(propertyName: String, operator op: BinaryOperator) {
        self.propertyName = propertyName
        self.op = op
        super.init(numInputs: 1, numOutputs: 0, attributes: [.isMutable], requiredContext: [.script, .classDefinition])
    }
}

///
/// Control Flow
///
class ControlFlowOperation: Operation {
    init(numInputs: Int, numInnerOutputs: Int = 0, attributes: Operation.Attributes, contextOpened: Context = .script) {
        Assert(attributes.contains(.isBlockStart) || attributes.contains(.isBlockEnd))
        super.init(numInputs: numInputs, numOutputs: 0, numInnerOutputs: numInnerOutputs, attributes: attributes.union(.propagatesSurroundingContext), contextOpened: contextOpened)
    }
}

class BeginIf: ControlFlowOperation {
    init() {
        super.init(numInputs: 1, attributes: [.isBlockStart])
    }
}

class BeginElse: ControlFlowOperation {
    init() {
        super.init(numInputs: 0, attributes: [.isBlockEnd, .isBlockStart])
    }
}

class EndIf: ControlFlowOperation {
    init() {
        super.init(numInputs: 0, attributes: [.isBlockEnd])
    }
}

/// The block content is the body of the first switch case
class BeginSwitch: ControlFlowOperation {

    var isDefaultCase: Bool {
        return numInputs == 1
    }

    init(numArguments: Int) {
        super.init(numInputs: numArguments, attributes: [.isBlockStart], contextOpened: [.script, .switchCase])
    }
}

class BeginSwitchCase: ControlFlowOperation {
    /// If true, causes the preceding case to fall through to it (and so no "break;" is emitted by the Lifter)
    let previousCaseFallsThrough: Bool

    var isDefaultCase: Bool {
        return numInputs == 0
    }

    init(numArguments: Int, fallsThrough: Bool) {
        self.previousCaseFallsThrough = fallsThrough
        super.init(numInputs: numArguments, attributes: [.isBlockStart, .isBlockEnd], contextOpened: [.script, .switchCase])
    }
}

class EndSwitch: ControlFlowOperation {
    init() {
        super.init(numInputs: 0, attributes: [.isBlockEnd])
    }
}

class SwitchBreak: Operation {
    init() {
        super.init(numInputs: 0, numOutputs: 0, attributes: [.isJump], requiredContext: [.script, .switchCase])
    }
}

class BeginWhileLoop: ControlFlowOperation {
    let comparator: Comparator
    init(comparator: Comparator) {
        self.comparator = comparator
        super.init(numInputs: 2, attributes: [.isMutable, .isBlockStart, .isLoop], contextOpened: [.script, .loop])
    }
}

class EndWhileLoop: ControlFlowOperation {
    init() {
        super.init(numInputs: 0, attributes: [.isBlockEnd, .isLoop])
    }
}

// Even though the loop condition is evaluated during EndDoWhile,
// the inputs are kept in BeginDoWhile as they have to come from
// the outer scope. Otherwise, special handling of EndDoWhile would
// be necessary throughout the IL, this way, only the Lifter has to
// be a bit more clever.
class BeginDoWhileLoop: ControlFlowOperation {
    let comparator: Comparator
    init(comparator: Comparator) {
        self.comparator = comparator
        super.init(numInputs: 2, attributes: [.isMutable, .isBlockStart, .isLoop], contextOpened: [.script, .loop])
    }
}

class EndDoWhileLoop: ControlFlowOperation {
    init() {
        super.init(numInputs: 0, attributes: [.isBlockEnd, .isLoop])
    }
}

class BeginForLoop: ControlFlowOperation {
    let comparator: Comparator
    let op: BinaryOperator
    init(comparator: Comparator, op: BinaryOperator) {
        self.comparator = comparator
        self.op = op
        super.init(numInputs: 3, numInnerOutputs: 1, attributes: [.isMutable, .isBlockStart, .isLoop], contextOpened: [.script, .loop])
    }
}

class EndForLoop: ControlFlowOperation {
    init() {
        super.init(numInputs: 0, attributes: [.isBlockEnd, .isLoop])
    }
}

class BeginForInLoop: ControlFlowOperation {
    init() {
        super.init(numInputs: 1, numInnerOutputs: 1, attributes: [.isBlockStart, .isLoop], contextOpened: [.script, .loop])
    }
}

class EndForInLoop: ControlFlowOperation {
    init() {
        super.init(numInputs: 0, attributes: [.isBlockEnd, .isLoop])
    }
}

class BeginForOfLoop: ControlFlowOperation {
    init() {
        super.init(numInputs: 1, numInnerOutputs: 1, attributes: [.isBlockStart, .isLoop], contextOpened: [.script, .loop])
    }
}

class BeginForOfWithDestructLoop: ControlFlowOperation {
    let indices: [Int]
    let hasRestElement: Bool

    init(indices: [Int], hasRestElement: Bool) {
        Assert(indices.count >= 1)
        self.indices = indices
        self.hasRestElement = hasRestElement
        super.init(numInputs: 1, numInnerOutputs: indices.count, attributes: [.isBlockStart, .isLoop], contextOpened: [.script, .loop])
    }
}

class EndForOfLoop: ControlFlowOperation {
    init() {
        super.init(numInputs: 0, attributes: [.isBlockEnd, .isLoop])
    }
}

class LoopBreak: Operation {
    init() {
        super.init(numInputs: 0, numOutputs: 0, attributes: [.isJump], requiredContext: [.script, .loop])
    }
}

class LoopContinue: Operation {
    init() {
        super.init(numInputs: 0, numOutputs: 0, attributes: [.isJump], requiredContext: [.script, .loop])
    }
}

class BeginTry: ControlFlowOperation {
    init() {
        super.init(numInputs: 0, attributes: [.isBlockStart])
    }
}

class BeginCatch: ControlFlowOperation {
    init() {
        super.init(numInputs: 0, numInnerOutputs: 1, attributes: [.isBlockStart, .isBlockEnd])
    }
}

class BeginFinally: ControlFlowOperation {
    init() {
        super.init(numInputs: 0, attributes: [.isBlockStart, .isBlockEnd])
    }
}

class EndTryCatchFinally: ControlFlowOperation {
    init() {
        super.init(numInputs: 0, attributes: [.isBlockEnd])
    }
}

class ThrowException: Operation {
    init() {
        super.init(numInputs: 1, numOutputs: 0, attributes: [.isJump])
    }
}

/// Generates a block of instructions, which is lifted to a string literal, that is a suitable as an argument to eval()
class BeginCodeString: Operation {
    init() {
        super.init(numInputs: 0, numOutputs: 1, attributes: [.isBlockStart], contextOpened: .script)
    }
}

class EndCodeString: Operation {
    init() {
        super.init(numInputs: 0, numOutputs: 0, attributes: [.isBlockEnd])
    }
}

/// Generates a block of instructions, which is lifted to a block statement.
class BeginBlockStatement: Operation {
    init() {
        super.init(numInputs: 0, numOutputs: 0, attributes: [.isBlockStart, .propagatesSurroundingContext], contextOpened: .script)
    }
}

class EndBlockStatement: Operation {
    init() {
        super.init(numInputs: 0, numOutputs: 0, attributes: [.isBlockEnd])
    }
}

/// Internal operations.
///
/// These can be used for internal fuzzer operations but will not appear in the corpus.
class InternalOperation: Operation {
    init(numInputs: Int) {
        super.init(numInputs: numInputs, numOutputs: 0, attributes: [.isInternal])
    }
}

/// Writes the argument to the output stream.
class Print: InternalOperation {
    init() {
        super.init(numInputs: 1)
    }
}


// Expose the name of an operation as instance and class variable
extension Operation {
    var name: String {
        return String(describing: type(of: self))
    }

    class var name: String {
        return String(describing: self)
    }
}
