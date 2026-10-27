# Full-core Quickstart

This workflow prepares all core trial sets and creates an uploadable submission
archive.

## 1. Configure

```bash
cp configs/full_core.example.env configs/full_core.env
```

Edit `configs/full_core.env` and set at least:

```bash
DATA_ROOT="/path/to/opensvbench_data"
MODEL_NAME="/path/to/model"
BACKEND="wespeaker"
GPU=0
SUBMISSION_NAME="my-model"
```

Keep `DATA_ROOT` outside the kit if possible.

## 2. Check the environment

```bash
./scripts/00_check_env.sh
```

Install any package required by the selected backend. `requirements.txt`
contains the common preparation and scoring dependencies; backend packages are
installed separately.

## 3. Download or place data

```bash
./scripts/01_download_full_core.sh
```

See `MANUAL_PLACEMENT.md` for datasets that require manual access. After
placing the files, run this step again.

## 4. Prepare the data

```bash
./scripts/02_prepare_full_core.sh
```

The scripts write manifests, prepared audio, and trial files below `DATA_ROOT`.
For GSC, the default preparation applies the committed canonical manifest and
trial file; it does not randomly select utterances or regenerate the trial list.
The pinned source and resource hashes are documented in
`resources/canonical/gsc/README.md`.

## 5. Check the trials

```bash
./scripts/03_precheck_full_core.sh
```

This checks that all scenario files are present and compares the local trials
with `resources/core_trial_fingerprints.tsv`. Do not upload if a fingerprint
does not match.

## 6. Generate a submission

```bash
./scripts/04_generate_submission_zip.sh
```

The zip is written to `OUTPUT_DIR`. If the model or prepared data changes while
an old embedding cache remains, set `FORCE_EXTRACT=1` and run the command again.

## 7. Upload

Open `https://opensvbench.xyz/submit/model` and upload the zip. See
`scripts/05_upload_instructions.md` for the form and archive format.
