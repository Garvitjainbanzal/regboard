# Gboard (real) vs RegBoard

## Artifact
`com.google.android.inputmethod.latin_18.5.4.993608717-release-arm64-v8a-176049702_…apkmirror.com.apkm` (sha256 `c698f6ad…1f283`), an APKM bundle: `base.apk` (89 MB) + 3 dpi splits + `split_dictation_feature_split.apk`. Package `com.google.android.inputmethod.latin`, v18.5.4, minSdk 32, targetSdk 37, 84 UI languages. Extracted read-only to the session scratchpad; tools: `unzip`, `aapt2 dump badging|xmltree|strings|resources` (Android SDK build-tools 36), `strings`.

## Evidence level
**Verified** = read directly from manifest / resource strings. A string's presence proves the feature or setting *exists in the app*; it does not prove how it behaves. **Not extracted**: key layouts/dimensions/themes (4,564 XML resources, names obfuscated — `0_resource_name_obfuscated`; not decoded), prediction/glide model internals (native `libintegrated_shared_object.so`, 35 MB, and dictionaries delivered at runtime as downloadable "superpacks", not in the APK), runtime behaviour (never executed).

## Verified architecture
- IME service `com.android.inputmethod.latin.LatinIME` (`BIND_INPUT_METHOD`, direct-boot aware); also a spell-checker service (`AndroidSpellCheckerService`), a clipboard ContentProvider, and an `INJECT_KEY_EVENTS` permission (system-only; N/A to iOS).
- Native ML/engine libs: `libintegrated_shared_object.so`, `libgboard_pipeline_jni`, `libgrammar-checker_jni`, `libexpressive_concepts_model_less_predictor_jni_native`, TFLite/EdgeTPU hooks; federated-learning/training-cache services (on-device personalization with optional Google upload: "Share usage statistics", "Improve for everyone").
- Heavy Google-network features: Translate, Proofread, Writing tools, Smart replies, Emoji Kitchen/stickers/GIFs, voice typing with AICore (`com.google.android.apps.aicore.service.BIND_SERVICE`), contacts, camera (sign-to-text/scan), microphone.
- Permissions include READ_CONTACTS, INTERNET, RECORD_AUDIO, CAMERA, READ_USER_DICTIONARY/WRITE_USER_DICTIONARY, VIBRATE.

## Verified user-facing settings (from English strings)
Glide typing (glide trail, dynamic suggestion preview, auto-commit) · Glide delete ("delete words by gliding left from Delete") · Glide cursor control / long-press space for trackpad · One-handed, Floating, Split layouts · Keyboard height ratio (configurable, 0.5–2.0 range stated in flag description; separate portrait/landscape, foldable) · Number row (+ "for passwords") · Flick keys (pull down for hinted symbol) · Long-press numbers/symbols/diacritics · Key pop-up preview · Vibrate on keypress (+ strength), key-tap sound + volume · Auto-capitalisation · Auto-correction (levels: words only / words and sentences; **undo on backspace**) · Double-space period · Auto-space after punctuation / after suggestions · Next-word suggestions · Multilingual typing (limited number of languages) · Personal dictionary (+ work dictionary), contacts suggestions, offensive-word blocking · Clear learned words/data · Smart compose · Clipboard (history duration, suggestions strip, screenshots) · Emoji row/toolbar, Emoji Kitchen, stickers, GIFs · Voice typing, Translate, Proofread, Writing tools, Rambler · Handwriting, physical-keyboard options, Morse, Chinese/Japanese/Korean-specific input · Themes/appearance, dark theme in battery saver, row-stagger/rounded keys · Toolbar · Shortcuts (comma/period/emoji/language-switch keys).

## Gap analysis (what we built vs verified Gboard)
| Area | Gboard (verified exists) | RegBoard | Gap / iOS limit |
|---|---|---|---|
| Glide typing + trail | yes | **no** | Feasible, large; not built |
| Glide delete (slide left on ⌫) | yes | **yes** | similar idea; ours deletes a word per 40 pt |
| Space-bar cursor swipe | yes (+ long-press trackpad) | swipe only | add long-press trackpad |
| Height setting | yes | **yes** (0.85–1.25 slider) | Gboard range wider |
| Number row toggle | yes | **yes** | |
| Flick key (pull down) for hinted symbol / number | yes | no (long-press only) | feasible |
| Long-press alternates/diacritics | yes | yes | |
| One-handed / floating / split | yes | **no** | one-handed feasible; floating/split limited by iOS keyboard frame |
| Key pop-up, haptics, sound | yes | yes | haptics need Full Access |
| Auto-correct + undo on backspace | yes, with sentence-level | word-level, simple | far weaker model |
| Next-word / multilingual | ML, many languages | ~40 bigrams, 4 layouts | model gap is the biggest |
| Personal dictionary, clear data | yes | yes | |
| Clipboard history | yes | no | iOS forbids background clipboard monitoring |
| Emoji + Kitchen/stickers/GIF | yes | basic emoji only | Kitchen/GIF need network + licensing |
| Voice typing | yes | no | extensions cannot use the mic |
| Translate/Proofread/Writing tools | yes (cloud/AICore) | no | needs approved service; against no-network policy |
| Themes | many, images | light/dark + 6 accents | |
| Telemetry / federated learning | yes (opt-in) | none by design | |
| Languages | 84 | 4 layouts | |

## Implications / suggested next steps
1. Add: long-press-space trackpad, flick-down hinted symbols, one-handed mode, ability to resize via drag.
2. Glide typing is the biggest missing gesture feature (local path-to-word matching over our dictionary).
3. Decoding the layout XML (e.g. via apktool/jadx with a mapping, or inspecting the compiled `res/xml` binaries) would give key counts/weights for pixel-closer layouts — not done yet.
4. Prediction quality cannot be matched from this APK: models/dictionaries are not shipped in it, and copying Google's would also be inappropriate.
