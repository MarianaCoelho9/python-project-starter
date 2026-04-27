---
paths:
  - /**/*.py"
---

# Python Standards 

**Ruff handles syntax, style, and many anti-patterns automatically.**
Run:
```bash
uv run ruff check . --fix   # lint + auto-fix (UP, I, E, W, N, B, SIM, S, ...)
uv run ruff format .         # format (indentation, line length, quotes)
```

This file covers only what Ruff cannot detect: design principles, docstring conventions, and error handling patterns.

---

## Design Principles

### Readability First
- Prefer clear, descriptive names over short or clever ones
- Write self-documenting code; add comments only where the logic isn't self-evident

### KISS — Keep It Simple
- Use the simplest solution that correctly handles the requirements
- Avoid over-engineering: no unnecessary abstraction layers, no clever tricks
- Easy to understand beats clever; a future reader should not need to decode your intent

### DRY — Don't Repeat Yourself
- Extract logic used in more than one place into a shared helper
- Never copy-paste code between services; put shared behaviour in `helpers/`

### YAGNI — You Aren't Gonna Need It
- Don't add features, parameters, or abstractions before they are required
- Avoid speculative generality: no optional flags with one code path, no base classes with a single subclass
- Start with the minimal correct implementation; refactor when a real second use case appears

---

## Docstring Standards

- **Controllers** — full Google-style docstring with Args, Returns, and Raises sections
- **Services** — Args and Returns sections only
- **Helpers** — single-line summary

---

## Error Handling

```python
try:
    result = await process_translation(request)
    return result
except ValidationError as e:
    logger.warning(f"Validation error: {str(e)}")
    raise HTTPException(status_code=400, detail=f"Validation failed: {str(e)}")
except Exception:
    logger.exception("Unexpected error")
    raise HTTPException(status_code=500, detail="Internal server error")
```

HTTP status codes: 400 (validation), 422 (business logic), 500 (unexpected), 503 (external service failure).

**EAFP over LBYL** — prefer `try/except` over pre-condition checks:

```python
# Bad
if key in data:
    return data[key]
return default

# Good
try:
    return data[key]
except KeyError:
    return default
```
