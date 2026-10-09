# Novel TTS pronunciation analyzer benchmark

Host: Cursor Cloud Agent VM, Linux x86_64  
Flutter 3.47.1 / Dart 3.13.1

## Decision

**Production analyzer: `IpadicJapaneseAnalyzer` (capability `ipadic-lattice`).**

It is a pure-Dart reimplementation of MeCab's lattice search (dictionary
lookup, `char.def` unknown-word generation, Viterbi with the IPADIC connection
matrix) over the complete mecab-ipadic 2.7.0-20070801, compiled by
`tool/build_ipadic_dictionary.dart` into `assets/tts/ipadic.bin.gz`. The
user's name aliases are added to the lattice as `名詞,固有名詞,人名,名` with
cost 7000, so the analyzer decides whether `悟` in `五条悟` or `悟以外` is the
name. No native code is involved, so it runs on every platform the app and its
tests run on.

`LexiconJapaneseAnalyzer` (below) stays as the fallback the worker uses while
the dictionary is still loading or if the asset cannot be read.

### Why the lexicon analyzer was replaced

The lexicon only knew verbs and adjectives, and grouped every other kanji run
into one token. A registered given name next to a surname or a following noun
therefore always looked like part of a longer word, which is the most common
way names are written:

| Text, alias | Lexicon | IPADIC lattice | MeCab (no alias) |
|---|---|---|---|
| `五条悟は`, 悟 | kept (`五条悟` one token) | **さとる** | 五条/悟(人名) |
| `夏油傑が`, 傑 | kept | **すぐる** | 夏/油/傑(人名) |
| `伏黒恵は`, 恵 | kept | **めぐみ** | 伏黒/恵(人名) |
| `狗巻棘は`, 棘 | kept | **とげ** | 狗/巻/棘 |
| `悟以外`, 悟 | kept | **さとる** | 悟(動詞)/以外 |
| `悟本人` `悟一人`, 悟 | kept | **さとる** | 悟(人名)/本人 |
| `悟った` `悟り` `覚悟` `恵まれた` `知恵` `傑作` `一歩` | kept | kept | — |

On a 64-sentence probe of name and non-name uses (single-kanji aliases 悟 傑
恵 光 歩 翼 凛 楓 蓮 司 棘 静 誠 薫 優 実), the lexicon missed 9 names and the
lattice misses none. The lattice's six remaining errors are all replacements
where the text means the common word: `光が差し込んだ`, `翼を広げた`,
`蓮の花`, `棘がある` (morphologically identical to the name — no analyzer can
separate them, only a work scope can), `凛として` (genuinely ambiguous), and
`悟空`, which IPADIC does not contain, so MeCab itself reads `悟/空`; a
`悟空` fixed phrase covers it.

### Fidelity to MeCab

`tool/compare_ipadic_with_mecab.dart` against `mecab` 0.996 with the same
IPADIC, over five Aozora Bunko novels (6097 lines, 902 707 UTF-16 units,
594 577 tokens): **3 lines differ**, each a tie between two paths of identical
total cost where MeCab's node order picks the other one (`又` 副詞/接続詞,
`主`, `見えなく`). `test/novel_tts_ipadic_test.dart` pins 48 sentences to
MeCab's output.

### Cost (Linux x86_64 VM, Dart 3.13.5, AOT `dart compile exe`)

| | |
|---|---:|
| Asset | **4.23 MB** gzip (`ipadic.bin.gz`), 11.9 MB inflated |
| Load (read, inflate, map) | **70 ms**; inflating runs in a background isolate |
| Analysis | **1.5 µs** per UTF-16 unit, ~1.2 ms for an 800-unit region |
| Resident | the 11.9 MB dictionary, shared by every analyzer in the process |

The asset is already compressed, so an APK or IPA grows by about its size.
The first alias candidate in a process waits up to 1.5 s for the load and is
served by the lexicon analyzer if it takes longer; the load keeps going and
the next region uses the lattice.

## Why not kuromoji (Phase 0, 2026-08-30)

| Gate | Threshold | kuromoji 1.0.5 result |
|---|---:|---|
| Package on disk | (informational) | **23 MB** under `~/.pub-cache/hosted/pub.dev/kuromoji-1.0.5`, mostly base64 `*.dat.dart` dictionaries (`tid_pos.dat.dart` 7.9 MB, `base.dat.dart` 5.3 MB, …) |
| Cold init | ≤ 1.2 s, off UI isolate | `TokenizerBuilder().build()` **did not finish in 658 s** and was killed. Fails by two orders of magnitude. |
| Warm 500-character p95 | ≤ 20 ms | Not reached; the tokenizer never became ready. |
| Offset trust | must map to UTF-16 | Splits on `[、。]` and reports `word_position` as the last-token position plus an in-sentence `startPos`. Offsets reset across sentences and are not source UTF-16 ranges. |

The first plan forbade kuromoji until every hard gate passed, and native
MeCab or Rust bridges altogether, so a lexicon derived from IPADIC shipped
instead. The lattice analyzer above keeps that constraint (no native code)
while using all of IPADIC; its load passes the same 1.2 s gate by a wide
margin because the dictionary is binary typed data, not Dart source.

## Lexicon analyzer (fallback) measurements

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
| Android arm64 release APK increment | ≤ 30 MB | **64 KiB** (see below) |
| Offset trust | must map to UTF-16 | Tokens carry source UTF-16 `start`/`end`; `MorphologyOffsetMapper` rejects any token that does not land on a scalar boundary inside the region |

The trie is built lazily behind `JapaneseInflectionLexicon.shared` on the first
alias candidate, so a reader that never configures a name alias never pays for
it, and app startup never touches it.

### Android release size

Two `flutter build apk --release --target-platform android-arm64` runs on this
VM, one at `HEAD` and one with `japaneseInflectionClasses` and
`japaneseFixedWords` emptied:

| Build | `app-release.apk` |
|---:|---:|
| With the lexicon | 40 944 336 B |
| Empty lexicon | 40 878 800 B |
| Increment | **65 536 B (64 KiB)** |

The const strings deduplicate and compress in the AOT snapshot, so 115 KiB of
generated Dart source costs 64 KiB shipped — three orders of magnitude under
the gate, against kuromoji's 23 MB of dictionary source.

## Accuracy

`test/novel_tts_pronunciation_test.dart` holds the behavioural matrix: the
`悟` set from the plan, plus a homograph regression suite over 恵 愛 光 望 歩
司 静 実 優 薫 誠 翼 楼 葵, and the degraded-path cases.

On an eight-line novel excerpt with four single-kanji aliases (悟 恵 傑 棘),
23 candidates resolve to 17 applied and 6 kept, and all 6 kept spans are real
non-name uses: 悟った, 悟り, 恵まれた, 知恵, 悟らない, 悟れば.

## Capability strings

- `ipadic-lattice` — full IPADIC lattice search with the aliases in the
  lattice. What the settings UI reports.
- `lexicon-pos` — IPADIC-derived part of speech, dictionary form, conjugation
  type. Used while the dictionary loads or if it cannot.
- `boundary-only` — script runs only, no part of speech.
- `unavailable` — the analyzer threw or timed out. Aliases fall back to the
  honorific, quote, and okurigana lists and skip anything they cannot justify.
