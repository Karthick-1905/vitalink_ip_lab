# Property implementation follow-up

This source and functional-test pass compares the runtime-property implementation with the original plan. It does not establish production rollout or hospital acceptance.

## Corrections

- Patient page scaffolds still passed literal headings for Dashboard, Update INR, Dosage Calendar, Dosage Management, Health Reports, My Records and My Profile. They now use property keys. Doctor patient-report headings use a template with a required patientName placeholder. Short Reports/Profile tab titles also resolve through properties.
- Flutter now stores the published ETag with its cached snapshot and issues conditional requests. HTTP 304 retains the current configuration. Backend CORS exposes ETag and permits If-None-Match for browser clients.
- A forced publication refresh no longer shares an older in-flight request. It waits for that request and fetches again.
- Uploaded branding references are checked against BrandAsset storage before saving or publishing, preventing missing images from becoming accepted configuration.

## Plan coverage and limits

| Original requirement | Source-backed state |
| --- | --- |
| Central property catalogue and source inventory | Implemented; generated JSON/Dart copies and consumer-key validation |
| Persistent draft, publication, history and rollback | Implemented in MongoDB, with version-conditioned writes and bounded history |
| Public pre-login branding with protected editing | Implemented; existing global administrator capabilities govern mutations |
| Bundled defaults, cache, atomic snapshot validation | Implemented; invalid data retains working configuration |
| Startup/resume refresh and conditional requests | Implemented; refresh interval remains fixed at five minutes, rather than remotely configurable |
| Patient, doctor, admin and authentication presentation | Broad migration implemented; page-heading gaps corrected here. This is not a claim that every literal is remotely editable |
| Logo upload, preview and fallback | Implemented; preview covers current draft branding, not a simulation of every application screen |
| Notification templates | Routine in-app/server templates implemented. Provider-managed SMS and authenticator issuer settings remain separate |
| Hospital overrides | Not implemented; current configuration and cache are global, so no tenant cache is introduced |
| Locale and typography controls | Not implemented; text catalogue and supported brand colors are configurable |
| Error-code localization | Partial; existing client display messages use properties, but no complete new backend error-code/localization contract is claimed |
| Native launcher, splash and store metadata | Outside runtime configuration; needs a platform release |
| Live rollout and installed-device acceptance | Unverified; local tests are separate from deployment evidence |

Remote configuration changes supported presentation values, not route identifiers, authorization, clinical algorithms or application code. New consumers still require a client release. Unreferenced branding-image cleanup and deployment-specific backup recovery remain operational follow-ups.

The optional CodeRabbit CLI review could not run on this Windows host: its installer rejected the operating system, and the configured WSL entry point had no /bin/bash. Functional regression checks and source evidence must not be attributed to CodeRabbit.
