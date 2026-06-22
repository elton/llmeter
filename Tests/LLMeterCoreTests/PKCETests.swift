import Testing
import Foundation
@testable import LLMeterCore

struct PKCETests {
    // RFC 7636 Appendix B test vector.
    @Test func challengeMatchesRFC7636Vector() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        #expect(PKCE.challenge(forVerifier: verifier) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func verifierIsUrlSafeAndWithinLength() {
        let v = PKCE.makeVerifier()
        #expect(v.count >= 43 && v.count <= 128)
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        #expect(v.unicodeScalars.allSatisfy { allowed.contains($0) })
    }

    @Test func base64URLHasNoPaddingOrUnsafeChars() {
        let s = PKCE.base64URL(Data([0xfb, 0xff, 0xfe]))
        #expect(!s.contains("="))
        #expect(!s.contains("+"))
        #expect(!s.contains("/"))
    }
}
