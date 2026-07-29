# Play Store Release Checklist

This checklist complements the technical build documentation. It does not
replace review of current Google Play policies.

## Consumer-facing URLs

Configure these exact URLs in the Play Console and release materials:

- App landing page:
  <https://shagiz-technologies.github.io/tele-vault/>
- Privacy Policy:
  <https://shagiz-technologies.github.io/tele-vault/privacy-policy.html>
- Terms of Service:
  <https://shagiz-technologies.github.io/tele-vault/terms-of-service.html>
- Support:
  <https://shagiz-technologies.github.io/tele-vault/support.html>
- Data & Deletion:
  <https://shagiz-technologies.github.io/tele-vault/data-deletion.html>
- Security:
  <https://shagiz-technologies.github.io/tele-vault/security.html>

Before release, verify every URL returns HTTP 200 without authentication and
that the approved privacy contact has replaced
`PRIVACY_CONTACT_EMAIL_REQUIRED`.

## Policy and technical review

- Reconcile the Data Safety form with the current permissions, TDLib/Telegram
  data flow, local diagnostics, vault encryption boundary, and metadata backup
  behavior.
- Confirm normal non-vault uploads are described as not client-side encrypted
  by TeleVault.
- Review photo/video permissions against the target Android version and current
  selected-media policy.
- Verify the target SDK requirement and foreground data-sync declarations.
- Verify TDLib/libtdjson provenance, licenses, supported ABIs, checksums, and
  16 KB page-size compatibility.
- Run the complete Flutter test suite and physical Android smoke tests.
- Build the signed AAB only in the approved release environment. Never commit
  keystores, key properties, credentials, APKs, AABs, or signing output.

