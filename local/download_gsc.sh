#!/bin/bash

# Download and unpack Google Speech Commands (GSC) v0.02

data=data
. tools/parse_options.sh || exit 1

data=$(realpath "${data}")
download_dir=${data}/gsc/download_data
rawdata_dir=${data}/gsc/raw_data

mkdir -p "${download_dir}"
mkdir -p "${rawdata_dir}"

echo "=== [GSC] Downloading archives to: ${download_dir} ==="

# GSC v0.02 URL
url="http://download.tensorflow.org/data/speech_commands_v0.02.tar.gz"
archive=${download_dir}/speech_commands_v0.02.tar.gz
expected_archive_sha256=af14739ee7dc311471de98f5f9d2c9191b18aedfe957f4a6ff791c709868ff58

if [ ! -f "${archive}" ]; then
  echo "[GSC] Downloading speech_commands_v0.02.tar.gz ..."
  # Use the same wget pattern as the other download scripts.
  wget -O "${archive}" "${url}"
else
  echo "[GSC] Found ${archive}, skip download."
fi

actual_archive_sha256=$(sha256sum "${archive}" | awk '{print $1}')
if [ "${actual_archive_sha256}" != "${expected_archive_sha256}" ]; then
  echo "[GSC] ERROR: speech_commands_v0.02.tar.gz checksum mismatch."
  echo "  expected: ${expected_archive_sha256}"
  echo "  actual:   ${actual_archive_sha256}"
  exit 2
fi
echo "[GSC] Verified archive SHA-256: ${actual_archive_sha256}"

echo "=== [GSC] Extracting archives to: ${rawdata_dir} ==="

# Check whether extraction has already completed. GSC contains an
# _background_noise_ directory that can be used as a marker.
if [ ! -d "${rawdata_dir}/_background_noise_" ]; then
  echo "[GSC] Unpacking ${archive} -> ${rawdata_dir} ..."
  # The archive has no root directory; extract the word directories directly
  # into rawdata_dir.
  tar -xzf "${archive}" -C "${rawdata_dir}" || { echo "[GSC] Extract failed"; exit 1; }
else
  echo "[GSC] Found _background_noise_ in ${rawdata_dir}, assuming already unpacked."
fi

echo "=== [GSC] Download + unpack done. Raw data in: ${rawdata_dir} ==="
