# Reverse-engineering findings

> **UPDATE (2026-10-27): a real Gboard bundle was supplied and analysed.** See [gboard-vs-regboard.md](gboard-vs-regboard.md) for the verified findings and gap analysis. The sections below describe the *first* APK supplied (the Uptodown store client), kept for the record.

## Headline finding: the supplied APK is not Gboard

| Item | Evidence |
|---|---|
| File | `uptodown-com.google.android.inputmethod.latin.apk` (sha256 `dc885921…2550`, matches REA `subject.digest`) |
| Package in manifest | `com.uptodown`, versionName 7.41 (code 741), minSdk 23, targetSdk 36 — `regboard.output` (`get_app_info`, `get_android_manifest`) |
| Real identity | The **Uptodown app-store client**. The filename is the *name of the app that was meant to be downloaded* (`com.google.android.inputmethod.latin` is Gboard's package id); the file actually saved is Uptodown's own installer/store app. |
| Components | 94 manifest components, all `com.uptodown.*` (store, TV UI, downloads, installers, ad SDKs) |
| Permissions | INTERNET, REQUEST_INSTALL_PACKAGES, QUERY_ALL_PACKAGES, MANAGE_EXTERNAL_STORAGE, RECORD_AUDIO, AD_ID … — none keyboard-related |
| Keyboard code | None. No `InputMethodService`, no `android.view.InputMethod` service entry, no `xml/method`, no keyboard layouts, dictionaries, or `.dict`/`.tflite` resources. `unzip -l` finds no entries matching latin/inputmethod/keyboard/dict. Native libs are `libuptodown-native`, `libutd-services-native`, androidx graphics/datastore only. |
| Stats | 13,961 classes, 2,169 resources (`regboard-classes.output`: `MainActivity` search returns only `com.uptodown.activities.MainActivity` and `TvMainActivity`) |

Artifacts reviewed (read fully; none modified):
- `/home/nhz/Downloads/regboard/regboard.output` — REA `inspect_android_package` (package info, manifest, 94 components)
- `/home/nhz/Downloads/regboard/regboard-classes.output` — REA `search_android_classes` for `MainActivity`
- the APK itself (listing and manifest strings only)

## Consequence for the checklist in the brief

| Topic | Status |
|---|---|
| Package information | **Verified** — but it is Uptodown's |
| Keyboard layouts / key dimensions | **Not present** in artifacts |
| Themes / appearance | **Not present** |
| Languages / locales | Not present (Uptodown has UI translations only; irrelevant) |
| Suggestions / autocorrect / personal dictionary | **Not present** |
| Swipe typing | **Not present** |
| Emoji / symbols / number layouts | **Not present** |
| Settings screens | Only Uptodown's |
| Haptics / sound | **Not present** |
| Clipboard / voice / translation | Not present (RECORD_AUDIO belongs to the store; not evidence of keyboard voice input) |

**Nothing about Gboard has been verified from these artifacts.** Every Gboard behaviour referenced elsewhere in this repo is therefore tagged:

- **[Unverified-public]** — common public knowledge of how Gboard behaves; *not* confirmed by any local artifact.
- **[Own design]** — original decision, no claim of parity.

## What is needed to do real reverse engineering
A real Gboard APK (package `com.google.android.inputmethod.latin`; usually an APKM/XAPK bundle with splits — the base APK alone lacks language/layout resources), then re-run the REA `inspect_android_package` and class/resource searches. Items worth mining: `res/xml/*keyboard*`, `InputMethodService` subclass, `method.xml`, dictionary/LM assets, theme resources. When one is supplied, the matrix in `feature-matrix.md` should be re-graded.

## Implementation implications
The iOS keyboard is built from (a) Apple's documented constraints, (b) generally known keyboard UX conventions, and (c) original design. No Google assets, strings, or code are used. The project name "RegBoard" is deliberately not "Gboard".
