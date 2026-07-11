// CustomAnyErrorTests.swift
// AnyError
//
// Copyright MFB Technologies, Inc. All rights reserved.
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

// These tests exercise Foundation / `NSError` / reflection APIs that are gated out of the Embedded build,
// so the whole suite is compiled only when the Embedded trait is disabled.
#if !Embedded
    import AnyError
    #if canImport(FoundationEssentials) && !FullFoundation
        import FoundationEssentials
    #else
        import Foundation
    #endif
    import Testing

    private enum TestError: Error, CustomAnyError {
        case errorA
        case errorB

        var code: Int {
            switch self {
            case .errorA:
                10
            case .errorB:
                20
            }
        }

        var domain: String {
            Self.defaultDomain
        }

        static var defaultDomain: String {
            "TestError"
        }

        var localizedDescription: String {
            switch self {
            case .errorA:
                "errorA"
            case .errorB:
                "errorB"
            }
        }

        var originatingTypeName: String {
            "TestError"
        }
    }

    /// Relies on both the default `defaultDomain` and the default `domain` (which forwards to it).
    private enum TestErrorWithImplicitDefaultDomain: Error, CustomAnyError {
        case errorA
        case errorB

        var code: Int {
            switch self {
            case .errorA:
                10
            case .errorB:
                20
            }
        }

        var localizedDescription: String {
            switch self {
            case .errorA:
                "errorA"
            case .errorB:
                "errorB"
            }
        }

        var originatingTypeName: String {
            "TestErrorWithImplicitDefaultDomain"
        }
    }

    private struct TestError_Struct: CustomAnyError {
        let code: Int
        let description: String

        static var defaultDomain: String {
            "TestError_Struct"
        }

        var domain: String {
            Self.defaultDomain
        }

        static let errorA = Self(code: 10, description: "a")
        static let errorB = Self(code: 20, description: "b")

        var localizedDescription: String {
            description
        }

        var originatingTypeName: String {
            "TestError_Struct"
        }
    }

    private enum TestErrorWithDefaultOriginatingTypeName: Error, CustomAnyError {
        case errorA

        var code: Int {
            10
        }

        var domain: String {
            Self.defaultDomain
        }

        var localizedDescription: String {
            "errorA"
        }
    }

    private struct LocalizedCustomError: CustomAnyError, LocalizedError {
        var code: Int {
            7
        }

        static var defaultDomain: String {
            "LocalizedCustomError"
        }

        var domain: String {
            Self.defaultDomain
        }

        var localizedDescription: String {
            "custom localized description"
        }

        var originatingTypeName: String {
            "LocalizedCustomError"
        }

        var errorDescription: String? {
            "custom localized description"
        }

        var failureReason: String? {
            "custom failure reason"
        }

        var helpAnchor: String? {
            "custom help anchor"
        }

        var recoverySuggestion: String? {
            "custom recovery suggestion"
        }
    }

    struct CustomAnyErrorTests {
        @Test
        func `init any error test error`() {
            let errorA = TestError.errorA
            let anyError = AnyError(custom: errorA)

            #expect(anyError.code == 10)
            #expect(anyError.domain == "TestError")
            #expect(anyError.localizedDescription == "errorA")
            #expect(anyError.originatingTypeName == "TestError")
        }

        @Test
        func `init any error test error with implicit default domain`() {
            let errorA = TestErrorWithImplicitDefaultDomain.errorA
            let anyError = AnyError(custom: errorA)

            #expect(anyError.code == 10)
            #expect(anyError.domain == "TestErrorWithImplicitDefaultDomain")
            #expect(anyError.localizedDescription == "errorA")
            #expect(anyError.originatingTypeName == "TestErrorWithImplicitDefaultDomain")
        }

        @Test
        func `init any error test error struct`() {
            let errorA = TestError_Struct.errorA
            let anyError = AnyError(custom: errorA)

            #expect(anyError.code == 10)
            #expect(anyError.domain == "TestError_Struct")
            #expect(anyError.localizedDescription == "a")
            #expect(anyError.originatingTypeName == "TestError_Struct")
        }

        @Test
        func `init any error via error`() {
            let errorA = TestError.errorA as any Error
            let anyError = AnyError(unknown: errorA)

            #expect(anyError.code == 10)
            #expect(anyError.domain == "TestError")
            #expect(anyError.localizedDescription == "errorA")
            #expect(anyError.originatingTypeName == "TestError")
        }

        @Test
        func `init any error uses default originating type name`() {
            let anyError = AnyError(custom: TestErrorWithDefaultOriginatingTypeName.errorA)

            #expect(anyError.code == 10)
            #expect(anyError.domain == "TestErrorWithDefaultOriginatingTypeName")
            #expect(anyError.localizedDescription == "errorA")
            #expect(anyError.originatingTypeName.hasSuffix("TestErrorWithDefaultOriginatingTypeName"))
        }

        @Test
        func `init custom captures localized error metadata`() {
            let anyError = AnyError(custom: LocalizedCustomError())

            #expect(anyError.localizedDescription == "custom localized description")
            #expect(anyError.failureReason == "custom failure reason")
            #expect(anyError.helpAnchor == "custom help anchor")
            #expect(anyError.recoverySuggestion == "custom recovery suggestion")
        }
    }

    #if FullFoundation || canImport(Darwin)
        extension CustomAnyErrorTests {
            @Test
            func `init any error via NS error`() {
                let errorA = TestError.errorA as NSError
                let anyError = AnyError(nsError: errorA)

                #expect(anyError.code == 10)
                #expect(anyError.domain == "TestError")
                #expect(anyError.localizedDescription == "errorA")
                #expect(anyError.originatingTypeName == "TestError")
            }

            @Test
            func `init any error with implicit default domain via NS error`() {
                let errorA = TestErrorWithImplicitDefaultDomain.errorA as NSError
                let anyError = AnyError(nsError: errorA)

                #expect(anyError.code == 10)
                #expect(anyError.domain == "TestErrorWithImplicitDefaultDomain")
                #expect(anyError.localizedDescription == "errorA")
                #expect(anyError.originatingTypeName == "TestErrorWithImplicitDefaultDomain")
            }

            @Test
            func `init any error via error and NS error`() {
                let _errorA = TestError.errorA as any Error
                let errorA = _errorA as NSError
                let anyError = AnyError(nsError: errorA)

                #expect(anyError.code == 10)
                #expect(anyError.domain == "TestError")
                #expect(anyError.localizedDescription == "errorA")
                #expect(anyError.originatingTypeName == "TestError")
            }

            @Test
            func `init any error with implicit default domain via error and NS error`() {
                let _errorA = TestErrorWithImplicitDefaultDomain.errorA as any Error
                let errorA = _errorA as NSError
                let anyError = AnyError(nsError: errorA)

                #expect(anyError.code == 10)
                #expect(anyError.domain == "TestErrorWithImplicitDefaultDomain")
                #expect(anyError.localizedDescription == "errorA")
                #expect(anyError.originatingTypeName == "TestErrorWithImplicitDefaultDomain")
            }

            @Test
            func `original from ns error recovers custom any error`() {
                let nsError = TestError.errorA as NSError
                let recovered = AnyError.original(from: nsError)

                #expect(recovered == AnyError(custom: TestError.errorA))
            }

            @Test
            func `original from plain ns error is nil`() {
                let nsError = NSError(domain: "CustomAnyErrorTests.Plain", code: 1)

                #expect(AnyError.original(from: nsError) == nil)
            }

            @Test
            func `custom any error round trips through NSError via init unknown`() {
                // `errorUserInfo` stashes the original so that a CustomAnyError erased to AnyError, bridged
                // to NSError, and re-erased with init(unknown:) comes back intact.
                let original = AnyError(custom: TestError.errorA)
                let nsError = TestError.errorA as NSError
                let recovered = AnyError(unknown: nsError as any Error)

                #expect(recovered == original)
            }
        }
    #endif
#endif
