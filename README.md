# mise Buildkite Plugin

Small Buildkite plugin to install and configure [mise](https://mise.jdx.dev/) for a step, with a configuration shape inspired by
[`jdx/mise-action`](https://github.com/jdx/mise-action) and hook simplicity inspired by
[`elastic/hermit-buildkite-plugin`](https://github.com/elastic/hermit-buildkite-plugin).

## Example

```yml
steps:
  - label: ":wrench: Test"
    plugins:
      - buildkite-plugins/mise#v1.0.0:
          version: 2025.10.2
          install: true
          install_args: "node@20 python@3.12"
          tool_versions: |
            node 20.18.1
            python 3.12.0
          log_level: info
          reshim: false
    command: node --version
```

## Configuration

Configuration keys are read from the plugin block and made available as `BUILDKITE_PLUGIN_MISE_*` environment variables.

### Inputs

- `version` (default: latest): mise version string (e.g. `2025.10.2`).
- `sha256` (default: unset): checksum used to verify downloaded mise archive.
- `mise_dir` (default: resolved from `MISE_DATA_DIR` / `$XDG_DATA_HOME/mise` / `~/.local/share/mise`): mise data directory.
- `working_directory` (default: step checkout dir): directory where `mise install` runs.
- `tool_versions` (default: unset): content written to `.tool-versions`.
- `mise_toml` (default: unset): content written to `mise.toml`.
- `install` (default: true): run `mise install`.
- `install_args` (default: unset): additional args for `mise install`.
- `experimental` (default: false): sets `MISE_EXPERIMENTAL=1`.
- `log_level` (default: unset): sets `MISE_LOG_LEVEL`.
- `reshim` (default: false): run `mise reshim -f`.
- `add_shims_to_path` (default: true): prepend `${mise_dir}/shims` to `PATH`.
- `github_token` (default: unset): sets `MISE_GITHUB_TOKEN`.
- `env` (default: true): append output from `mise env --dotenv` to `$BUILDKITE_ENV_FILE`.

## Notes

- This implementation mirrors GitHub Action behavior where practical for Buildkite: install/setup and optional `mise install`, then export env into Buildkite step scope.
- Windows (`win32`) is not currently supported.
- Caching is intentionally not included in this first version.

## Development

Run plugin checks locally:

```bash
docker run --rm -v "$PWD:/plugin" -w /plugin buildkite/plugin-linter --id buildkite-plugins/mise --path /plugin
docker run --rm -v "$PWD:/plugin" -w /plugin buildkite/plugin-tester
shellcheck hooks/pre-command
```
