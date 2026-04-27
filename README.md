# Python Project Starter

Python project starter kit: bootstrap new projects with uv, Ruff, mypy, pre-commit, GitHub Actions CI, and reusable Claude templates/rules.

Reusable starter kit to bootstrap Python projects with:
- `uv` package/environment management
- `ruff` formatter + linter
- `mypy` type checks
- `pre-commit` hooks
- optional GitHub Actions CI
- Claude files (`claude.md` at root + `.claude/` folders/rules)

## Requirements

- `git`
- `uv`

## Quick Start

```bash
# 1) Clone this starter repo
git clone https://github.com/<your-user>/python-project-starter.git
cd python-project-starter
chmod +x bootstrap.sh

# 2) Bootstrap a target project directory
./bootstrap.sh --target-dir /path/to/my-project --with-github-workflows
```

## Use Your Templates

```bash
./bootstrap.sh \
  --target-dir /path/to/my-project \
  --claude-template ./templates/claude.md \
  --claude-rules-dir ./templates/rules \
  --with-github-workflows
```

## Common Options

```bash
./bootstrap.sh --help
```

Key flags:
- `--target-dir <path>`: initialize a different project folder
- `--project-name <name>`: override generated project name
- `--python-version <version>`: default `3.14`
- `--with-github-workflows`: adds `.github/workflows/ci.yml`
- `--with-pre-commit` / `--without-pre-commit`
- `--force`: overwrite managed files
- `--claude-template <path>`
- `--claude-rules-dir <path>`
- `--claude-rule-file <path>`
