# Feature compatibility matrix

"Gboard" column is **[Unverified-public]**: no Gboard artifact was supplied (see reverse-engineering-findings.md), so *no row below is a verified match*. "Exact match" is therefore never claimed.
Status: **Implemented** (coded; **not built or run** in this Linux environment) · **Approximation** · **Unsupported** (iOS) · **Not implemented** (feasible, deferred).

| Feature | Status | Notes |
|---|---|---|
| QWERTY + number row, shift, caps lock | Implemented (approximation of common behaviour) | unit-tested logic |
| Backspace + hold-to-repeat | Implemented | fixed 0.07 s repeat; no acceleration |
| Long-press alternates popover | Implemented | accents per language; slide to choose |
| Numbers / symbols pages | Implemented | number panel follows the layout supplied by the user (screenshot): 1–0 · `@ # ₹ _ & - + ( ) /` · `=\< * " ' : ; ! ? ⌫` · ABC (round) , language-space . enter (light-accent, dark arrow). Second page (`=\<`) is our own symbol set |
| Layouts: EN, ES, DE QWERTZ, FR AZERTY | Implemented | layouts only; no dictionaries |
| Themes light/dark/system + accent | Implemented | original palettes |
| Key height setting (70–140%), landscape sizing | Implemented | |
| Double-space full stop (toggle) | Implemented | fixed rule, own setting |
| Auto punctuation (toggle) | Implemented | space-before/after rules, own setting |
| Autocapitalisation | Implemented | |
| Flick-down hinted symbols | Implemented | toggle in app |
| One-handed mode | Implemented | left/right, 80% width |
| Long-press space trackpad | Implemented | horizontal only |
| Suggestions / autocorrect / next-word / personal dictionary | **Intentionally removed** | per request: no prediction of any kind |
| Space-bar cursor drag | Implemented | `adjustTextPosition`; one-dimensional |
| Emoji picker with recents | Approximation | ~350 emoji, no skin tones/search/stickers; system emoji key unavailable to 3rd-party |
| Haptics | Implemented | requires Full Access |
| Shift-swipe to type uppercase | Implemented | press ⇧, slide to a letter, release |
| Swipe ⌫ left to delete words | Implemented | one word per 40 pt |
| Hide-keyboard key | Implemented | `dismissKeyboard()`; iOS may ignore it in some hosts |
| Swipe (glide) typing | Not implemented | needs a word dictionary to decode paths — conflicts with the no-prediction decision |
| Voice typing | Unsupported | extensions cannot use the microphone |
| Clipboard history/monitoring | Unsupported | arbitrary monitoring not allowed; explicit paste button not built |
| Translate / network features | Not implemented | would need approved external service; none added |
| Text-selection, cut/copy via keys | Unsupported | proxy cannot read/set selection |
| One-handed / floating / resizable modes | Not implemented | height scale only |
| Multilingual simultaneous typing | Not implemented | one layout at a time |
