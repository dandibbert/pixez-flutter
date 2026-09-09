# Novel TTS pronunciation analyzer benchmark

Host: Cursor Cloud Agent VM, Linux x86_64  
Flutter 3.47.1 / Dart 3.13.1

## Decision

**Production analyzer: `LexiconJapaneseAnalyzer` (capability `lexicon-pos`).**

It is backed by `japanese_lexicon_data.dart`, generated from mecab-ipadic
2.7.0-20070801 by `tool/generate_japanese_lexicon.dart`. `kuromoji` is not a
dependency; `BoundaryOnlyJapaneseAnalyzer` stays in the tree only as the
degraded path the worker falls back to when the analyzer throws.

## Why not kuromoji (Phase 0, 2026-08-30)

| Gate | Threshold | kuromoji 1.0.5 result |
|---|---:|---|
| Package on disk | (informational) | **23 MB** under `~/.pub-cache/hosted/pub.dev/kuromoji-1.0.5`, mostly base64 `*.dat.dart` dictionaries (`tid_pos.dat.dart` 7.9 MB, `base.dat.dart` 5.3 MB, …) |
| Cold init | ≤ 1.2 s, off UI isolate | `TokenizerBuilder().build()` **did not finish in 658 s** and was killed. Fails by two orders of magnitude. |
| Warm 500-character p95 | ≤ 20 ms | Not reached; the tokenizer never became ready. |
| Offset trust | must map to UTF-16 | Splits on `[、。]` and reports `word_position` as the last-token position plus an in-sentence `startPos`. Offsets reset across sentences and are not source UTF-16 ranges. |

The plan forbids shipping kuromoji until every hard gate passes, and forbids
Sudachi/MeCab/Rust bridges as a fallback. What it does allow is a lexicon
derived from IPADIC, which is what ships.

## Lexicon analyzer measurements

Reproduce with `flutter test test/novel_tts_pronunciation_test.dart` for
behaviour; the numbers below come from an in-process harness on this VM
(1000 timed iterations after 200 warm-up iterations).

| Gate | Threshold | `LexiconJapaneseAnalyzer` result |
|---|---:|---|
| Cold init | ≤ 1.2 s | **21 ms** to build the trie (9830 stems, 1283 fixed words) |
| `warmUp()` once built | — | 92 µs |
| Warm 500-character p95 | ≤ 20 ms | **0.072 ms** (p50 0.052 ms, p99 0.085 ms) |
| Extra RSS | ≤ 80 MB | **+6 MiB** for the built trie |
| Generated source | (informational) | **115.3 KiB** of Dart const strings, no asset and no runtime download |
| Android arm64 release APK increment | ≤ 30 MB | PENDING-APK-INCREMENT (see below) |
| Offset trust | must map to UTF-16 | Tokens carry source UTF-16 `start`/`end`; `MorphologyOffsetMapper` rejects any token that does not land on a scalar boundary inside the region |

The trie is built lazily behind `JapaneseInflectionLexicon.shared` on the first
alias candidate, so a reader that never configures a name alias never pays for
it, and app startup never touches it.

### Android release size

Two `flutter build apk --release --target-platform android-arm64` runs on this
VM, one at `HEAD` and one with `japaneseInflectionClasses` and
`japaneseFixedWords` emptied:

| Build | `app-release.apk` |
|---|---:|
| With the lexicon | PENDING-APK-WITH |
| Empty lexicon | PENDING-APK-WITHOUT |

## Accuracy

`test/novel_tts_pronunciation_test.dart` holds the behavioural matrix: the
`悟` set from the plan, plus a homograph regression suite over 恵 愛 光 望 歩
司 静 実 優 薫 誠 翼 楼 葵, and the degraded-path cases.

On an eight-line novel excerpt with four single-kanji aliases (悟 恵 傑 棘),
23 candidates resolve to 17 applied and 6 kept, and all 6 kept spans are real
non-name uses: 悟った, 悟り, 恵まれた, 知恵, 悟らない, 悟れば.

## Capability strings

- `lexicon-pos` — IPADIC-derived part of speech, dictionary form, conjugation
  type. What the settings UI reports.
- `boundary-only` — script runs only, no part of speech.
- `unavailable` — the analyzer threw or timed out. Aliases fall back to the
  honorific, quote, and okurigana lists and skip anything they cannot justify.
