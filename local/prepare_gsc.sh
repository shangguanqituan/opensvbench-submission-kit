#!/bin/bash

# Prepare Google Speech Commands (GSC) for Speaker Verification Benchmark
#
# Update:
# - Include WORD in utt_id for better readability (e.g., SPK_WORD_INDEX)

data=data
max_utts=10000
legacy_random=false
KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "${KIT_ROOT}/tools/parse_options.sh" || exit 1

data=$(realpath "${data}")
rawdata_dir=${data}/gsc/raw_data
prep_dir=${data}/gsc/prepared
canonical_dir=${KIT_ROOT}/resources/canonical/gsc

case "${legacy_random}" in
    1|true|TRUE|yes|YES)
        legacy_random=true
        ;;
    *)
        legacy_random=false
        ;;
esac

if [ "${legacy_random}" = false ] && [ "${max_utts}" -ne 10000 ]; then
    echo "[GSC] Canonical mode requires --max-utts 10000."
    echo "[GSC] Use --legacy-random true for a custom experimental subset."
    exit 2
fi

mkdir -p "${prep_dir}"

echo "=== [GSC] prepare_gsc.sh ==="

# -------------------------------------------------------------
# 1. Reorganize Directory Structure (Flat Word -> Speaker/Word)
# -------------------------------------------------------------
echo "[GSC] Checking directory structure..."

if [ -d "${rawdata_dir}/zero" ] && [ ! -d "${rawdata_dir}/zero/zero" ]; then
    echo "[GSC] Reorganizing raw_data into: raw_data/SPEAKER/WORD/wav ..."

    find "${rawdata_dir}" -maxdepth 2 -name "*.wav" | grep -v "_background_noise_" | while read -r wav_path; do
        filename=$(basename "$wav_path")
        parent_dir=$(dirname "$wav_path")
        word=$(basename "$parent_dir")
        spk_id=$(echo "$filename" | cut -d'_' -f1)
        grandparent_dir=$(dirname "$parent_dir")

        if [ "$grandparent_dir" == "${rawdata_dir}" ]; then
            target_dir="${rawdata_dir}/${spk_id}/${word}"
            mkdir -p "${target_dir}"
            mv "$wav_path" "${target_dir}/"
        fi
    done
    find "${rawdata_dir}" -maxdepth 1 -type d -empty -delete
    echo "[GSC] Reorganization complete."
else
    echo "[GSC] Structure seems already organized. Skipping reorganization."
fi

if [ "${legacy_random}" = false ]; then
    if [ ! -f "${canonical_dir}/manifest.tsv" ] || [ ! -f "${canonical_dir}/trials_short.txt" ]; then
        echo "[GSC] ERROR: Missing frozen canonical manifest/trials in ${canonical_dir}"
        exit 2
    fi
    echo "[GSC] Applying frozen canonical manifest and trials..."
    python3 "${KIT_ROOT}/tools/apply_canonical_gsc.py" \
        --manifest "${canonical_dir}/manifest.tsv" \
        --trials "${canonical_dir}/trials_short.txt" \
        --raw-dir "${rawdata_dir}" \
        --prep-dir "${prep_dir}"
    echo "=== [GSC] Preparation Done (canonical). ==="
    exit 0
fi

echo "[GSC] WARNING: using legacy random GSC preparation; output is not the core canonical protocol."

# -------------------------------------------------------------
# 2. Generate Metadata (Test Split Only) with Semantic Utt-ID
# Only include files listed in testing_list.txt
# testing_list.txt format: word/speaker_nohash_N.wav
# -------------------------------------------------------------
echo "[GSC] Scanning test-split files (testing_list.txt) to generate metadata..."

wav_scp=${prep_dir}/wav.scp
utt2spk=${prep_dir}/utt2spk
utt2text=${prep_dir}/utt2text

> "${wav_scp}"
> "${utt2spk}"
> "${utt2text}"

testing_list="${rawdata_dir}/testing_list.txt"
if [ ! -f "${testing_list}" ]; then
    echo "[GSC] WARNING: testing_list.txt not found at ${testing_list}. Falling back to full scan."
    testing_list=""
fi

# Build manifests in one pass. This is much faster than a bash loop over the
# full Speech Commands tree while preserving the same utt_id convention.
if [ -n "${testing_list}" ]; then
    echo "[GSC] Loaded $(wc -l < "${testing_list}") entries from testing_list.txt"
fi

awk \
  -v testing_list="${testing_list}" \
  -v wav_scp="${wav_scp}" \
  -v utt2spk="${utt2spk}" \
  -v utt2text="${utt2text}" '
BEGIN {
  if (testing_list != "") {
    while ((getline entry < testing_list) > 0) {
      sub(/\r$/, "", entry)
      if (entry != "") {
        test_file_set[entry] = 1
      }
    }
    close(testing_list)
  }
}
{
  abs_path = $0
  n = split(abs_path, path_parts, "/")
  filename = path_parts[n]
  word = path_parts[n - 1]
  spk_id = path_parts[n - 2]

  split(filename, filename_parts, "_")
  fname_spk = filename_parts[1]
  if (spk_id != fname_spk) {
    spk_id = fname_spk
  }

  if (testing_list != "") {
    lookup_key = word "/" filename
    if (!(lookup_key in test_file_set)) {
      next
    }
  }

  suffix = filename
  sub("^" spk_id "_", "", suffix)
  sub(/\.[^.]*$/, "", suffix)
  utt_id = spk_id "_" word "_" suffix

  print utt_id " " abs_path >> wav_scp
  print utt_id " " spk_id >> utt2spk
  print utt_id " " word >> utt2text
}
' < <(find "${rawdata_dir}" -name "*.wav" | grep -v "_background_noise_" | sort)

num_utt=$(wc -l < "${wav_scp}")
echo "[GSC] Processed ${num_utt} utterances."

# If this prepared directory already has a canonical wav_all.scp, keep its
# clean subset stable so reruns do not silently perturb frozen trial sets.
canonical_wav_all="${prep_dir}/wav_all.scp"
if [ "${max_utts}" -gt 0 ] && [ -f "${canonical_wav_all}" ]; then
  canonical_clean_count=$(awk '
    $1 !~ /_(noisy|reverb|codec_)/ {
      count += 1
    }
    END { print count + 0 }
  ' "${canonical_wav_all}")
  if [ "${canonical_clean_count}" -ge "${max_utts}" ]; then
    echo "[GSC] Reusing ${max_utts} clean utterances from existing wav_all.scp"
    awk -v max_utts="${max_utts}" '
      $1 !~ /_(noisy|reverb|codec_)/ {
        print
        count += 1
        if (count >= max_utts) {
          exit
        }
      }
    ' "${canonical_wav_all}" > "${wav_scp}"
    awk '{ split($1, parts, "_"); print $1, parts[1] }' "${wav_scp}" > "${utt2spk}"
    awk '{ split($1, parts, "_"); print $1, parts[2] }' "${wav_scp}" > "${utt2text}"
    awk '{ spk=$2; utt=$1; spk2utt[spk]=spk2utt[spk] " " utt } END { for (spk in spk2utt) print spk spk2utt[spk] }' "${utt2spk}" | sort > "${prep_dir}/spk2utt"
  fi
fi

# -------------------------------------------------------------
# 2.5. Subsample to max_utts (speaker-balanced)
# -------------------------------------------------------------
if [ "${max_utts}" -gt 0 ] && [ "$(wc -l < ${wav_scp})" -gt "${max_utts}" ]; then
  echo "[GSC] Subsampling to ${max_utts} utterances..."
  python3 "${KIT_ROOT}/tools/subsample_wavscp.py" \
    --wav-scp  "${wav_scp}" \
    --utt2spk  "${utt2spk}" \
    --max-utts "${max_utts}" \
    --filter-files "${utt2spk}" "${utt2text}" \
    --regen-spk2utt "${prep_dir}/spk2utt" \
    --seed 777
fi

# -------------------------------------------------------------
# 3. Generate Trials
# -------------------------------------------------------------
echo "[GSC] Generating Trials using tools/make_trials_gsc.py ..."

python3 "${KIT_ROOT}/tools/make_trials_gsc.py" \
    --utt2spk           "${utt2spk}" \
    --utt2text          "${utt2text}" \
    --out-short         "${prep_dir}/trials_short.txt" \
    --preserve-existing-short \
    --max-target-trials 20000 \
    --nontarget-ratio   10 \
    --seed 777

echo "=== [GSC] Preparation Done. ==="
