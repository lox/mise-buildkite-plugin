# mise Buildkite Plugin

Install [mise](https://mise.jdx.dev/), run `mise install`, and export the tool environment into the Buildkite step.

This plugin is intentionally small:

- `mise` is installed if missing or at the wrong version
- `mise install` always runs
- `mise env --shell bash` is always appended to `$BUILDKITE_ENV_FILE`
- tool versions come from the repository, not plugin config

## Example

```yml
steps:
  - label: ":wrench: Test"
    plugins:
      - buildkite-plugins/mise#v1.0.0:
          version: 2026.2.11
    command: go test ./...
```

## Monorepo Example

```yml
steps:
  - label: ":wrench: Test backend"
    plugins:
      - buildkite-plugins/mise#v1.0.0:
          dir: backend
    command: go test ./...
```

## Configuration

- `version` (default: `latest`): mise version to install.
- `dir` (default: checkout directory): directory where `mise install` and `mise env` run.

## Repo Requirements

The target directory must contain one of:

- `mise.toml`
- `.mise.toml`
- `.tool-versions`

Advanced `mise` behavior should be configured with normal step environment variables such as `MISE_DATA_DIR`, `MISE_LOG_LEVEL`, or `MISE_EXPERIMENTAL`, not plugin-specific config keys.

## Development

Run plugin checks locally:

```bash
docker run --rm -v "$PWD:/plugin" -w /plugin buildkite/plugin-linter --id buildkite-plugins/mise --path /plugin
docker run --rm -v "$PWD:/plugin" -w /plugin buildkite/plugin-tester
"$(mise where shellcheck@0.11.0)/shellcheck-v0.11.0/shellcheck" hooks/pre-command tests/pre-command.bats
```
