#!/usr/bin/env python3
"""Install the frozen OpenSVBench GSC manifest and trial file."""

from __future__ import annotations

import argparse
import hashlib
import shutil
import sys
from collections import defaultdict
from pathlib import Path


EXPECTED_TESTING_LIST_ROWS = 11005
EXPECTED_TESTING_LIST_SHA256 = (
    "2d17c6b3faf63be43eda93cfeb0c747cfd79b7b236282039dbac65a2cb5f1df5"
)
EXPECTED_MANIFEST_ROWS = 10000
EXPECTED_MANIFEST_SPEAKERS = 250
EXPECTED_MANIFEST_SHA256 = (
    "8c19839809cbd4e08a5266076c830e49fcb649524d928edb7af114908664dcb3"
)
EXPECTED_TRIAL_ROWS = 220000
EXPECTED_TRIAL_SHA256 = (
    "24c93fc5799f2a24afa603eaf410dfc24e9bd70ec896e41e2877e551bacf0229"
)


def get_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Apply the frozen GSC manifest"
    )
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--trials", required=True)
    parser.add_argument("--raw-dir", required=True)
    parser.add_argument("--prep-dir", required=True)
    return parser.parse_args()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as input_file:
        for chunk in iter(lambda: input_file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_manifest(path: Path) -> list[dict[str, str]]:
    expected_header = ["utt_id", "rel_path", "speaker_id", "word"]
    rows: list[dict[str, str]] = []
    seen_ids: set[str] = set()

    with path.open("r", encoding="utf-8") as manifest_file:
        header = manifest_file.readline().rstrip("\n").split("\t")
        if header != expected_header:
            raise ValueError(f"Unexpected manifest header in {path}: {header}")

        for line_number, line in enumerate(manifest_file, start=2):
            parts = line.rstrip("\n").split("\t")
            if len(parts) != len(expected_header):
                raise ValueError(
                    f"Malformed manifest row {line_number}: {line!r}"
                )
            utt_id, rel_path, speaker_id, word = parts
            if not utt_id or not rel_path or not speaker_id or not word:
                raise ValueError(f"Empty manifest field on row {line_number}")
            if utt_id in seen_ids:
                raise ValueError(
                    f"Duplicate utterance ID in manifest: {utt_id}"
                )
            relative_path = Path(rel_path)
            if relative_path.is_absolute() or ".." in relative_path.parts:
                raise ValueError(
                    f"Unsafe relative path in manifest: {rel_path}"
                )
            path_parts = relative_path.parts
            if len(path_parts) < 3:
                raise ValueError(f"Unexpected GSC relative path: {rel_path}")
            if path_parts[-3] != speaker_id or path_parts[-2] != word:
                raise ValueError(
                    "Manifest metadata does not match path on row "
                    f"{line_number}: "
                    f"{rel_path}"
                )
            filename_stem = Path(path_parts[-1]).stem
            speaker_prefix = f"{speaker_id}_"
            if not filename_stem.startswith(speaker_prefix):
                raise ValueError(
                    f"GSC filename does not start with speaker ID on row "
                    f"{line_number}: {rel_path}"
                )
            expected_utt_id = (
                f"{speaker_id}_{word}_{filename_stem[len(speaker_prefix):]}"
            )
            if utt_id != expected_utt_id:
                raise ValueError(
                    f"Unexpected utterance ID on row {line_number}: "
                    f"{utt_id} != {expected_utt_id}"
                )
            seen_ids.add(utt_id)
            rows.append(
                {
                    "utt_id": utt_id,
                    "rel_path": rel_path,
                    "speaker_id": speaker_id,
                    "word": word,
                }
            )

    if not rows:
        raise ValueError(f"Canonical GSC manifest is empty: {path}")
    actual_digest = sha256_file(path)
    if (
        len(rows) != EXPECTED_MANIFEST_ROWS
        or actual_digest != EXPECTED_MANIFEST_SHA256
    ):
        raise ValueError(
            "Unexpected canonical GSC manifest: "
            f"rows={len(rows)}, sha256={actual_digest}"
        )
    speaker_count = len({row["speaker_id"] for row in rows})
    if speaker_count != EXPECTED_MANIFEST_SPEAKERS:
        raise ValueError(
            "Unexpected canonical GSC speaker count: "
            f"{speaker_count} != {EXPECTED_MANIFEST_SPEAKERS}"
        )
    return rows


def read_testing_list(raw_dir: Path) -> set[str]:
    testing_list_path = raw_dir / "testing_list.txt"
    if not testing_list_path.is_file():
        raise FileNotFoundError(
            f"Missing GSC testing list: {testing_list_path}"
        )
    testing_entries = set()
    with testing_list_path.open("r", encoding="utf-8") as testing_file:
        for line in testing_file:
            entry = line.strip()
            if entry:
                testing_entries.add(entry.lstrip("./"))
    actual_digest = sha256_file(testing_list_path)
    if (
        len(testing_entries) != EXPECTED_TESTING_LIST_ROWS
        or actual_digest != EXPECTED_TESTING_LIST_SHA256
    ):
        raise ValueError(
            "Unexpected GSC testing_list.txt: "
            f"unique_rows={len(testing_entries)}, sha256={actual_digest}"
        )
    return testing_entries


def validate_audio(rows: list[dict[str, str]], raw_dir: Path) -> None:
    testing_entries = read_testing_list(raw_dir)
    missing: list[Path] = []
    outside_testing: list[str] = []

    for row in rows:
        audio_path = raw_dir / row["rel_path"]
        if not audio_path.is_file():
            missing.append(audio_path)
        relative_testing_key = "/".join(
            Path(row["rel_path"]).parts[-2:]
        )
        if relative_testing_key not in testing_entries:
            outside_testing.append(relative_testing_key)

    if missing:
        print("[GSC] ERROR: canonical manifest audio is missing.")
        print(f"  missing_count: {len(missing)} / {len(rows)}")
        for path in missing[:10]:
            print(f"    {path}")
        raise SystemExit(2)
    if outside_testing:
        print(
            "[GSC] ERROR: canonical manifest contains audio outside "
            "testing_list.txt."
        )
        print(f"  outside_testing_count: {len(outside_testing)}")
        for item in outside_testing[:10]:
            print(f"    {item}")
        raise SystemExit(2)


def validate_trials(path: Path) -> None:
    rows = 0
    with path.open("rb") as trials_file:
        for _ in trials_file:
            rows += 1
    actual_digest = sha256_file(path)
    if rows != EXPECTED_TRIAL_ROWS or actual_digest != EXPECTED_TRIAL_SHA256:
        raise ValueError(
            "Unexpected canonical GSC trials: "
            f"rows={rows}, sha256={actual_digest}"
        )


def write_prepared(
    rows: list[dict[str, str]], raw_dir: Path, prep_dir: Path
) -> None:
    prep_dir.mkdir(parents=True, exist_ok=True)
    metadata_rows = rows
    wav_rows = sorted(rows, key=lambda row: row["utt_id"])
    spk2utt: defaultdict[str, list[str]] = defaultdict(list)
    for row in metadata_rows:
        spk2utt[row["speaker_id"]].append(row["utt_id"])

    outputs = {
        "wav.scp": [
            f"{row['utt_id']} {raw_dir / row['rel_path']}\n"
            for row in wav_rows
        ],
        "wav_all.scp": [
            f"{row['utt_id']} {raw_dir / row['rel_path']}\n"
            for row in wav_rows
        ],
        "utt2spk": [
            f"{row['utt_id']} {row['speaker_id']}\n" for row in metadata_rows
        ],
        "utt2text": [
            f"{row['utt_id']} {row['word']}\n" for row in metadata_rows
        ],
        "spk2utt": [
            f"{speaker} {' '.join(sorted(utterances))}\n"
            for speaker, utterances in sorted(spk2utt.items())
        ],
    }
    for filename, lines in outputs.items():
        temporary_path = prep_dir / f".{filename}.canonical.tmp"
        with temporary_path.open("w", encoding="utf-8") as output_file:
            output_file.writelines(lines)
        temporary_path.replace(prep_dir / filename)


def main() -> None:
    args = get_args()
    manifest_path = Path(args.manifest).resolve()
    trials_path = Path(args.trials).resolve()
    raw_dir = Path(args.raw_dir).resolve()
    prep_dir = Path(args.prep_dir).resolve()

    try:
        rows = read_manifest(manifest_path)
        validate_trials(trials_path)
        validate_audio(rows, raw_dir)
    except (OSError, ValueError) as exc:
        print(f"[GSC] ERROR: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc

    write_prepared(rows, raw_dir, prep_dir)
    temporary_trials = prep_dir / ".trials_short.txt.canonical.tmp"
    shutil.copyfile(trials_path, temporary_trials)
    temporary_trials.replace(prep_dir / "trials_short.txt")

    speaker_count = len({row["speaker_id"] for row in rows})
    print(
        "[GSC] Applied frozen OpenSVBench canonical manifest: "
        f"{len(rows)} utterances, {speaker_count} speakers, "
        f"{EXPECTED_TRIAL_ROWS} trials"
    )


if __name__ == "__main__":
    main()
