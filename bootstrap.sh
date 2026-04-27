#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME=""
PROJECT_SLUG=""
PYTHON_VERSION="3.14"
WITH_GITHUB_WORKFLOWS="false"
WITH_GITHUB_REPO="false"
GITHUB_REPO_NAME=""
GITHUB_OWNER=""
GITHUB_VISIBILITY="private"
FORCE="false"
TARGET_DIR="."
CLAUDE_TEMPLATE=""
CLAUDE_RULES_DIR=""
CLAUDE_RULE_FILE=""
WITH_PRECOMMIT="true"
WITH_PYTEST="false"

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<USAGE
Usage: ./$SCRIPT_NAME [options]

Options:
  --project-name <name>         Project name to use in metadata and README title
  --target-dir <path>           Directory to initialize (default: current directory)
  --python-version <version>    Python version for uv and tool config (default: 3.14)
  --with-github-workflows       Generate GitHub Actions workflow under .github/workflows
  --with-github-repo            Create and push a GitHub repo via gh (optional)
  --github-repo-name <name>     GitHub repo name (default: project slug)
  --github-owner <owner>        GitHub owner/org (optional, defaults to gh auth user)
  --github-visibility <type>    private or public (default: private)
  --with-pre-commit             Configure and install pre-commit hooks (default: enabled)
  --without-pre-commit          Skip pre-commit setup
  --with-pytest                 Add pytest dependency, tests scaffold, and CI test step
  --without-pytest              Skip pytest scaffold (default)
  --force                       Overwrite existing managed files
  --claude-template <path>      Path to custom claude.md template to copy into ./claude.md
  --claude-rules-dir <path>     Path to directory with custom Claude rules copied into .claude/rules/
  --claude-rule-file <path>     Path to a single Claude rule markdown file copied into .claude/rules/
  -h, --help                    Show this help message
USAGE
}

log() {
  printf '[bootstrap] %s\n' "$1"
}

warn() {
  printf '[bootstrap][warn] %s\n' "$1" >&2
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf '[bootstrap][error] Missing required command: %s\n' "$cmd" >&2
    exit 1
  fi
}

write_file() {
  local destination="$1"
  local content="$2"

  if [[ -e "$destination" && "$FORCE" != "true" ]]; then
    warn "Skipping existing file: $destination (use --force to overwrite)"
    return
  fi

  printf '%s\n' "$content" > "$destination"
  log "Wrote $destination"
}

copy_file() {
  local source="$1"
  local destination="$2"

  if [[ ! -f "$source" ]]; then
    printf '[bootstrap][error] File not found: %s\n' "$source" >&2
    exit 1
  fi

  if [[ -e "$destination" && "$FORCE" != "true" ]]; then
    warn "Skipping existing file: $destination (use --force to overwrite)"
    return
  fi

  cp "$source" "$destination"
  log "Copied $source -> $destination"
}

absolute_path() {
  local path_value="$1"
  if [[ -d "$path_value" ]]; then
    (
      cd "$path_value"
      pwd
    )
    return
  fi

  local dir_part
  dir_part="$(dirname "$path_value")"
  local file_part
  file_part="$(basename "$path_value")"

  (
    cd "$dir_part"
    printf '%s/%s\n' "$(pwd)" "$file_part"
  )
}

copy_dir_contents() {
  local source_dir="$1"
  local destination_dir="$2"

  if [[ ! -d "$source_dir" ]]; then
    printf '[bootstrap][error] Directory not found: %s\n' "$source_dir" >&2
    exit 1
  fi

  mkdir -p "$destination_dir"

  local copied_any="false"
  while IFS= read -r -d '' source_path; do
    copied_any="true"
    local relative_path="${source_path#"$source_dir"/}"
    local destination_path="$destination_dir/$relative_path"
    mkdir -p "$(dirname "$destination_path")"

    if [[ -e "$destination_path" && "$FORCE" != "true" ]]; then
      warn "Skipping existing file: $destination_path (use --force to overwrite)"
      continue
    fi

    cp "$source_path" "$destination_path"
    log "Copied $source_path -> $destination_path"
  done < <(find "$source_dir" -type f -print0)

  if [[ "$copied_any" != "true" ]]; then
    warn "No files found in directory: $source_dir"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project-name)
        PROJECT_NAME="${2:-}"
        shift 2
        ;;
      --target-dir)
        TARGET_DIR="${2:-}"
        shift 2
        ;;
      --python-version)
        PYTHON_VERSION="${2:-}"
        shift 2
        ;;
      --with-github-workflows)
        WITH_GITHUB_WORKFLOWS="true"
        shift
        ;;
      --with-github-repo)
        WITH_GITHUB_REPO="true"
        shift
        ;;
      --github-repo-name)
        GITHUB_REPO_NAME="${2:-}"
        shift 2
        ;;
      --github-owner)
        GITHUB_OWNER="${2:-}"
        shift 2
        ;;
      --github-visibility)
        GITHUB_VISIBILITY="${2:-}"
        shift 2
        ;;
      --with-pre-commit)
        WITH_PRECOMMIT="true"
        shift
        ;;
      --without-pre-commit)
        WITH_PRECOMMIT="false"
        shift
        ;;
      --with-pytest)
        WITH_PYTEST="true"
        shift
        ;;
      --without-pytest)
        WITH_PYTEST="false"
        shift
        ;;
      --force)
        FORCE="true"
        shift
        ;;
      --claude-template)
        CLAUDE_TEMPLATE="${2:-}"
        shift 2
        ;;
      --claude-rules-dir)
        CLAUDE_RULES_DIR="${2:-}"
        shift 2
        ;;
      --claude-rule-file)
        CLAUDE_RULE_FILE="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        printf '[bootstrap][error] Unknown option: %s\n' "$1" >&2
        usage
        exit 1
        ;;
    esac
  done
}

validate_inputs() {
  require_cmd uv
  require_cmd git
  if [[ "$WITH_GITHUB_REPO" == "true" ]]; then
    require_cmd gh
  fi

  TARGET_DIR="$(absolute_path "$TARGET_DIR")"
  mkdir -p "$TARGET_DIR"

  if [[ -n "$CLAUDE_TEMPLATE" ]]; then
    CLAUDE_TEMPLATE="$(absolute_path "$CLAUDE_TEMPLATE")"
  fi

  if [[ -n "$CLAUDE_RULES_DIR" ]]; then
    CLAUDE_RULES_DIR="$(absolute_path "$CLAUDE_RULES_DIR")"
  fi

  if [[ -n "$CLAUDE_RULE_FILE" ]]; then
    CLAUDE_RULE_FILE="$(absolute_path "$CLAUDE_RULE_FILE")"
  fi

  if [[ -z "$PROJECT_NAME" ]]; then
    PROJECT_NAME="$(basename "$TARGET_DIR")"
  fi

  PROJECT_SLUG="$(printf '%s' "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//')"
  if [[ -z "$PROJECT_SLUG" ]]; then
    PROJECT_SLUG="python-project"
  fi

  if [[ -z "$GITHUB_REPO_NAME" ]]; then
    GITHUB_REPO_NAME="$PROJECT_SLUG"
  fi

  if [[ "$GITHUB_VISIBILITY" != "private" && "$GITHUB_VISIBILITY" != "public" ]]; then
    printf '[bootstrap][error] --github-visibility must be "private" or "public"\n' >&2
    exit 1
  fi

  if [[ -n "$CLAUDE_TEMPLATE" && ! -f "$CLAUDE_TEMPLATE" ]]; then
    printf '[bootstrap][error] --claude-template file not found: %s\n' "$CLAUDE_TEMPLATE" >&2
    exit 1
  fi

  if [[ -n "$CLAUDE_RULES_DIR" && ! -d "$CLAUDE_RULES_DIR" ]]; then
    printf '[bootstrap][error] --claude-rules-dir directory not found: %s\n' "$CLAUDE_RULES_DIR" >&2
    exit 1
  fi

  if [[ -n "$CLAUDE_RULE_FILE" && ! -f "$CLAUDE_RULE_FILE" ]]; then
    printf '[bootstrap][error] --claude-rule-file file not found: %s\n' "$CLAUDE_RULE_FILE" >&2
    exit 1
  fi
}

ensure_uv_project() {
  uv python pin "$PYTHON_VERSION" >/dev/null
  log "Pinned Python version to $PYTHON_VERSION"

  uv sync --dev >/dev/null
  log "Created/updated virtual environment"
}

write_main_file() {
  local content
  content=$(cat <<'PY'
"""Entry point for the project."""


def main() -> None:
    """Run the starter application."""
    print("Hello from your uv-managed Python project!")


if __name__ == "__main__":
    main()
PY
)
  write_file "main.py" "$content"
}

write_readme() {
  local testing_section=""
  if [[ "$WITH_PYTEST" == "true" ]]; then
    testing_section=$(cat <<'TXT'

## Run Tests

```bash
uv run pytest
```
TXT
)
  fi

  local content
  content=$(cat <<EOF2
# $PROJECT_NAME

A Python project bootstrapped with:
- [uv](https://github.com/astral-sh/uv) for environment and package management
- [ruff](https://docs.astral.sh/ruff/) for formatting and linting
- [mypy](https://mypy.readthedocs.io/) for static type checking

## Getting Started

\`\`\`bash
uv sync
uv run python main.py
\`\`\`

## Development Checks

\`\`\`bash
uv run ruff format .
uv run ruff check .
uv run mypy .
\`\`\`
$testing_section
EOF2
)
  write_file "README.md" "$content"
}

write_gitignore() {
  local content
  content=$(cat <<'TXT'
.venv/
__pycache__/
*.py[cod]
.mypy_cache/
.ruff_cache/
.pytest_cache/
.DS_Store
TXT
)
  write_file ".gitignore" "$content"
}

write_pyproject() {
  local pytest_dep=""
  if [[ "$WITH_PYTEST" == "true" ]]; then
    pytest_dep='  "pytest",'
  fi

  local content
  content=$(cat <<EOF2
[project]
name = "${PROJECT_SLUG}"
version = "0.1.0"
description = ""
readme = "README.md"
requires-python = ">=${PYTHON_VERSION}"
dependencies = []

[dependency-groups]
dev = [
  "ruff",
  "mypy",
  "pre-commit",
$pytest_dep
]

[tool.ruff]
target-version = "py${PYTHON_VERSION//./}"
line-length = 100

[tool.ruff.lint]
select = ["E", "F", "I", "UP"]

[tool.ruff.format]
quote-style = "double"
indent-style = "space"

[tool.mypy]
python_version = "${PYTHON_VERSION}"
strict = false
warn_unused_configs = true
disallow_untyped_defs = true
check_untyped_defs = true
no_implicit_optional = true
warn_return_any = true
warn_redundant_casts = true
warn_unused_ignores = true
warn_unreachable = true
pretty = true
show_error_codes = true
EOF2
)
  write_file "pyproject.toml" "$content"
}

setup_pytest() {
  if [[ "$WITH_PYTEST" != "true" ]]; then
    return
  fi

  mkdir -p tests
  local test_content
  test_content=$(cat <<'PY'
"""Basic tests for the starter app."""

import subprocess
import sys


def test_main_script_runs() -> None:
    """Ensure the starter entry point executes and prints the expected message."""
    result = subprocess.run(
        [sys.executable, "main.py"],
        capture_output=True,
        check=True,
        text=True,
    )
    assert result.stdout.strip() == "Hello from your uv-managed Python project!"
PY
)
  write_file "tests/test_main.py" "$test_content"
}

setup_claude() {
  mkdir -p .claude/skills .claude/agents .claude/commands .claude/rules
  log "Ensured .claude directory structure"

  if [[ -n "$CLAUDE_TEMPLATE" ]]; then
    copy_file "$CLAUDE_TEMPLATE" "claude.md"
  else
    local claude_content
    claude_content=$(cat <<'TXT'
# Claude Project Instructions

## Project Context
- Keep solutions simple and maintainable.
- Favor explicit typing and readable code.

## Coding Standards
- Use Ruff for linting and formatting.
- Use mypy for static type checking.
- Add tests for behavior changes.

## Collaboration
- Explain tradeoffs briefly in PR descriptions.
- Prefer small, focused commits.
TXT
)
    write_file "claude.md" "$claude_content"
  fi

  local skills_readme
  skills_readme=$(cat <<'TXT'
# Skills

Store reusable skill prompts and task recipes here.
TXT
)
  write_file ".claude/skills/README.md" "$skills_readme"

  local agents_readme
  agents_readme=$(cat <<'TXT'
# Agents

Store specialized agent definitions or instructions here.
TXT
)
  write_file ".claude/agents/README.md" "$agents_readme"

  local commands_readme
  commands_readme=$(cat <<'TXT'
# Commands

Store reusable command snippets or workflows here.
TXT
)
  write_file ".claude/commands/README.md" "$commands_readme"

  local rules_readme
  rules_readme=$(cat <<'TXT'
# Rules

Place custom Claude rule files in this directory.
TXT
)
  write_file ".claude/rules/README.md" "$rules_readme"

  if [[ -n "$CLAUDE_RULES_DIR" ]]; then
    copy_dir_contents "$CLAUDE_RULES_DIR" ".claude/rules"
  fi

  if [[ -n "$CLAUDE_RULE_FILE" ]]; then
    copy_file "$CLAUDE_RULE_FILE" ".claude/rules/$(basename "$CLAUDE_RULE_FILE")"
  fi
}

setup_precommit() {
  if [[ "$WITH_PRECOMMIT" != "true" ]]; then
    return
  fi

  local config
  config=$(cat <<'YAML'
repos:
  - repo: local
    hooks:
      - id: ruff-format
        name: Ruff format
        entry: uv run ruff format
        language: system
        types_or: [python]
      - id: ruff-check
        name: Ruff lint
        entry: uv run ruff check --fix
        language: system
        types_or: [python]
      - id: mypy
        name: Mypy
        entry: uv run mypy .
        language: system
        pass_filenames: false
YAML
)
  write_file ".pre-commit-config.yaml" "$config"

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    uv run pre-commit install >/dev/null
    log "Installed pre-commit hooks"
  else
    warn "Skipped pre-commit hook install (not a git repository yet)."
    warn "Run 'uv run pre-commit install' after initializing git."
  fi
}

write_editorconfig() {
  local content
  content=$(cat <<'TXT'
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
indent_style = space
indent_size = 4
trim_trailing_whitespace = true

[*.md]
trim_trailing_whitespace = false
TXT
)
  write_file ".editorconfig" "$content"
}

setup_github_workflow() {
  if [[ "$WITH_GITHUB_WORKFLOWS" != "true" ]]; then
    return
  fi

  mkdir -p .github/workflows

  local ci_workflow
  ci_workflow=$(cat <<'YAML'
name: CI

on:
  push:
    branches: ["**"]
  pull_request:

jobs:
  lint-typecheck:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install uv
        uses: astral-sh/setup-uv@v6

      - name: Set up Python
        run: uv python install

      - name: Sync deps
        run: uv sync --all-extras --dev

      - name: Ruff format check
        run: uv run ruff format --check .

      - name: Ruff lint
        run: uv run ruff check .

      - name: Mypy
        run: uv run mypy .
YAML
)

  if [[ "$WITH_PYTEST" == "true" ]]; then
    ci_workflow+=$'\n\n      - name: Pytest\n        run: uv run pytest\n'
  fi

  write_file ".github/workflows/ci.yml" "$ci_workflow"
}

setup_github_repo() {
  if [[ "$WITH_GITHUB_REPO" != "true" ]]; then
    return
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git init >/dev/null
    log "Initialized git repository"
  fi

  git add .
  if ! git diff --cached --quiet; then
    if ! git commit -m "Bootstrap project" >/dev/null 2>&1; then
      warn "Could not create git commit automatically. Check git user.name/user.email."
    else
      log "Created initial commit"
    fi
  fi
  git branch -M main

  if git remote get-url origin >/dev/null 2>&1; then
    warn "Remote 'origin' already exists. Skipping gh repo create."
    return
  fi

  local repo_ref="$GITHUB_REPO_NAME"
  if [[ -n "$GITHUB_OWNER" ]]; then
    repo_ref="$GITHUB_OWNER/$GITHUB_REPO_NAME"
  fi

  gh repo create "$repo_ref" "--$GITHUB_VISIBILITY" --source=. --remote=origin --push >/dev/null
  log "Created and pushed GitHub repository: $repo_ref"
}

print_next_steps() {
  cat <<EOF2

Bootstrap complete.

Next steps:
  1. uv run python main.py
  2. uv run ruff check .
  3. uv run mypy .
  4. uv run pre-commit run --all-files
  5. uv run pytest (if --with-pytest was used)
  6. git add . && git commit -m "Bootstrap project"
EOF2
}

main() {
  parse_args "$@"
  validate_inputs
  cd "$TARGET_DIR"
  log "Initializing project in $(pwd)"
  write_pyproject
  ensure_uv_project
  write_main_file
  write_readme
  write_gitignore
  write_editorconfig
  setup_claude
  setup_pytest
  setup_precommit
  setup_github_workflow
  setup_github_repo
  print_next_steps
}

main "$@"
