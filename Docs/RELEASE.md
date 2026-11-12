# Release

1. Run package tests and the Xcode Debug and Release builds.
2. Configure an Apple Developer Team and a unique bundle identifier.
3. Enable hardened runtime and sign with Developer ID Application.
4. Archive, export, submit the ZIP or DMG with `notarytool`, and staple the ticket.
5. Verify Gatekeeper on a separate Mac and manually exercise missing-tool and denied-permission states.

No signing or notarization is claimed for the included artifact; credentials were not supplied. The committed project disables signing for reproducible local builds.

