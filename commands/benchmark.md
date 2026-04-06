# Benchmark — Performance Measurement

Measure and compare performance before and after changes.

## Usage

```
/benchmark                         # Benchmark current state
/benchmark before                  # Save baseline
/benchmark after                   # Compare with baseline
/benchmark <url>                   # Benchmark specific URL
```

## Workflow

### Action: before (save baseline)

Capture current performance metrics and save:

```bash
mkdir -p .claude/benchmarks
```

**For web pages:**
```
playwright-cli open "<url>"
# Measure: page load time, DOM content loaded, first paint
playwright-cli evaluate "JSON.stringify(performance.timing)"
playwright-cli evaluate "JSON.stringify(performance.getEntriesByType('resource').length)"
```

**For code/API:**
```bash
# Build time
time pnpm run build

# Test time
time pnpm run test:unit

# Bundle size
du -sh dist/
```

Save to `.claude/benchmarks/baseline.json`:
```json
{
  "timestamp": "2026-04-06T10:00:00Z",
  "branch": "develop",
  "metrics": {
    "build_time_s": 12.3,
    "test_time_s": 8.1,
    "bundle_size_kb": 450,
    "page_load_ms": 1200,
    "dom_ready_ms": 800
  }
}
```

### Action: after (compare)

Run the same measurements and compare:

```
## Performance Comparison

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Build time | 12.3s | 11.8s | -0.5s (4% faster) |
| Test time | 8.1s | 8.3s | +0.2s (2% slower) |
| Bundle size | 450kb | 445kb | -5kb (1% smaller) |
| Page load | 1200ms | 980ms | -220ms (18% faster) |

Verdict: IMPROVED / REGRESSED / NEUTRAL
```

### Action: default (one-time measurement)

Run metrics once and report without comparison.

## Core Web Vitals (for web)

If measuring web pages, include:
- **LCP** (Largest Contentful Paint) — target < 2.5s
- **FID** (First Input Delay) — target < 100ms
- **CLS** (Cumulative Layout Shift) — target < 0.1

## Rules

- Always measure before AND after for meaningful comparison
- Run measurements multiple times and average (reduce noise)
- Report absolute numbers AND percentages
- Flag any regression > 10% as a concern
