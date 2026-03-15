#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR
  export BUILDKITE_BUILD_CHECKOUT_PATH="${TEST_TMPDIR}/checkout"
  export BUILDKITE_ENV_FILE="${TEST_TMPDIR}/env"
  export MISE_DATA_DIR="${TEST_TMPDIR}/mise-data"
  export BUILDKITE_PLUGIN_MISE_VERSION="1.0.0"

  mkdir -p "${BUILDKITE_BUILD_CHECKOUT_PATH}" "${MISE_DATA_DIR}/bin" "${MISE_DATA_DIR}/shims"

  cat > "${MISE_DATA_DIR}/bin/mise" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

log_file="${MISE_MOCK_LOG:?}"
cmd="${1:-}"

case "${cmd}" in
  --version|version)
    echo "mise v1.0.0"
    ;;
  install)
    echo "install pwd=${PWD} $*" >> "${log_file}"
    ;;
  env)
    if [ "${2:-}" = "--shell" ] && [ "${3:-}" = "bash" ]; then
      echo "export TEST_ENV=ok"
      echo "export PATH=\"${MISE_DATA_DIR}/installs/go/1.0.0/bin:\$PATH\""
      echo "env pwd=${PWD} $*" >> "${log_file}"
    else
      exit 1
    fi
    ;;
  *)
    echo "unexpected command: $*" >&2
    exit 1
    ;;
esac
MOCK
  chmod +x "${MISE_DATA_DIR}/bin/mise"

  export MISE_MOCK_LOG="${TEST_TMPDIR}/mise.log"
  : > "${MISE_MOCK_LOG}"

  unset BUILDKITE_PLUGIN_MISE_DIR
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

setup_install_mocks() {
  mkdir -p "${TEST_TMPDIR}/mock-bin"
  export PATH="${TEST_TMPDIR}/mock-bin:${PATH}"

  cat > "${TEST_TMPDIR}/mock-bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'mock archive'
MOCK

  cat > "${TEST_TMPDIR}/mock-bin/tar" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

dest=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -C)
      dest="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

mkdir -p "${dest}/mise/bin"
cat > "${dest}/mise/bin/mise" <<'INNER'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  --version|version)
    echo "mise v1.0.0"
    ;;
  install)
    ;;
  env)
    if [ "${2:-}" = "--shell" ] && [ "${3:-}" = "bash" ]; then
      echo "export PATH=\"${MISE_DATA_DIR}/installs/go/1.0.0/bin:\$PATH\""
    else
      exit 1
    fi
    ;;
  *)
    echo "unexpected installed command: $*" >&2
    exit 1
    ;;
esac
INNER
chmod +x "${dest}/mise/bin/mise"
MOCK

  chmod +x "${TEST_TMPDIR}/mock-bin/curl" "${TEST_TMPDIR}/mock-bin/tar"
}

@test "runs install and exports shell environment from repo config" {
  printf 'go 1.0.0\n' > "${BUILDKITE_BUILD_CHECKOUT_PATH}/.tool-versions"

  run bash hooks/pre-command

  [ "${status}" -eq 0 ]
  grep -F "install pwd=${BUILDKITE_BUILD_CHECKOUT_PATH} install" "${MISE_MOCK_LOG}"
  grep -F "env pwd=${BUILDKITE_BUILD_CHECKOUT_PATH} env --shell bash" "${MISE_MOCK_LOG}"
  grep -F "export TEST_ENV=ok" "${BUILDKITE_ENV_FILE}"
  grep -F "export PATH=\"${MISE_DATA_DIR}/installs/go/1.0.0/bin:\$PATH\"" "${BUILDKITE_ENV_FILE}"
}

@test "uses dir config for monorepos" {
  subdir="${BUILDKITE_BUILD_CHECKOUT_PATH}/backend"
  mkdir -p "${subdir}"
  printf 'go 1.0.0\n' > "${subdir}/.tool-versions"
  export BUILDKITE_PLUGIN_MISE_DIR="${subdir}"

  run bash hooks/pre-command

  [ "${status}" -eq 0 ]
  grep -F "install pwd=${subdir} install" "${MISE_MOCK_LOG}"
  grep -F "env pwd=${subdir} env --shell bash" "${MISE_MOCK_LOG}"
}

@test "fails when no mise config exists" {
  run bash hooks/pre-command

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"No mise config found in"* ]]
}

@test "installs mise without leaking cleanup trap state" {
  printf 'go 1.0.0\n' > "${BUILDKITE_BUILD_CHECKOUT_PATH}/.tool-versions"
  rm -f "${MISE_DATA_DIR}/bin/mise"
  setup_install_mocks

  run bash hooks/pre-command

  [ "${status}" -eq 0 ]
  [ -x "${MISE_DATA_DIR}/bin/mise" ]
  [[ "${output}" != *"archive: unbound variable"* ]]
}
