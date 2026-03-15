#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR
  export BUILDKITE_BUILD_CHECKOUT_PATH="${TEST_TMPDIR}/checkout"
  export BUILDKITE_ENV_FILE="${TEST_TMPDIR}/env"
  export BUILDKITE_PLUGIN_MISE_MISE_DIR="${TEST_TMPDIR}/mise-data"
  export BUILDKITE_PLUGIN_MISE_VERSION="1.0.0"
  export BUILDKITE_PLUGIN_MISE_WORKING_DIRECTORY="${BUILDKITE_BUILD_CHECKOUT_PATH}"
  mkdir -p "${BUILDKITE_BUILD_CHECKOUT_PATH}" "${BUILDKITE_PLUGIN_MISE_MISE_DIR}/bin" "${BUILDKITE_PLUGIN_MISE_MISE_DIR}/shims"

  cat > "${BUILDKITE_PLUGIN_MISE_MISE_DIR}/bin/mise" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
log_file="${MISE_MOCK_LOG:?}"
cmd="${1:-}"
case "${cmd}" in
  --version|version)
    echo "mise v1.0.0"
    ;;
  install)
    echo "install $*" >> "${log_file}"
    ;;
  reshim)
    echo "reshim $*" >> "${log_file}"
    ;;
  env)
    if [ "${2:-}" = "--shell" ] && [ "${3:-}" = "bash" ]; then
      echo "export TEST_ENV=ok"
      echo "export PATH=\"${MISE_DATA_DIR}/installs/go/1.0.0/bin:\$PATH\""
      echo "env $*" >> "${log_file}"
    else
      exit 1
    fi
    ;;
  self-update)
    echo "self-update $*" >> "${log_file}"
    ;;
  *)
    echo "unexpected command: $*" >&2
    exit 1
    ;;
esac
MOCK
  chmod +x "${BUILDKITE_PLUGIN_MISE_MISE_DIR}/bin/mise"

  export MISE_MOCK_LOG="${TEST_TMPDIR}/mise.log"
  : > "${MISE_MOCK_LOG}"

  unset BUILDKITE_PLUGIN_MISE_INSTALL
  unset BUILDKITE_PLUGIN_MISE_RESHIM
  unset BUILDKITE_PLUGIN_MISE_ENV
  unset BUILDKITE_PLUGIN_MISE_INSTALL_ARGS
  unset BUILDKITE_PLUGIN_MISE_TOOL_VERSIONS
  unset BUILDKITE_PLUGIN_MISE_MISE_TOML
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

@test "runs install and exports environment" {
  export BUILDKITE_PLUGIN_MISE_INSTALL="true"
  export BUILDKITE_PLUGIN_MISE_RESHIM="true"
  export BUILDKITE_PLUGIN_MISE_ENV="true"
  export BUILDKITE_PLUGIN_MISE_INSTALL_ARGS="node@20 python@3.12"
  export BUILDKITE_PLUGIN_MISE_TOOL_VERSIONS=$'node 20.18.1\npython 3.12.0'
  export BUILDKITE_PLUGIN_MISE_MISE_TOML=$'[tools]\nnode = "20.18.1"'

  run bash hooks/pre-command

  [ "${status}" -eq 0 ]
  [ -f "${BUILDKITE_BUILD_CHECKOUT_PATH}/.tool-versions" ]
  [ -f "${BUILDKITE_BUILD_CHECKOUT_PATH}/mise.toml" ]
  grep -F 'node 20.18.1' "${BUILDKITE_BUILD_CHECKOUT_PATH}/.tool-versions"
  grep -F 'node = "20.18.1"' "${BUILDKITE_BUILD_CHECKOUT_PATH}/mise.toml"
  grep -F 'install install node@20 python@3.12' "${MISE_MOCK_LOG}"
  grep -F 'reshim reshim -f' "${MISE_MOCK_LOG}"
  grep -F 'export TEST_ENV=ok' "${BUILDKITE_ENV_FILE}"
  grep -F 'export MISE_DATA_DIR=' "${BUILDKITE_ENV_FILE}"
  grep -F 'export PATH=' "${BUILDKITE_ENV_FILE}"
}

@test "skips install and env export when disabled" {
  export BUILDKITE_PLUGIN_MISE_INSTALL="false"
  export BUILDKITE_PLUGIN_MISE_RESHIM="false"
  export BUILDKITE_PLUGIN_MISE_ENV="false"

  run bash hooks/pre-command

  [ "${status}" -eq 0 ]
  if grep -q '^install ' "${MISE_MOCK_LOG}"; then
    echo "install should not be called"
    exit 1
  fi
  if grep -q '^reshim ' "${MISE_MOCK_LOG}"; then
    echo "reshim should not be called"
    exit 1
  fi
  if grep -q '^TEST_ENV=ok$' "${BUILDKITE_ENV_FILE}"; then
    echo "env export should not be called"
    exit 1
  fi
}

@test "installs mise without leaking cleanup trap state" {
  rm -f "${BUILDKITE_PLUGIN_MISE_MISE_DIR}/bin/mise"
  export BUILDKITE_PLUGIN_MISE_INSTALL="false"
  export BUILDKITE_PLUGIN_MISE_ENV="false"
  setup_install_mocks

  run bash hooks/pre-command

  [ "${status}" -eq 0 ]
  [ -x "${BUILDKITE_PLUGIN_MISE_MISE_DIR}/bin/mise" ]
  [[ "${output}" != *"archive: unbound variable"* ]]
}

@test "uses mise tool PATH when shims are disabled" {
  export BUILDKITE_PLUGIN_MISE_INSTALL="false"
  export BUILDKITE_PLUGIN_MISE_ENV="true"
  export BUILDKITE_PLUGIN_MISE_ADD_SHIMS_TO_PATH="false"

  run bash hooks/pre-command

  [ "${status}" -eq 0 ]
  grep -F "export PATH=\"${BUILDKITE_PLUGIN_MISE_MISE_DIR}/installs/go/1.0.0/bin:\$PATH\"" "${BUILDKITE_ENV_FILE}"
  if grep -Fq "${BUILDKITE_PLUGIN_MISE_MISE_DIR}/shims" "${BUILDKITE_ENV_FILE}"; then
    echo "shims path should not be exported when add_shims_to_path=false"
    exit 1
  fi
}
