# Release Signing Setup

The two release workflows — `.github/workflows/ios-testflight.yml` (monthly
TestFlight upload) and `.github/workflows/macos-release.yml` (monthly signed +
notarized DMG on GitHub Releases) — are gated on repository secrets: a
`check-secrets` job verifies the required secrets are configured and skips
everything otherwise, so the workflows are a no-op on forks or clones without
secrets. This document explains how to create the signing material and upload
it as secrets.

Prerequisites: a paid Apple Developer account, a Mac (for Keychain Access),
and admin access to the GitHub repository.

## Required secrets

| Secret | Contents | Used by |
|---|---|---|
| `IOS_DIST_CERT_P12_BASE64` | Apple Distribution certificate (.p12), base64 | ios-testflight |
| `IOS_DIST_CERT_PASSWORD` | password of the .p12 above | ios-testflight |
| `IOS_PROVISIONING_PROFILE_BASE64` | App Store provisioning profile (.mobileprovision), base64 | ios-testflight |
| `MACOS_CERT_P12_BASE64` | Developer ID Application certificate (.p12), base64 | macos-release |
| `MACOS_CERT_PASSWORD` | password of the .p12 above | macos-release |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API key ID (plain text) | both |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect API issuer ID (plain text) | both |
| `APP_STORE_CONNECT_API_KEY_BASE64` | App Store Connect API private key (.p8), base64 | both |

## 1. Create the signing certificates

Easiest via Xcode:

1. Xcode → **Settings → Accounts** → select your Apple ID → **Manage Certificates…**
2. Click **"+"** and create:
   - **Apple Distribution** (TestFlight/App Store)
   - **Developer ID Application** (notarized macOS DMG) — only the team's
     **Account Holder** can create this one

Without Xcode: Keychain Access → **Certificate Assistant → Request a
Certificate from a Certificate Authority…** → save the CSR to disk, then on
[developer.apple.com → Certificates](https://developer.apple.com/account/resources/certificates)
click "+", pick the certificate type, upload the CSR, download the `.cer` and
double-click it to install it into the keychain.

### Export as .p12

For each of the two certificates:

1. Open **Keychain Access** → "login" keychain → **My Certificates**
2. Find the certificate and verify it has the **private key nested under it**
   (expand arrow). Without the private key the .p12 is useless — this happens
   when installing a `.cer` created from a different Mac.
3. Right-click → **Export** → format **.p12** → choose a password (it becomes
   the `*_CERT_PASSWORD` secret)

## 2. Create the App Store provisioning profile (iOS only)

1. [developer.apple.com → Profiles](https://developer.apple.com/account/resources/profiles) → "+"
2. **Distribution → App Store Connect**
3. App ID: `it.robertodisanto.PicaSim` (create it under Identifiers first if
   it doesn't exist)
4. Certificate: select the **Apple Distribution certificate created above** —
   the profile is bound to specific certificates, so after renewing the
   certificate the profile must be regenerated too
5. Name it (e.g. "PicaSim App Store"), generate, download the `.mobileprovision`

Also make sure the app record exists in **App Store Connect → My Apps** with
that bundle ID — the TestFlight upload fails without it.

## 3. Create the App Store Connect API key

One key serves both workflows (TestFlight upload and notarization):

1. [App Store Connect](https://appstoreconnect.apple.com) → **Users and
   Access → Integrations → App Store Connect API → Team Keys** → "+"
2. Name it (e.g. "PicaSim CI"), role **App Manager**
3. Download `AuthKey_XXXXXXXXXX.p8` — **it can only be downloaded once**
4. Note the **Key ID** (key row) and **Issuer ID** (top of the page)

## 4. Upload the secrets to GitHub

With the [GitHub CLI](https://cli.github.com) (fastest, no copy-paste):

```bash
REPO=RobertoD91/PicaSim
gh secret set IOS_DIST_CERT_P12_BASE64        --repo $REPO --body "$(base64 -i apple_distribution.p12)"
gh secret set IOS_DIST_CERT_PASSWORD          --repo $REPO --body "your-p12-password"
gh secret set IOS_PROVISIONING_PROFILE_BASE64 --repo $REPO --body "$(base64 -i PicaSim_App_Store.mobileprovision)"
gh secret set MACOS_CERT_P12_BASE64           --repo $REPO --body "$(base64 -i developer_id.p12)"
gh secret set MACOS_CERT_PASSWORD             --repo $REPO --body "your-p12-password"
gh secret set APP_STORE_CONNECT_KEY_ID        --repo $REPO --body "A1B2C3D4E5"
gh secret set APP_STORE_CONNECT_ISSUER_ID     --repo $REPO --body "69a6de70-...."
gh secret set APP_STORE_CONNECT_API_KEY_BASE64 --repo $REPO --body "$(base64 -i AuthKey_A1B2C3D4E5.p8)"
```

Or manually: encode each file with `base64 -i file | pbcopy` and paste it under
repo **Settings → Secrets and variables → Actions → New repository secret**.

## 5. Verify

1. The scheduled (cron) runs only happen on the default branch, so the
   workflows must be merged into `main` first. Note that GitHub disables
   scheduled workflows on forks until manually enabled in the Actions tab,
   and suspends them after 60 days of repository inactivity.
2. **Actions → iOS TestFlight → Run workflow**: `check-secrets` must pass and
   trigger the build job (if everything is skipped, a secret is missing or
   empty).
3. Same for **macOS Signed Release**.

## Renewal

- **Apple Distribution**: valid 1 year. On renewal: new certificate → new
  .p12 → **regenerate the provisioning profile** → update
  `IOS_DIST_CERT_P12_BASE64`, `IOS_DIST_CERT_PASSWORD`,
  `IOS_PROVISIONING_PROFILE_BASE64`. The symptom of expiry is the archive
  step failing with "no signing certificate found".
- **Developer ID Application**: valid up to 5 years.
- **API key**: does not expire (until revoked).

## Security notes

The secrets in this setup can sign software as you (Developer ID) and upload
builds to your App Store account, so the workflows follow these rules:

- **No third-party actions in the release workflows.** Only `actions/*`
  (maintained by GitHub itself) are used. Anything else is done with tools
  preinstalled on the runners: the GitHub release is published with the `gh`
  CLI instead of a release action, and vcpkg is cloned directly from
  microsoft/vcpkg and pinned to the `builtin-baseline` commit from
  `vcpkg.json`. Third-party actions referenced by mutable tags (`@v2`) can be
  repointed to malicious code if the author's repo is compromised — with
  signing material on the runner, that class of risk is excluded entirely.
  The plain build workflows (e.g. `macos-build.yml`, `windows-build.yml`) do
  use third-party actions, but they carry no secrets and their artifacts are
  unsigned.
- **Secrets are only injected into the steps that reference them** via `env`;
  GitHub never passes repository secrets to workflow runs triggered by pull
  requests from forks.
- **Minimal token permissions**: the workflows run with `contents: read`;
  only the release-publishing job gets `contents: write`.
- **Ephemeral signing material**: certificates go into a temporary keychain
  with a random password, and a cleanup step (`if: always()`) deletes the
  keychain, the provisioning profile and the API key file at the end of the
  run. GitHub-hosted runners are themselves ephemeral VMs.

If a secret ever leaks: revoke the certificate on developer.apple.com and the
API key in App Store Connect, then recreate both and update the secrets.
