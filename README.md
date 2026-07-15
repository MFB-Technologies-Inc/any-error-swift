# AnyError

[![ci](https://github.com/MFB-Technologies-Inc/any-error-swift/actions/workflows/ci.yml/badge.svg)](https://github.com/MFB-Technologies-Inc/any-error-swift/actions/workflows/ci.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FMFB-Technologies-Inc%2Fany-error-swift%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/MFB-Technologies-Inc/any-error-swift)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FMFB-Technologies-Inc%2Fany-error-swift%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/MFB-Technologies-Inc/any-error-swift)

A concrete, value-semantic, `Hashable` error type that erases errors on every Swift platform, with or without Foundation, while retaining all the important information carried in the original error.

  * [Motivation](#motivation)
  * [The problem](#the-problem)
  * [The solution](#the-solution)
  * [Erasing any error](#erasing-any-error)
  * [Your own error types](#your-own-error-types)
  * [Localized errors](#localized-errors)
  * [Platform support](#platform-support)
  * [Documentation](#documentation)
  * [Installation](#installation)
  * [License](#license)

## Motivation

Swift's `Error` is a protocol, so the moment you need to *store* an error you reach for the
existential `any Error`. That box is convenient to throw around, but it's a poor thing to hold onto.
It isn't `Equatable` or `Hashable`, so a value type that stores one can't synthesize those
conformances either, ruling it out of a feature's `Equatable` state, a `Set`, or a dictionary key.
Getting anything useful out of it beyond a `localizedDescription`
also means knowing which concrete type is inside and downcasting to it, whether that's a `URLError`, a
database driver's error, or whatever else your dependencies happened to throw.

Where full Foundation is available you could bridge to `NSError` instead, which recovers some of
this: an `NSError` is `Equatable` and `Hashable`, and it carries a `code`, a `domain`, and localized
messages. But it's a reference type rather than a value, it doesn't preserve the name of the Swift
type the error came from, and it depends on Foundation, which isn't available (or even desirable) on
every platform Swift runs on.

`AnyError` is a plain value type that captures the useful parts of an error: its
`localizedDescription`, `code`, `domain`, the name of the type it came from, and the rest of the
`LocalizedError` details (`failureReason`, `helpAnchor`, and `recoverySuggestion`). It's `Hashable`
and `Equatable`, it stores cleanly in your models whether or not Foundation is available, and it
hides the implementation details of your dependencies behind a single, stable type.

## The problem

Say your feature keeps its state in a value type, and part of that state is whether the last load
failed:

```swift
struct ProfileState: Equatable {
  var profile: Profile?
  var loadError: (any Error)?   // 👈 'any Error' is not Equatable
}
```

This doesn't compile. Because `any Error` isn't `Equatable`, `ProfileState` can't synthesize the
`Equatable` conformance it asks for:

> 🛑 Type 'ProfileState' does not conform to protocol 'Equatable'

The same is true for `Hashable`, and for putting an error in a `Set` or a dictionary key. And even
where you don't need equality, an `any Error` is opaque: reading anything structured out of it, such
as a `code` to branch on or a `domain`, means knowing which concrete type is inside and downcasting
to it, whether that's a `URLError`, a driver-specific database error, or a third-party SDK's error.

## The solution

Store an `AnyError` instead. Now `ProfileState` conforms to `Equatable` without complaint:

```swift
import AnyError

struct ProfileState: Equatable {
  var profile: Profile?
  var loadError: AnyError?   // ✅ Equatable and Hashable
}
```

Erase whatever was thrown at the point you catch it:

```swift
do {
  state.profile = try await repository.fetch()
} catch {
  state.loadError = AnyError(unknown: error)   // 👈 erase whatever was thrown
}
```

`AnyError` keeps the information you actually want to display or log, and drops the type you didn't
want to leak. Say `repository.fetch()` failed with a `URLError(.timedOut)`:

```swift
state.loadError?.localizedDescription  // "The operation couldn’t be completed. (NSURLErrorDomain error -1001.)"
state.loadError?.code                  // -1001
state.loadError?.domain                // "NSURLErrorDomain"
state.loadError?.originatingTypeName   // "NSError"
```

`code` and `domain` come straight from the error. `originatingTypeName` is `"NSError"` here because
`URLError` (like most Foundation error types) bridges to `NSError`, so that is the concrete type
`AnyError(unknown:)` sees. For an error type you own, conform it to
[`CustomAnyError`](#your-own-error-types) and its real Swift type name is retained instead.

## Erasing any error

`init(unknown:)` accepts any error and erases it:

```swift
let erased = AnyError(unknown: URLError(.timedOut))
```

  * If it's already an `AnyError`, it's returned unchanged.
  * If it conforms to [`CustomAnyError`](#your-own-error-types), its `code`/`domain` are carried over.
  * Otherwise, on platforms with full Foundation, the error is bridged through `NSError` to recover
    its `code` and `domain`; elsewhere those are derived from the error's type.

`AnyError` conforms to `LocalizedError`, `CustomStringConvertible`, and `CustomDebugStringConvertible`,
so printing or logging it produces readable output:

```swift
print(erased)
// NSURLErrorDomain code=-1001: The operation couldn’t be completed. (NSURLErrorDomain error -1001.)

print(erased.debugDescription)
// AnyError {
// 	localizedDescription: The operation couldn’t be completed. (NSURLErrorDomain error -1001.),
// 	originatingTypeName: NSError,
// 	code: -1001,
// 	domain: NSURLErrorDomain
// }
```

## Your own error types

If you own an error type, conform it to `CustomAnyError` and it maps to `AnyError` automatically,
with no bridging guesswork:

```swift
import AnyError

enum ProfileError: CustomAnyError {
  case notFound
  case unauthorized

  var code: Int {
    switch self {
    case .notFound: 404
    case .unauthorized: 401
    }
  }

  var localizedDescription: String {
    switch self {
    case .notFound: "That profile could not be found."
    case .unauthorized: "You are not allowed to view this profile."
    }
  }
}

let erased = AnyError(custom: ProfileError.notFound)
erased.code    // 404
erased.domain  // "ProfileError"
```

Anywhere full Foundation is available, `CustomAnyError` also refines
`CustomNSError`. That means even if your error is thrown as `any Error`, bridged to `NSError`, and
handed back to you from some framework, you can recover the original:

```swift
let nsError = ProfileError.notFound as NSError
AnyError.original(from: nsError)   // the original AnyError, code 404 and all
```

## Localized errors

`AnyError` is itself a `LocalizedError`. Beyond `localizedDescription`, it captures the other three
localization fields (`failureReason`, `helpAnchor`, and `recoverySuggestion`) from whatever error
you erase, so nothing an alert or error UI needs is lost along the way:

```swift
let erased = AnyError(unknown: someLocalizedError)

erased.errorDescription      // same as localizedDescription
erased.failureReason         // preserved from the original
erased.helpAnchor            // preserved from the original
erased.recoverySuggestion    // preserved from the original
```

Because `AnyError` conforms to `LocalizedError`, its stored `localizedDescription` stays
authoritative even when the value is read back through `any Error`; the bridge reads
`errorDescription`, which `AnyError` backs with its own stored description.

## Platform support

`AnyError` is available **everywhere Swift runs**: Apple platforms (iOS, macOS, tvOS, watchOS,
visionOS), Linux, Windows, and WebAssembly. It even works on platforms that ship only
`FoundationEssentials`, or no Foundation at all.

The behavior that requires full Foundation (`NSError` bridging via `init(nsError:)` and
`AnyError.original(from:)`, and the `CustomNSError` refinement of `CustomAnyError`) is only compiled
in where `Foundation` can be imported. Everything else behaves identically on every platform. On
non-Apple platforms you can opt into full Foundation with the `FullFoundation` package trait, which
is enabled by default.

> [!NOTE]
> When full Foundation isn't imported or available, erasing an arbitrary error with
> `AnyError(unknown:)` has no `NSError` to draw from, so its `code` defaults to `0` and its `domain`
> is derived from the error's type. Values that are already an `AnyError` or a `CustomAnyError` keep
> their `code` and `domain` everywhere.

### Embedded Swift

In Embedded Swift there is no `Error` existential to type-cast against and no `NSError` to bridge
through, so `AnyError(unknown:)` (which relies on both) is not available. The reduced API surface is:

  * the memberwise initializer, for constructing an `AnyError` from values you already have, and
  * `AnyError(custom:)`, for erasing a [`CustomAnyError`](#your-own-error-types) you own.

Because reflection is also absent, a `CustomAnyError` conformer must supply `defaultDomain` and
`originatingTypeName` explicitly there rather than relying on their reflection-derived defaults. The
localized metadata (`failureReason`/`helpAnchor`/`recoverySuggestion`) is always `nil` in Embedded,
as there is no `LocalizedError` existential to read it from.

## Documentation

  * [`main`](https://swiftpackageindex.com/MFB-Technologies-Inc/any-error-swift/main/documentation/anyerror/)
  * [0.x.x](https://swiftpackageindex.com/MFB-Technologies-Inc/any-error-swift/~/documentation/anyerror/)

## Installation

You can add `AnyError` to an Xcode project by adding it as a package dependency.

> https://github.com/MFB-Technologies-Inc/any-error-swift

If you want to use `AnyError` in a [SwiftPM](https://swift.org/package-manager/) project, add it to
your `Package.swift`:

``` swift
dependencies: [
  .package(url: "https://github.com/MFB-Technologies-Inc/any-error-swift", from: "0.1.0")
]
```

And then add the product to any target that needs access to the library:

``` swift
.product(name: "AnyError", package: "any-error-swift"),
```

## License

This library is released under the MIT license. See [LICENSE](LICENSE) for details.
