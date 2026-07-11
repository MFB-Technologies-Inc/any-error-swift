// AnyError.swift
// AnyError
//
// Copyright MFB Technologies, Inc. All rights reserved.
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

/// Generalized, concrete implementation of `Error`.
///
/// ``AnyError`` helps you avoid the existential `any Error` or erase a
/// dependency-specific error type to hide implementation details.
///
/// Erase a caught error with ``init(unknown:)``. Because the erased type is concrete, it can be named in a typed
/// `throws` clause instead of leaking internal or third-party error types to callers while not losing any error
/// information:
///
/// ```swift
/// func loadProfile() throws(AnyError) {
///     do {
///         try database.fetchProfile()
///     } catch {
///         throw AnyError(unknown: error)
///     }
/// }
/// ```
///
/// A ``CustomAnyError`` conformer can be erased directly with ``init(custom:)``, preserving its ``code`` and
/// ``domain``:
///
/// ```swift
/// throw AnyError(custom: ProfileError.notFound)
/// ```
///
/// ``code`` and ``domain`` are also available for storing information from an `NSError`
/// or other error types that carry those values.
///
/// > Note: ``AnyError`` is available on every platform, including those without `Foundation` or with only
/// > `FoundationEssentials`. Behavior that requires full `Foundation` (`NSError` bridging via
/// > ``init(nsError:)`` and ``original(from:)``) is only available where `Foundation` can be imported.
///
/// > Important: `Equatable`/`Hashable` compare *all* stored values, including the localized strings
/// > (``localizedDescription``, ``failureReason``, ``helpAnchor``, ``recoverySuggestion``). The same
/// > underlying failure erased under two different locales therefore compares unequal. If you need
/// > locale-independent identity, compare ``code`` and ``domain`` yourself.
public struct AnyError: Error, Hashable, Sendable {
    /// A string containing the description of the error. It may or may not be localized depending on the original
    /// source of the description.
    ///
    /// When populated by ``init(unknown:)`` it is taken, in order, from: the original error's
    /// `LocalizedError.errorDescription`; the `localizedDescription` of the `NSError` it is or bridges to; or
    /// `String(describing:)` of the original error. The last case uses `String(describing:)` rather than
    /// `Error.localizedDescription` because, for a type that is not a `LocalizedError`, `Error.localizedDescription`
    /// bridges to `NSError` and returns a generic "The operation couldn't be completed…" message, while
    /// `String(describing:)` keeps the original error's own contents. ``init(custom:)`` copies the conformer's
    /// ``CustomAnyError`` description.
    public let localizedDescription: String
    /// The name of the original error's type.
    ///
    /// When `Foundation` or `FoundationEssentials` is imported, this is set to `String(reflecting:)` of the original
    /// error's type unless overridden by ``CustomAnyError`` conformance. That means it should be a fully qualified,
    /// dot-separated type name like `ModuleName.EnclosingTypeName.TypeName`. The exception is an error erased
    /// through the `NSError` path (``init(nsError:)``, or ``init(unknown:)`` given an error whose dynamic type is an
    /// `NSError` subclass): those report `"NSError"` rather than a reflected Swift type name.
    public let originatingTypeName: String
    /// An integer code categorizing the error, analogous to `NSError.code`.
    ///
    /// On Apple platforms, or when full `Foundation` is available, it is set from the bridged `NSError.code` unless
    /// overridden by ``CustomAnyError`` conformance. On platforms without `NSError` bridging (including
    /// `FoundationEssentials`-only platforms and Embedded Swift), it defaults to `0` unless overridden by
    /// ``CustomAnyError`` conformance.
    public let code: Int
    /// A string identifying the error's domain, analogous to `NSError.domain`.
    ///
    /// On Apple platforms, or when full `Foundation` is available, it is set from the bridged `NSError.domain` unless
    /// overridden by ``CustomAnyError`` conformance. On platforms without `NSError` bridging, it defaults to
    /// `String(reflecting:)` of the original error's type unless overridden by ``CustomAnyError`` conformance.
    public let domain: String
    /// A localized message describing the reason for the failure, mirroring `LocalizedError.failureReason`.
    ///
    /// Populated from `LocalizedError.failureReason` when the original error conforms to `LocalizedError`, or from
    /// `NSError.localizedFailureReason` when bridging an `NSError`. It is `nil` when no such value is available, and
    /// always `nil` in Embedded Swift where there is no `LocalizedError` existential to probe.
    public let failureReason: String?
    /// A localized message providing help-anchor text for the error, mirroring `LocalizedError.helpAnchor`.
    ///
    /// Populated from `LocalizedError.helpAnchor` when the original error conforms to `LocalizedError`, or from
    /// `NSError.helpAnchor` when bridging an `NSError`. It is `nil` when no such value is available, and always `nil`
    /// in Embedded Swift where there is no `LocalizedError` existential to probe.
    public let helpAnchor: String?
    /// A localized message describing how the user might recover from the failure, mirroring
    /// `LocalizedError.recoverySuggestion`.
    ///
    /// Populated from `LocalizedError.recoverySuggestion` when the original error conforms to `LocalizedError`, or from
    /// `NSError.localizedRecoverySuggestion` when bridging an `NSError`. It is `nil` when no such value is available,
    /// and always `nil` in Embedded Swift where there is no `LocalizedError` existential to probe.
    public let recoverySuggestion: String?

    /// Creates an error by supplying every stored value directly.
    ///
    /// Most callers should prefer ``init(custom:)``, ``init(unknown:)``, or ``init(nsError:)``, which derive these
    /// values from an existing error. Use this initializer when constructing an ``AnyError`` from scratch.
    ///
    /// - Parameters:
    ///   - localizedDescription: The value for ``localizedDescription``.
    ///   - originatingTypeName: The value for ``originatingTypeName``.
    ///   - code: The value for ``code``.
    ///   - domain: The value for ``domain``.
    ///   - failureReason: The value for ``failureReason``.
    ///   - helpAnchor: The value for ``helpAnchor``.
    ///   - recoverySuggestion: The value for ``recoverySuggestion``.
    @inlinable
    public init(
        localizedDescription: String,
        originatingTypeName: String,
        code: Int,
        domain: String,
        failureReason: String?,
        helpAnchor: String?,
        recoverySuggestion: String?,
    ) {
        self.localizedDescription = localizedDescription
        self.originatingTypeName = originatingTypeName
        self.code = code
        self.domain = domain
        self.failureReason = failureReason
        self.helpAnchor = helpAnchor
        self.recoverySuggestion = recoverySuggestion
    }

    /// Creates an error from a ``CustomAnyError``, copying its ``code``, ``domain``, description, and localized
    /// metadata.
    ///
    /// > Note: In Embedded Swift there is no `LocalizedError` existential to probe, so the localized metadata
    /// > (``failureReason``/``helpAnchor``/``recoverySuggestion``) is unavailable and left `nil`.
    ///
    /// - Parameter error: The error to erase into an ``AnyError``.
    @inlinable
    public init(custom error: some CustomAnyError) {
        #if !Embedded
            let localizedError = error as? any LocalizedError
            let failureReason = localizedError?.failureReason
            let helpAnchor = localizedError?.helpAnchor
            let recoverySuggestion = localizedError?.recoverySuggestion
        #else
            let failureReason: String? = nil
            let helpAnchor: String? = nil
            let recoverySuggestion: String? = nil
        #endif
        self.init(
            localizedDescription: error.localizedDescription,
            originatingTypeName: error.originatingTypeName,
            code: error.code,
            domain: error.domain,
            failureReason: failureReason,
            helpAnchor: helpAnchor,
            recoverySuggestion: recoverySuggestion,
        )
    }
}

extension AnyError: CustomStringConvertible {
    @inlinable
    public var description: String {
        "\(domain) code=\(code): \(localizedDescription)"
    }
}

extension AnyError: CustomDebugStringConvertible {
    @inlinable
    public var debugDescription: String {
        var body = """
        \tlocalizedDescription: \(localizedDescription),
        \toriginatingTypeName: \(originatingTypeName),
        \tcode: \(code),
        \tdomain: \(domain)
        """
        // Include the localized fields only when set; they are usually nil.
        if let failureReason {
            body += ",\n\tfailureReason: \(failureReason)"
        }
        if let helpAnchor {
            body += ",\n\thelpAnchor: \(helpAnchor)"
        }
        if let recoverySuggestion {
            body += ",\n\trecoverySuggestion: \(recoverySuggestion)"
        }
        return "AnyError {\n\(body)\n}"
    }
}

// MARK: - Foundation / FoundationEssentials

#if !Embedded
    #if canImport(FoundationEssentials) && !FullFoundation
        import FoundationEssentials
    #else
        import Foundation
    #endif

    extension AnyError: LocalizedError {
        /// The stored ``localizedDescription``, surfaced as the `LocalizedError` error description.
        ///
        /// > Important: This conformance is required for erasure to work correctly. `Error.localizedDescription` is a
        /// > statically-dispatched extension property, so reading it through an `any Error` existential bypasses the
        /// > stored ``localizedDescription`` and bridges to `NSError` instead. For a type that does not conform to
        /// > `LocalizedError`, that bridge returns a generic "The operation couldn't be completed…" string.
        /// > Implementing `errorDescription` sends the bridge back to the stored ``localizedDescription`` so it
        /// > survives erasure to `any Error`. Both `Foundation` and `FoundationEssentials` provide `LocalizedError`,
        /// > so this works wherever either is available. The other `LocalizedError` members need no implementation:
        /// > the stored ``failureReason``, ``helpAnchor``, and ``recoverySuggestion`` properties satisfy them
        /// > directly.
        @inlinable
        public var errorDescription: String? {
            localizedDescription
        }
    }
#endif

#if !Embedded
    extension AnyError {
        /// Erases any error into an ``AnyError``, bridging through `NSError` to recover ``code`` and ``domain``.
        ///
        /// If `error` is already an ``AnyError`` it is returned unchanged, and a ``CustomAnyError`` is mapped via
        /// ``init(custom:)``. Anything else is bridged to `NSError` to derive its ``code`` and ``domain``. Its
        /// description comes from `LocalizedError` when the error conforms to it, otherwise from `String(describing:)`
        /// so the original error's contents are preserved; other localized metadata is copied from `LocalizedError`
        /// when available.
        ///
        /// > Note: Errors that are neither ``AnyError`` nor ``CustomAnyError`` cannot carry a ``code``/``domain``
        /// > without `NSError`, so those are derived from the error's dynamic type and ``code`` defaults to `0`.
        ///
        /// - Parameter error: The error to erase.
        @inlinable
        public init(unknown error: some Error) {
            if let anyError = error as? AnyError {
                self = anyError
            } else if let customAnyError = error as? CustomAnyError {
                self.init(custom: customAnyError)
            } else {
                // Re-box the generic `some Error` as `any Error` before inspecting it. This looks
                // redundant but is not: `Error` self-conforms, so in this generic context `error as NSError`
                // and `type(of: error)` would act on the static `some Error` rather than the dynamic error.
                // Widening to `any Error` first makes the `as NSError` bridge below legal and gives
                // `type(of:)` the real dynamic type.
                let swiftError = error as any Error
                let type = type(of: swiftError)
                let localizedError = error as? any LocalizedError
                #if FullFoundation || canImport(Darwin)
                    let nsError = swiftError as NSError
                    if type is NSError.Type {
                        self.init(nsError: nsError)
                    } else {
                        self.init(
                            localizedDescription: localizedError?.errorDescription ?? String(describing: error),
                            originatingTypeName: String(reflecting: type),
                            code: nsError.code,
                            domain: nsError.domain,
                            failureReason: localizedError?.failureReason,
                            helpAnchor: localizedError?.helpAnchor,
                            recoverySuggestion: localizedError?.recoverySuggestion,
                        )
                    }
                #else
                    self.init(
                        localizedDescription: localizedError?.errorDescription ?? String(describing: error),
                        originatingTypeName: String(reflecting: type),
                        code: 0,
                        domain: String(reflecting: type),
                        failureReason: localizedError?.failureReason,
                        helpAnchor: localizedError?.helpAnchor,
                        recoverySuggestion: localizedError?.recoverySuggestion,
                    )
                #endif
            }
        }
    }

    #if FullFoundation || canImport(Darwin)
        extension AnyError {
            /// Creates an error from an `NSError`, copying its ``code``, ``domain``, and localized metadata.
            ///
            /// If the `NSError` was produced by bridging a ``CustomAnyError`` (see ``original(from:)``), the original
            /// ``AnyError`` is recovered instead of rebuilding it from the `NSError` fields.
            ///
            /// - Parameter error: The `NSError` to erase into an ``AnyError``.
            @inlinable
            public init(nsError error: NSError) {
                if let originalError = error.originalError {
                    self = originalError
                } else {
                    self.init(
                        localizedDescription: error.localizedDescription,
                        originatingTypeName: "NSError",
                        code: error.code,
                        domain: error.domain,
                        failureReason: error.localizedFailureReason,
                        helpAnchor: error.helpAnchor,
                        recoverySuggestion: error.localizedRecoverySuggestion,
                    )
                }
            }

            /// The original ``AnyError`` stashed in an `NSError`'s `userInfo`, if this error originated from a
            /// ``CustomAnyError``.
            ///
            /// - Parameter nsError: An `NSError` that may have been produced by bridging a ``CustomAnyError``.
            /// - Returns: The recovered ``AnyError``, or `nil` if `nsError` did not carry one.
            @inlinable
            public static func original(from nsError: NSError) -> Self? {
                nsError.originalError
            }
        }
    #endif
#endif
