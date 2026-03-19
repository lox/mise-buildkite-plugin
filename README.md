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

## Monorepo with Selective Tools

In monorepos where different steps need different tools, use `tools` to install only
what each step needs instead of everything in the config file:

```yml
steps:
  - label: ":elixir: Backend"
    plugins:
      - buildkite/mise#v1.1.1:
          dir: apps/backend
          tools:
            - erlang
            - elixir
    command: mix test

  - label: ":react: Frontend"
    plugins:
      - buildkite/mise#v1.1.1:
          dir: apps/frontend
          tools:
            - node
            - pnpm
    command: pnpm test
```

When `tools` is omitted, the existing behavior is preserved — `mise install` runs with no
arguments and installs everything in the config file.

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
- `tools` (default: unset): array of specific tools to install. When omitted, all tools in the config are installed. Passes tool names directly to `mise install`.

## Repo Requirements

The target directory must contain one of:

- `mise.toml`
- `.mise.toml`
- `.tool-versions`

`MISE_DATA_DIR` still takes precedence over plugin configuration. Advanced `mise` behavior should otherwise be configured with normal step environment variables such as `MISE_LOG_LEVEL` or `MISE_EXPERIMENTAL`.

## System Binary Seeding

When the cached mise binary is missing and `mise` is already available on the system PATH
(e.g., baked into a custom agent image), the plugin copies it to the cache directory instead
of downloading from GitHub. The version check still runs — if the seeded binary doesn't match
the requested version, it is replaced by a fresh download. This is a zero-config optimization
that avoids a network request on first run with pre-built agent images.

## Development

Run plugin checks locally:

```bash
mise install
docker run --rm -v "$PWD:/plugin" -w /plugin buildkite/plugin-linter --id buildkite/mise --path /plugin
docker run --rm -v "$PWD:/plugin" -w /plugin buildkite/plugin-tester
"$(mise where shellcheck@0.11.0)/shellcheck-v0.11.0/shellcheck" hooks/pre-command tests/pre-command.bats
```
