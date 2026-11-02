# Signing files

Encrypted with GPG (AES-256). The password is the `SIGNING_PASSPHRASE` repository secret,
which the TestFlight workflow uses to unlock them on the build machine.

- `dist_key.pem.gpg` — private key for the Apple Distribution certificate
- `distribution.cer.gpg` — the Apple Distribution certificate
- `profile.mobileprovision.gpg` — App Store profile with the CarPlay Audio entitlement
- `AuthKey.p8.gpg` — App Store Connect API key used to upload builds
- `asc.env` — the API key's Key ID and Issuer ID (not secret)
