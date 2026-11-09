# Mobile release builds — security checklist

## 1. Signing (Android)
Release builds **fail on purpose** without a real key (never debug-signed).

```bash
keytool -genkey -v -keystore ~/zaad-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Create `apps/mobile/android/key.properties` (git-ignored, never commit, store in the team password manager):
```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/absolute/path/zaad-upload.jks
```
Enrol in Google Play App Signing; this is the *upload* key.

## 2. Build
```bash
API_BASE_URL=https://<api-domain>/api/v1 apps/mobile/scripts/build-release.sh appbundle   # Android
API_BASE_URL=https://<api-domain>/api/v1 apps/mobile/scripts/build-release.sh ipa         # iOS (on macOS)
```
This enables Dart obfuscation (`--obfuscate --split-debug-info`). Android R8 shrinking/obfuscation is on for release.
Keep `build/symbols/<version>` privately to read crash stack traces.

The app refuses to start if a release API build points at a non-HTTPS URL, and demo data / demo tools are
never enabled unless explicitly requested with `--dart-define=DATA_SOURCE=demo`.

## 3. What the app does to protect data
| Area | Android | iOS |
|---|---|---|
| Tokens at rest | Encrypted, key in Android Keystore (`flutter_secure_storage`) | Keychain, `unlocked_this_device` (not restorable to another device) |
| Backups | `allowBackup=false` + data-extraction rules exclude everything | Keychain item is device-only |
| Cleartext HTTP | `usesCleartextTraffic=false` | ATS default (HTTPS only) |
| App-switcher snapshot | Hidden (Android 13+) | Covered with a brand-colour view |
| Screenshots / recording | Blocked on invoice details (`FLAG_SECURE`) | Not blockable by apps on iOS |
| Permissions | `INTERNET`, `USE_BIOMETRIC` only | Face ID usage description only |

## 4. Not yet done (tracked)
- **Certificate pinning** — add once the production API domain and certificate are known. Pin the SPKI of the
  issuing CA/intermediate **plus a backup pin**, and plan rotation; pinning a single leaf certificate bricks the
  app at renewal.
- Biometric-bound token (token only readable after biometric) — current biometric unlock is a UI gate on an
  encrypted token.
- Root/jailbreak detection — deliberately not in MVP (bypassable; server enforces all rules). Revisit only as a
  warning, never a hard block at the pharmacy counter.
