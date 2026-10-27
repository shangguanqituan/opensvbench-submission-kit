# Changelog

## 0.2.2 - 2026-10-27

- Commit the historical 10,000-utterance GSC manifest and matching
  `24c93fc5...` trial file as the sole canonical `gsc_short` protocol.
- Make canonical GSC preparation validate the official archive, testing list,
  manifest, source paths, and frozen trial fingerprint before writing metadata.
- Keep the previous random GSC subset/trial generator behind the explicit
  `--legacy-random true` opt-in.

## 0.2.1 - 2026-10-18

- Freeze the VoxCeleb Short and CN-Celeb Short crop source IDs, sample offsets,
  lengths, sample rates, and decoded PCM SHA-256 fingerprints.
- Verify all canonical short audio before precheck, scoring, or embedding-cache
  reuse.
- Invalidate only stale short-utterance entries in legacy embedding caches.
