# mise Buildkite Plugin

Install [mise](https://mise.jdx.dev/), run `mise install`, and export the tool environment into the Buildkite step.

This plugin is intentionally small:

- `mise` is installed if missing or at the wrong version
- `mise install` always runs
- `mise env --shell bash` is sourced in the hook and appended to `$BUILDKITE_ENV_FILE`
- tool versions come from the repository, not plugin config

## Example

```yml
steps:
  - label: ":wrench: Test"
    plugins:
      - buildkite/mise#v1.1.1:
          version: 2026.2.11
    command: go test ./...
```

## Monorepo Example

```yml
steps:
  - label: ":wrench: Test backend"
    plugins:
      - buildkite/mise#v1.1.1:
          dir: backend
    command: go test ./...
```

## Pre-compiled Tools from Agent Images

On Buildkite hosted agents, the image filesystem and the cache volume are separate mount
points. Tools pre-compiled into the image (e.g., at `/opt/mise/installs/ruby/`) are invisible
to `mise` when `MISE_DATA_DIR` points at the cache volume. Without bridging the two, `mise
install` recompiles from source — even though the compiled binary is already in the image.

`image-installs-dir` solves this by symlinking the image's tool directories into
`MISE_DATA_DIR/installs/` before `mise install` runs:

```yml
steps:
  - label: ":wrench: Test"
    plugins:
      - buildkite/mise#v1.1.1:
          image-installs-dir: /opt/mise/installs
    command: mix test
```

Symlinks (not copies) are used because compiled binaries bake the install prefix into the
binary — copying to a different path breaks them. Tools that are already present in the
installs directory are skipped.

If the directory does not exist (e.g., running the same pipeline on agents without a custom
image), the option is silently ignored.

## Hosted Agent Cache Volumes

```yml
cache: ".buildkite/cache-volume"

steps:
  - label: ":wrench: Test"
    plugins:
      - buildkite/mise#v1.1.1: ~
    command: go test ./...
```

When running on Buildkite hosted agents, the plugin automatically uses `/cache/bkcache/mise` as `MISE_DATA_DIR` if a cache volume is attached. Buildkite only mounts that volume when the pipeline or step defines `cache`, so you still need to request one in `pipeline.yml`.

## Configuration

- `version` (default: `latest`): mise version to install.
- `dir` (default: checkout directory): directory where `mise install` and `mise env` run.
- `cache-dir` (default: unset): directory to use for `MISE_DATA_DIR`. This is mainly useful on self-hosted agents with a persistent disk.
- `image-installs-dir` (default: unset): directory containing pre-compiled tool installs from an agent image (e.g., `/opt/mise/installs`). Tools are symlinked into `MISE_DATA_DIR` to avoid recompilation.

## Repo Requirements

The target directory must contain one of:

- `mise.toml`
- `.mise.toml`
- `.tool-versions`

`MISE_DATA_DIR` still takes precedence over plugin configuration. Advanced `mise` behavior should otherwise be configured with normal step environment variables such as `MISE_LOG_LEVEL` or `MISE_EXPERIMENTAL`.

## Development

Run plugin checks locally:

```bash
mise install
docker run --rm -v "$PWD:/plugin" -w /plugin buildkite/plugin-linter --id buildkite/mise --path /plugin
docker run --rm -v "$PWD:/plugin" -w /plugin buildkite/plugin-tester
"$(mise where shellcheck@0.11.0)/shellcheck-v0.11.0/shellcheck" hooks/pre-command tests/pre-command.bats
```
