# Canonical GSC Protocol

`gsc_short` is an OpenSVBench protocol built from the official Google Speech
Commands v0.02 testing split. This directory commits the fixed utterance subset
and trial rows so that every submission uses exactly the same evaluation input.
The submission kit does not redistribute the source audio.

## Pinned Inputs and Resources

| Item | Count | SHA-256 |
| --- | ---: | --- |
| `speech_commands_v0.02.tar.gz` | 2,428,923,189 bytes | `af14739ee7dc311471de98f5f9d2c9191b18aedfe957f4a6ff791c709868ff58` |
| extracted `testing_list.txt` | 11,005 lines | `2d17c6b3faf63be43eda93cfeb0c747cfd79b7b236282039dbac65a2cb5f1df5` |
| `manifest.tsv` | 10,000 utterances / 250 speakers | `8c19839809cbd4e08a5266076c830e49fcb649524d928edb7af114908664dcb3` |
| `trials_short.txt` | 220,000 rows | `24c93fc5799f2a24afa603eaf410dfc24e9bd70ec896e41e2877e551bacf0229` |

The official archive is available at:

```text
http://download.tensorflow.org/data/speech_commands_v0.02.tar.gz
```

`manifest.tsv` uses the following columns:

```text
utt_id    rel_path    speaker_id    word
```

`rel_path` is relative to `gsc/raw_data` after the kit reorganizes the archive
into `speaker/word/audio.wav`. This manifest is the historical 10,000-utterance
subset associated with the frozen `24c93fc5...` trial file, and its row order is
also fixed.

## Preparation

The normal commands apply the committed resources and validate the source
archive, testing list, manifest, audio paths, and trial fingerprint:

```bash
./local/download_gsc.sh --data "${DATA_ROOT}"
./local/prepare_gsc.sh --data "${DATA_ROOT}"
```

Canonical mode is the only mode used by the core protocol. It does not sample
utterances or regenerate trials. To prevent protocol drift, canonical mode
rejects any non-default `--max-utts` value.

For local experiments only, the previous random generator remains available by
explicit opt-in. Its output is not the core `gsc_short` protocol and must not be
used for leaderboard submissions:

```bash
./local/prepare_gsc.sh \
  --data "${DATA_ROOT}" \
  --legacy-random true \
  --max-utts 10000
```

Do not edit `trials_short.txt` or replace the committed manifest. If the core
fingerprint check fails, rerun canonical preparation from the official archive
instead of changing score files.
