# Novel TTS pronunciation analyzer benchmark

Date: 2026-08-30  
Host: Cursor Cloud Agent VM, Linux x86_64  
Dart/Flutter: repository SDK constraint `>=3.11.5`

## Decision

**Production analyzer: `BoundaryOnlyJapaneseAnalyzer` (boundary-only).**  
`kuromoji 1.0.5` is not wired into the controller.

## Phase 0 measurements

| Gate | Threshold | kuromoji 1.0.5 result |
|---|---:|---|
| Package on disk | (informational) | **23 MB** under `~/.pub-cache/hosted/pub.dev/kuromoji-1.0.5`, mostly base64 `*.dat.dart` dictionaries (`tid_pos.dat.dart` 7.9 MB, `base.dat.dart` 5.3 MB, …) |
| Android release increment | ≤ 30 MB | Not measured as an APK. Embedding 23 MB of dictionary source already risks the gate after AOT; skipped. |
| iOS release increment | ≤ 30 MB | Not measured (no iOS toolchain on this VM). |
| Cold init on mid-range mobile | ≤ 1.2 s, off UI isolate | Linux `dart run` of `TokenizerBuilder().build()` **did not finish in 658 s** and was killed. Fails the gate by two orders of magnitude. |
| Warm 500-character p95 | ≤ 20 ms | Not reached; tokenizer never became ready. |
| Extra RSS | ≤ 80 MB | Not reached. |
| Android / iOS / macOS / Windows build | all pass | Not attempted; dependency is not in `pubspec.yaml`. |
| Offset trust | must map to UTF-16 | Source splits on `[、。]` then reports `word_position` as last-token position plus in-sentence `startPos`. Offsets reset across sentences and are not source UTF-16 ranges. |

## Why boundary-only

The plan forbids shipping kuromoji until every hard gate passes, and forbids Sudachi/MeCab/Rust bridges as a fallback. Boundary-only keeps:

- `exactPhrase` / `force` replacements
- conservative `nameAlias` only on token boundaries, honorifics, quotes, or work/series particles
- fail-closed aliases when a verb/adjective inflection suffix follows

## Boundary-only microbench (this VM)

Same machine, in-process `BoundaryOnlyJapaneseAnalyzer`:

| Case | Result |
|---|---|
| Cold `warmUp()` | < 1 ms |
| `悟は笑った。` + `真相を悟った。` | < 1 ms each |
| 500-character Japanese page | < 2 ms |
| Extra RSS | not measurable above Dart VM noise |

## Capability string

`boundary-only` — the settings UI must not claim full POS morphology.
