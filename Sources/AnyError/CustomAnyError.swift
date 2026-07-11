// CustomAnyError.swift
// AnyError
//
// Copyright MFB Technologies, Inc. All rights reserved.
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

#if !Embedded
    #if canImport(FoundationEssentials) && !FullFoundation
        import FoundationEssentials
    #else
        import Foundation
    #endif
#endif

#if (FullFoundation || canImport(Darwin)) && !Embedded
    /// Convenience protocol that maps a conforming error type to ``AnyError`` while preserving its metadata.
    ///
    /// Conform an error type to ``CustomAnyError`` to erase it with ``AnyError/init(custom:)`` without losing its
    /// ``code``, ``domain``, and description. Conformers are also recoverable after being cast to `NSError`, via
    /// ``AnyError/original(from:)``.
    ///
    /// ```swift
    /// enum ProfileError: CustomAnyError {
    ///     case notFound
    ///
    ///     var code: Int { 404 }
    ///     var localizedDescription: String { "Profile not found" }
    /// }
    ///
    /// let anyError = AnyError(custom: ProfileError.notFound)
    /// ```
    ///
    /// > Note: The `NSError` round-trip requires full `Foundation`. On platforms without `NSError` there is nothing
    /// > to bridge to, so the recovery via ``AnyError/original(from:)`` does not exist there; a conformer still maps
    /// > to ``AnyError`` the same way.
    public protocol CustomAnyError: Error, CustomNSError {
        /// An integer code categorizing the error, copied into ``AnyError/code``.
        var code: Int { get }

        /// The default value of ``domain``. Where `NSError` bridging is available it also satisfies
        /// `CustomNSError`'s `static var errorDomain: String` requirement.
        ///
        /// Defaults to `String(describing:)` of the conforming type unless implemented explicitly. That default is
        /// unavailable in Embedded Swift, where reflection is absent, so conformers must supply it there.
        static var defaultDomain: String { get }

        /// A string identifying the error's domain, copied into ``AnyError/domain``.
        ///
        /// Defaults to ``defaultDomain`` unless implemented explicitly.
        var domain: String { get }

        /// The human-readable description of the error, copied into ``AnyError/localizedDescription``.
        ///
        /// > Note: This is a requirement because `localizedDescription` is not a requirement of `Error` — it is
        /// > supplied by an `Error` extension. Without requiring it here, generic use of the protocol would resolve
        /// > to `Error`'s implementation instead of the conformer's value.
        var localizedDescription: String { get }

        /// The name of the conforming type, copied into ``AnyError/originatingTypeName``.
        ///
        /// Defaults to `String(reflecting:)` of the conforming type unless implemented explicitly. That default is
        /// unavailable in Embedded Swift, where reflection is absent, so conformers must supply it there.
        var originatingTypeName: String { get }
    }

    // MARK: - Default `CustomNSError` implementations

    extension CustomAnyError {
        /// Satisfies `CustomNSError` by exposing ``code`` as the `NSError` error code.
        @inlinable
        public var errorCode: Int {
            code
        }

        /// Satisfies `CustomNSError` by exposing ``defaultDomain`` as the `NSError` error domain.
        @inlinable
        public static var errorDomain: String {
            defaultDomain
        }

        /// Satisfies `CustomNSError`, stashing the erased ``AnyError`` in `userInfo` so it can be recovered later.
        ///
        /// > Important: This is what makes ``AnyError/original(from:)`` work. When a conformer is bridged to
        /// > `NSError`, the original error is preserved under a private `userInfo` key instead of being flattened
        /// > into the `NSError`'s own fields.
        @inlinable
        public var errorUserInfo: [String: Any] {
            [
                NSError.originalErrorKey: AnyError(custom: self),
            ]
        }
    }

    extension NSError {
        /// Private `userInfo` key under which ``CustomAnyError/errorUserInfo`` stashes the original ``AnyError``.
        @usableFromInline
        static var originalErrorKey: String {
            "CustomAnyError_originalError"
        }

        /// The original ``AnyError`` stashed in `userInfo` when a ``CustomAnyError`` was bridged to `NSError`.
        ///
        /// When a ``CustomAnyError`` conformer is thrown as `any Error` or `NSError`, recovering the original error
        /// while mapping it back to ``AnyError`` would otherwise be lossy. ``CustomAnyError/errorUserInfo`` stores
        /// the original here so it can be read back intact.
        @usableFromInline
        var originalError: AnyError? {
            userInfo[Self.originalErrorKey] as? AnyError
        }
    }
#else
    /// Convenience protocol that maps a conforming error type to ``AnyError`` while preserving its metadata.
    ///
    /// On platforms without full `Foundation` there is no `NSError`, so the `NSError` round-trip
    /// (`AnyError.original(from:)`) does not exist here. A conformer still maps to ``AnyError`` the same way as
    /// everywhere else.
    public protocol CustomAnyError: Error {
        /// An integer code categorizing the error, copied into ``AnyError/code``.
        var code: Int { get }

        /// The default value of ``domain``. Where `NSError` bridging is available it also satisfies
        /// `CustomNSError`'s `static var errorDomain: String` requirement.
        ///
        /// Defaults to `String(describing:)` of the conforming type unless implemented explicitly. That default is
        /// unavailable in Embedded Swift, where reflection is absent, so conformers must supply it there.
        static var defaultDomain: String { get }

        /// A string identifying the error's domain, copied into ``AnyError/domain``.
        ///
        /// Defaults to ``defaultDomain`` unless implemented explicitly.
        var domain: String { get }

        /// The human-readable description of the error, copied into ``AnyError/localizedDescription``.
        ///
        /// Required on every platform so ``AnyError/init(custom:)`` has a description to copy, even where `Error`
        /// does not provide `localizedDescription`.
        var localizedDescription: String { get }

        /// The name of the conforming type, copied into ``AnyError/originatingTypeName``.
        ///
        /// Defaults to `String(reflecting:)` of the conforming type unless implemented explicitly. That default is
        /// unavailable in Embedded Swift, where reflection is absent, so conformers must supply it there.
        var originatingTypeName: String { get }
    }
#endif

// MARK: - Default implementations

/// `domain` forwards to `defaultDomain` on every platform, so most conformers do not need to implement
/// it. It has no reflection dependency, so unlike the defaults below it is available in Embedded Swift.
extension CustomAnyError {
    /// Derives ``domain`` from ``defaultDomain``.
    ///
    /// Most conformers want ``AnyError/domain`` to match their error domain, so this forwards to
    /// ``defaultDomain`` by default. Implement ``domain`` explicitly only when the two should differ.
    @inlinable
    public var domain: String {
        Self.defaultDomain
    }
}

// `defaultDomain` and `originatingTypeName` derive from the type's name via reflection, which is
// unavailable in Embedded Swift. There they become plain protocol requirements each conformer supplies.
#if !Embedded
    extension CustomAnyError {
        /// Derives ``defaultDomain`` from the conforming type's name via `String(describing:)`.
        @inlinable
        public static var defaultDomain: String {
            String(describing: Self.self)
        }
    }

    extension CustomAnyError {
        /// Derives ``originatingTypeName`` from the conforming type via `String(reflecting:)`, yielding a fully
        /// qualified name like `ModuleName.TypeName`.
        @inlinable
        public var originatingTypeName: String {
            String(reflecting: Self.self)
        }
    }
#endif
