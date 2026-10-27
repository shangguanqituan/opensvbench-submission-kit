# Google Speech Commands

The kit does not include Speech Commands audio.

```bash
./local/download_gsc.sh --data "${DATA_ROOT}"
./local/prepare_gsc.sh --data "${DATA_ROOT}"
```

Raw files go under `${DATA_ROOT}/gsc/raw_data`; prepared manifests and trials
go under `${DATA_ROOT}/gsc/prepared`.

Core scenario: `gsc_short`, built from the official testing split. The default
preparation applies the committed canonical resources under
`resources/canonical/gsc/`:

- `manifest.tsv`: 10,000 utterances from 250 speakers;
- `trials_short.txt`: 220,000 rows;
- trial SHA-256:
  `24c93fc5799f2a24afa603eaf410dfc24e9bd70ec896e41e2877e551bacf0229`.

The script validates the archive checksum, `testing_list.txt`, every canonical
audio path, and the trial fingerprint. It does not randomly subsample or
regenerate trials. A custom random subset is available only for experiments:

```bash
./local/prepare_gsc.sh \
  --data "${DATA_ROOT}" \
  --legacy-random true \
  --max-utts 10000
```

The legacy output is not valid for the core leaderboard protocol. See
`resources/canonical/gsc/README.md` for all pinned hashes.

Follow the upstream Speech Commands terms.
