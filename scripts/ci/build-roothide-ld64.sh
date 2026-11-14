#!/usr/bin/env bash
set -euo pipefail

umask 022

readonly PROCURSUS_REPOSITORY="https://github.com/roothide/Procursus-roothide.git"
readonly PROCURSUS_COMMIT="7dfa18ef09d18028f4e2bca01ce28c3e7e0db227"
readonly EXPECTED_CCTOOLS_COMMIT="6262802c55660436c49c52f323c2db9900a900ae"
readonly EXPECTED_LD64_COMMIT="eac639ff5e0104c57343a0342650294ad37fa510"
readonly EXPECTED_PACKAGE="ld64"
readonly EXPECTED_VERSION="951.9-1"
readonly EXPECTED_ARCHITECTURE="iphoneos-arm64e"

readonly ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
readonly OUTPUT_DIR="${ROOT}/artifacts/roothide-ld64"
readonly SOURCE_DIR="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/Procursus-roothide"
readonly BUILD_LOG="${OUTPUT_DIR}/build.log"
readonly PROVENANCE="${OUTPUT_DIR}/provenance.txt"
readonly FAILURE_SUMMARY="${OUTPUT_DIR}/failure-summary.txt"

mkdir -p "${OUTPUT_DIR}"
rm -rf "${SOURCE_DIR}"

exec > >(tee "${BUILD_LOG}") 2>&1

report_failure() {
  local status=$?
  trap - ERR

  {
    printf 'exit_status=%d\n' "${status}"
    printf '%s\n' '--- build.log tail ---'
    tail -n 80 "${BUILD_LOG}" 2>/dev/null || true
  } > "${FAILURE_SUMMARY}"

  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    local annotation
    annotation="$(tail -n 40 "${FAILURE_SUMMARY}" | sed -e 's/%/%25/g' -e 's/\r/%0D/g' -e 's/$/%0A/' | tr -d '\n')"
    printf '::error title=RootHide ld64 构建失败::%s\n' "${annotation}"
  fi

  exit "${status}"
}
trap report_failure ERR

if command -v gmake >/dev/null 2>&1; then
  MAKE=gmake
else
  MAKE=make
fi

{
  printf 'repository=%s\n' "${PROCURSUS_REPOSITORY}"
  printf 'commit=%s\n' "${PROCURSUS_COMMIT}"
  printf 'runner_os=%s\n' "${RUNNER_OS:-unknown}"
  printf 'runner_arch=%s\n' "${RUNNER_ARCH:-unknown}"
  printf 'xcode=%s\n' "$(xcodebuild -version | tr '\n' ';')"
  printf 'clang=%s\n' "$(clang --version | head -n 1)"
  printf 'make=%s\n' "$(${MAKE} --version | head -n 1)"
  printf 'bash=%s\n' "$(bash --version | head -n 1)"
  printf 'disk_before=%s\n' "$(df -h . | tail -n 1 | tr -s ' ')"
} > "${PROVENANCE}"

git clone --filter=blob:none --no-checkout "${PROCURSUS_REPOSITORY}" "${SOURCE_DIR}"
git -C "${SOURCE_DIR}" fetch --depth=1 origin "${PROCURSUS_COMMIT}"
git -C "${SOURCE_DIR}" checkout --detach FETCH_HEAD

test "$(git -C "${SOURCE_DIR}" rev-parse HEAD)" = "${PROCURSUS_COMMIT}"
grep -Fq "CCTOOLS_COMMIT  := ${EXPECTED_CCTOOLS_COMMIT}" "${SOURCE_DIR}/makefiles/cctools.mk"
grep -Fq "LD64_COMMIT     := ${EXPECTED_LD64_COMMIT}" "${SOURCE_DIR}/makefiles/cctools.mk"
grep -Fq 'LD64_VERSION    := 951.9' "${SOURCE_DIR}/makefiles/cctools.mk"

printf '\n[official-input-sha256]\n' >> "${PROVENANCE}"
shasum -a 256 \
  "${SOURCE_DIR}/Makefile" \
  "${SOURCE_DIR}/makefiles/cctools.mk" \
  "${SOURCE_DIR}/build_patch/cctools/ld64-blob-clone.diff" \
  "${SOURCE_DIR}/build_patch/cctools/ld64-stdlib.diff" \
  "${SOURCE_DIR}/build_patch/cctools/llvm-headers-only.diff" \
  >> "${PROVENANCE}"

"${MAKE}" -C "${SOURCE_DIR}" -j2 \
  MEMO_TARGET=iphoneos-arm64-roothide \
  MEMO_CFVER=1900 \
  NO_PGP=1 \
  cctools-package

mapfile -t PACKAGES < <(find "${SOURCE_DIR}" -type f -name 'ld64_951.9-1_iphoneos-arm64e.deb' -print)
if [[ ${#PACKAGES[@]} -ne 1 ]]; then
  printf '期望恰好一个 ld64 deb，实际找到 %d 个\n' "${#PACKAGES[@]}" >&2
  exit 1
fi

readonly PACKAGE_PATH="${PACKAGES[0]}"
readonly PACKAGE_NAME="$(dpkg-deb -f "${PACKAGE_PATH}" Package)"
readonly PACKAGE_VERSION="$(dpkg-deb -f "${PACKAGE_PATH}" Version)"
readonly PACKAGE_ARCHITECTURE="$(dpkg-deb -f "${PACKAGE_PATH}" Architecture)"

test "${PACKAGE_NAME}" = "${EXPECTED_PACKAGE}"
test "${PACKAGE_VERSION}" = "${EXPECTED_VERSION}"
test "${PACKAGE_ARCHITECTURE}" = "${EXPECTED_ARCHITECTURE}"

cp "${PACKAGE_PATH}" "${OUTPUT_DIR}/"
dpkg-deb -f "${PACKAGE_PATH}" > "${OUTPUT_DIR}/control.txt"
dpkg-deb -c "${PACKAGE_PATH}" > "${OUTPUT_DIR}/contents.txt"

readonly EXTRACT_DIR="${OUTPUT_DIR}/extracted"
mkdir -p "${EXTRACT_DIR}"
dpkg-deb -x "${PACKAGE_PATH}" "${EXTRACT_DIR}"

readonly LD64_PATH="${EXTRACT_DIR}/usr/bin/ld64"
test -f "${LD64_PATH}"
file "${LD64_PATH}" > "${OUTPUT_DIR}/ld64-file.txt"
otool -hv "${LD64_PATH}" > "${OUTPUT_DIR}/ld64-mach-header.txt"

printf '\n[output-sha256]\n' >> "${PROVENANCE}"
shasum -a 256 "${OUTPUT_DIR}"/*.deb "${LD64_PATH}" >> "${PROVENANCE}"
printf 'disk_after=%s\n' "$(df -h . | tail -n 1 | tr -s ' ')" >> "${PROVENANCE}"

rm -rf "${EXTRACT_DIR}"
