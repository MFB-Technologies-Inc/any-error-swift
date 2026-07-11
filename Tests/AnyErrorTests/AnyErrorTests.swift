// AnyErrorTests.swift
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
    import Testing

    #if canImport(FoundationEssentials) && !FullFoundation
        import FoundationEssentials
    #else
        import Foundation
    #endif

    private struct SomeError: Error {
        var localizedDescription = "This is 'some' error"
    }

    private struct LocalizedOnlyError: LocalizedError {
        var errorDescription: String? {
            "Localized description"
        }

        var failureReason: String? {
            "Localized failure reason"
        }

        var helpAnchor: String? {
            "Localized help anchor"
        }

        var recoverySuggestion: String? {
            "Localized recovery suggestion"
        }
    }

    struct AnyErrorTests {
        @Test
        func `non custom any error originating type name`() {
            let error = SomeError()
            let anyError = AnyError(unknown: error as any Error)

            // `String(reflecting:)` of a file-private type is fully qualified but includes a context marker,
            // so assert on the stable parts rather than the exact spelling.
            #expect(anyError.originatingTypeName.contains("AnyErrorTests"))
            #expect(anyError.originatingTypeName.hasSuffix("SomeError"))
            // `SomeError` conforms to neither `LocalizedError` nor `CustomNSError`, so its description falls
            // back to `String(describing:)`. Unlike Foundation's generic bridged message, that keeps the
            // original error's contents on every platform.
            #expect(anyError.localizedDescription.contains("SomeError(localizedDescription:"))
            #expect(anyError.localizedDescription.contains("This is"))
            #expect(anyError.localizedDescription.contains("some"))
            #expect(anyError.localizedDescription.contains("error"))

            #expect(anyError.domain == anyError.originatingTypeName)
        }

        @Test
        func `init unknown passes through existing any error`() {
            let original = AnyError(
                localizedDescription: "Original localized description",
                originatingTypeName: "Original",
                code: 7,
                domain: "AnyErrorTests",
                failureReason: "Original failure reason",
                helpAnchor: "Original help anchor",
                recoverySuggestion: "Original recovery suggestion",
            )

            let anyError = AnyError(unknown: original as any Error)

            #expect(anyError == original)
        }

        @Test
        func `equatable and hashable`() {
            let anyError = AnyError(
                localizedDescription: "boom",
                originatingTypeName: "None",
                code: 1,
                domain: "AnyErrorTests",
                failureReason: nil,
                helpAnchor: nil,
                recoverySuggestion: nil,
            )
            let same = AnyError(
                localizedDescription: "boom",
                originatingTypeName: "None",
                code: 1,
                domain: "AnyErrorTests",
                failureReason: nil,
                helpAnchor: nil,
                recoverySuggestion: nil,
            )
            let different = AnyError(
                localizedDescription: "different",
                originatingTypeName: "None",
                code: 1,
                domain: "AnyErrorTests",
                failureReason: nil,
                helpAnchor: nil,
                recoverySuggestion: nil,
            )

            #expect(anyError == same)
            #expect(anyError != different)
            #expect(anyError.hashValue == same.hashValue)
            #expect(Set([anyError, same, different]).count == 2)
        }

        @Test
        func `description formats domain code and localized description`() {
            let anyError = AnyError(
                localizedDescription: "boom",
                originatingTypeName: "MyType",
                code: 42,
                domain: "MyDomain",
                failureReason: nil,
                helpAnchor: nil,
                recoverySuggestion: nil,
            )

            #expect(anyError.description == "MyDomain code=42: boom")
            #expect("\(anyError)" == "MyDomain code=42: boom")
        }

        @Test
        func `debug description includes all core fields`() {
            let anyError = AnyError(
                localizedDescription: "boom",
                originatingTypeName: "MyType",
                code: 42,
                domain: "MyDomain",
                failureReason: nil,
                helpAnchor: nil,
                recoverySuggestion: nil,
            )

            let expected = """
            AnyError {
            \tlocalizedDescription: boom,
            \toriginatingTypeName: MyType,
            \tcode: 42,
            \tdomain: MyDomain
            }
            """

            #expect(anyError.debugDescription == expected)
        }

        @Test
        func `debug description includes localized metadata when present`() {
            let anyError = AnyError(
                localizedDescription: "boom",
                originatingTypeName: "MyType",
                code: 42,
                domain: "MyDomain",
                failureReason: "why it failed",
                helpAnchor: "help anchor",
                recoverySuggestion: "try again",
            )

            let expected = """
            AnyError {
            \tlocalizedDescription: boom,
            \toriginatingTypeName: MyType,
            \tcode: 42,
            \tdomain: MyDomain,
            \tfailureReason: why it failed,
            \thelpAnchor: help anchor,
            \trecoverySuggestion: try again
            }
            """

            #expect(anyError.debugDescription == expected)
        }

        @Test
        func `init unknown accepts an uncast concrete error`() {
            // No `as any Error` here on purpose: this exercises the concrete-generic entry into
            // `init(unknown:)`, the path the internal re-box protects. It must behave exactly like
            // erasing the pre-widened existential.
            let anyError = AnyError(unknown: SomeError())

            #expect(anyError == AnyError(unknown: SomeError() as any Error))
            #expect(anyError.originatingTypeName.hasSuffix("SomeError"))
            #expect(anyError.localizedDescription.contains("SomeError(localizedDescription:"))
        }

        @Test
        func `init unknown captures localized error metadata`() {
            let anyError = AnyError(unknown: LocalizedOnlyError() as any Error)

            #expect(anyError.localizedDescription == "Localized description")
            #expect(anyError.failureReason == "Localized failure reason")
            #expect(anyError.helpAnchor == "Localized help anchor")
            #expect(anyError.recoverySuggestion == "Localized recovery suggestion")
            #expect(anyError.originatingTypeName.hasSuffix("LocalizedOnlyError"))
        }

        @Test
        func `init unknown captures localized error metadata from an uncast concrete error`() {
            let anyError = AnyError(unknown: LocalizedOnlyError())

            #expect(anyError == AnyError(unknown: LocalizedOnlyError() as any Error))
            #expect(anyError.localizedDescription == "Localized description")
            #expect(anyError.failureReason == "Localized failure reason")
            #expect(anyError.helpAnchor == "Localized help anchor")
            #expect(anyError.recoverySuggestion == "Localized recovery suggestion")
        }

        @Test
        func `localized error properties survive existential`() throws {
            let anyError = AnyError(
                localizedDescription: "Original localized description",
                originatingTypeName: "None",
                code: -1,
                domain: "AnyErrorTests",
                failureReason: "Original failure reason",
                helpAnchor: "Original help anchor",
                recoverySuggestion: "Original recovery suggestion",
            )

            let existential = anyError as any LocalizedError

            // `errorDescription` rather than `localizedDescription` here: the latter comes from an
            // `Error` extension that only full Foundation (or the Darwin overlay) provides, and this
            // test also runs on FoundationEssentials-only platforms. The full-Foundation bridge is
            // covered by `localized description survives existential` below.
            #expect(existential.errorDescription == anyError.localizedDescription)
            #expect(existential.failureReason == anyError.failureReason)
            #expect(existential.helpAnchor == anyError.helpAnchor)
            #expect(existential.recoverySuggestion == anyError.recoverySuggestion)

            let recovered = try #require(existential as? AnyError)

            #expect(recovered.localizedDescription == anyError.localizedDescription)
            #expect(recovered.failureReason == anyError.failureReason)
            #expect(recovered.helpAnchor == anyError.helpAnchor)
            #expect(recovered.recoverySuggestion == anyError.recoverySuggestion)
        }
    }

    #if FullFoundation
        extension AnyErrorTests {
            @Test
            func `localized description survives existential`() throws {
                let anyError = AnyError(
                    localizedDescription: "Original localized description",
                    originatingTypeName: "None",
                    code: -1,
                    domain: "AnyErrorTests",
                    failureReason: "Original failure reason",
                    helpAnchor: "Original help anchor",
                    recoverySuggestion: "Original recovery suggestion",
                )

                let existential = anyError as any Error

                // `Error.localizedDescription` bridges through NSError, so this pins that the bridge
                // lands on the stored description. The extension providing it requires full Foundation,
                // which is why this test is gated while its `errorDescription` sibling above is not.
                #expect(existential.localizedDescription == anyError.localizedDescription)

                let recovered = try #require(existential as? AnyError)

                #expect(recovered.localizedDescription == anyError.localizedDescription)
            }

            @Test
            func `init from actual NSError`() {
                let nsError = NSError(domain: "AnyErrorTests.NSErrorTest", code: -123_789)
                let anyError = AnyError(nsError: nsError)

                #expect(anyError.originatingTypeName == "NSError")
                // The localized description is Foundation's generated message, which is locale-dependent,
                // so assert on the stable fields rather than its exact text.
                #expect(anyError.domain == "AnyErrorTests.NSErrorTest")
                #expect(anyError.code == -123_789)
            }

            @Test
            func `init unknown routes a real NSError through the NSError branch`() {
                let nsError = NSError(domain: "AnyErrorTests.NSErrorTest", code: -123_789)
                let anyError = AnyError(unknown: nsError as any Error)

                #expect(anyError.originatingTypeName == "NSError")
                #expect(anyError.domain == "AnyErrorTests.NSErrorTest")
                #expect(anyError.code == -123_789)
            }

            @Test
            func `init unknown erases a Foundation URLError`() {
                let anyError = AnyError(unknown: URLError(.timedOut) as any Error)

                // `code`/`domain` are recovered from the error on every platform.
                #expect(anyError.code == URLError.Code.timedOut.rawValue)
                #expect(anyError.domain == URLError.errorDomain)

                #if canImport(Darwin)
                    // On Apple platforms URLError (a _BridgedStoredNSError) is represented as its backing
                    // NSError once boxed into `any Error`, so its dynamic type is an NSError subclass:
                    // init(unknown:) takes the NSError branch and reports "NSError", not the Swift type
                    // name. This pins the behavior the README documents.
                    #expect(anyError.originatingTypeName == "NSError")
                #else
                    // With swift-corelibs Foundation the boxed error keeps its Swift dynamic type
                    // `URLError`, so init(unknown:) does not take the NSError branch and the reflected
                    // Swift name is retained. URLError still bridges via `as NSError` — that is how the
                    // `code`/`domain` above are recovered on every platform.
                    #expect(anyError.originatingTypeName.hasSuffix("URLError"))
                #endif
            }

            @Test
            func `init unknown erases an uncast Foundation URLError`() {
                // No `as any Error` here on purpose — this is the concrete-generic call exactly as
                // the README writes it. It must match erasing the pre-widened existential, including
                // the platform-dependent NSError routing pinned above.
                let anyError = AnyError(unknown: URLError(.timedOut))

                #expect(anyError == AnyError(unknown: URLError(.timedOut) as any Error))
                #expect(anyError.code == URLError.Code.timedOut.rawValue)
                #expect(anyError.domain == URLError.errorDomain)
            }
        }
    #endif
#endif
