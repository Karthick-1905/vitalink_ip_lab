# Application properties

VitaLink reads public presentation properties from `GET /api/v1/app-properties`. The reviewed default catalogue is `frontend/assets/config/app_properties.json`. It includes screen headings, labels, validation/help text, branding, artwork references, supported brand colors, and routine notification templates. Internal routes, API keys, role identifiers, clinical calculations, secrets, and native launcher metadata remain application/deployment code.

Run `python scripts/properties/sync.py` after changing defaults. This writes the identical backend JSON copy and the generated Dart map. Run `python scripts/properties/sync.py --check` to detect drift and unknown static Dart references. Frontend CI runs the contract check. Property keys are stable identifiers; changing their displayed values must not rename routes or payload fields. New keys need an app release before older clients can use them.

## Administrator workflow

An Application Admin with `platform.system_config.read` opens **Platform Configuration**, then expands **Application properties**. Management additionally requires `platform.system_config.manage`. Hospital Admins and Auditors cannot edit global presentation properties.

1. Search by property name or current draft text. Results show 20 properties per page.
2. Edit text or color values. Image properties accept their bundled default, an HTTPS URL, or an uploaded PNG/JPEG. Uploads are limited to 512 KiB and 2048 pixels per side and are stored as separate public `BrandAsset` documents. Their references use `brand-asset:<sha256>`. Saving or publishing rejects a reference whose uploaded image is absent.
3. Inspect the draft branding preview. It shows both draft logos, application name, and primary color. Uploaded logos resolve through the same public asset endpoint used by the app, including a local HTTP backend. Failed preview downloads show an unavailable-image indicator. Screen text/layout and all supported device sizes still require acceptance checks.
4. Select **Save draft**. Saving replaces the full override map, limited to 256 KiB with at most 4000 characters per value; values equal to defaults are omitted. Unsaved local edits must be saved before publishing or restoring a revision. Reload asks before discarding local edits.
5. Select **Publish saved draft** and confirm. Users receive the published revision on their next configuration refresh.
6. Expand **Publication history** to restore a retained revision. Restore creates a new publication revision rather than rewriting history. The initial defaults are a rollback target after the first publication. Only the latest 20 publication entries are retained.

Edits use `expectedVersion`. A stale draft save, publication, or rollback returns HTTP 409, preserves server state, and requires reloading before retrying. Generic admin auditing records action/version metadata without copying property content or image bytes. Audit persistence follows the existing admin middleware's post-commit failure reporting contract.

All catalogue defaults and published properties are public. Drafts, history and actor identities are restricted to the management endpoint. Public image URLs can be fetched without signing in, including images uploaded for a draft. Use only artwork intended for public distribution. Private patient files keep their existing access controls and storage paths.

## Client branding

Use the existing Application properties editor for each client's backend deployment. Search for these keys, save the draft, then publish it:

| Property | Runtime use |
| --- | --- |
| `branding.appName` | Flutter application title and administrator navigation name |
| `asset.hospitalLogo` | Login and patient/doctor headers, administrator sidebar and mobile drawer, draft preview |
| `asset.instituteLogo` | Login and patient/doctor headers, draft preview |
| `theme.primary`, `theme.secondary`, `theme.accent` | Supported Flutter theme colors |

Upload a PNG/JPEG for either logo or supply an HTTPS image URL. Uploading alone does not publish the logo reference. The administrator preview uses unsaved draft values; the rest of the app uses published values. Published images keep their bounded layout and contain fit, and download/decode failures fall back to bundled artwork. To reset a logo, select **Use default**, save, and publish. Restoring an earlier publication also restores its image references.

Branding is global to the selected backend, including before login. All hospitals using that backend receive the same publication. Separate client deployments can publish different branding without rebuilding a client that already supports these keys and targets the intended API. Changing the bootstrap API address still uses the existing build-time configuration. Do not use this workflow to promise hospital-specific branding within one shared backend.

## Runtime behavior

Flutter starts with generated bundled defaults, then applies a compatible cached snapshot from SharedPreferences. Cache keys include the bootstrap API address and API path prefix. The network refresh runs in the background at startup; app resume triggers another attempt at most once every five minutes. Administrator publication forces a refresh in that app instance. There is no live push or continuous polling of properties.

Known properties are validated as one snapshot before application. Missing known keys use bundled defaults; unknown keys from a newer catalogue are ignored. Invalid schema versions, lower revisions, invalid types/colors/image references, and changed template placeholders leave the previous snapshot intact. Network/storage failures retain working values. Rebuilds through `AppPropertyScope` preserve existing route and form state. Descriptor lists used by navigation and onboarding are computed when read so labels can refresh.

Remote images fall back to bundled artwork on download/decode failure. Uploaded image URLs are immutable and content-addressed. The public configuration response carries an ETag based on the complete published snapshot and requires revalidation; image responses are cached for one year. The client persists the ETag alongside its last working snapshot and sends If-None-Match on refresh. A 304 preserves that snapshot without downloading the property map. Cross-origin clients can read ETag and preflight If-None-Match. A forced refresh after publication waits for any older request to finish, then starts a new request so it cannot reuse a pre-publication response. External image availability and cache headers remain the external host's responsibility.

Routine server notification templates use a fresh published snapshot per operation, with bundled wording if configuration cannot be read. Substitution occurs once and retains required placeholders. Already persisted notifications keep their original wording. Push continues to carry only a generic prompt and opaque notification ID, not in-app clinical details. Clinical eligibility, dosage values, permissions, and operational flags do not come from presentation properties. Authentication issuer strings and provider-managed SMS templates remain controlled by their integration configuration.

## Deployment and compatibility

Deploy the backend and its catalogue before releasing the updated Flutter client. No existing documents require a backfill; management lazily creates the singleton, while public reads return defaults without writing. The new collections use MongoDB's built-in unique `_id` index. Start with no overrides to retain the current appearance.

The first client release is required to add runtime configuration support. Subsequent changes to supported properties require publication only. New functionality, new property consumers, native launcher icons/names, native splash screens, and installed application metadata still require platform builds. Browser HTML metadata is outside the Flutter runtime property layer. Configuration is currently global; authenticated hospital overrides and public hospital selection are not implemented.

Brand assets are retained so old clients and rollback revisions remain usable. Automated cleanup of unreferenced uploads is not implemented. Monitor collection growth and storage backups; do not remove images referenced by published or retained revisions.

See [ADR-0016](../decisions/0016-runtime-presentation-properties.md), the [entity catalogue](../data/entities.md), and the [validation report](../reference/validation.md).

See the [implementation follow-up](../reference/property-implementation-audit.md) for comparison with the original plan and remaining scope.
