# efvibe in CI/CD

This repository demonstrates [efvibe](https://github.com/yeahbah/my-ef-vibe) — an EF Core LINQ REPL and static analyzer — in GitHub Actions.

## Workflow

[`.github/workflows/efvibe.yml`](../.github/workflows/efvibe.yml) runs on every push and pull request to `main`:

1. Starts **SQL Server 2022** as a service container.
2. Creates the **AdventureWorks** database (and attempts **DbUp** migrations when possible).
3. Installs **efvibe** from [`.config/dotnet-tools.json`](../.config/dotnet-tools.json).
4. Runs **`efvibe scan deep`** against `AdventureWorksDbContext`.
5. **Fails the job** when any finding is **critical** or higher (`--fail-on critical` → exit code `1`).

## What `scan deep` exercises

| Feature | CI behavior |
|---------|-------------|
| Static LINQ heuristics | Same rules as `:scan lite` (e.g. `unbounded-materialize`, `untracked-materialize`) |
| `ToQueryString()` | Translated SQL per query call site (live `DbContext`) |
| EXPLAIN / query plan | SQL Server `SET SHOWPLAN_ALL` where translation succeeds |
| Severity gate | `--fail-on critical` stops the pipeline on critical findings |
| Machine-readable output | `--json` → `efvibe-scan-deep.json` + GitHub Step Summary |
| Artifacts | JSON report and session file under `.efvibe-ci/` |

## Local reproduction

```bash
dotnet tool restore

dotnet tool run efvibe -- scan deep \
  -w ./.efvibe-ci \
  -p apps/api-dotnet/src/AdventureWorks.Infrastructure.Persistence/AdventureWorks.Infrastructure.Persistence.csproj \
  -s apps/api-dotnet/src/AdventureWorks.API/AdventureWorks.API.csproj \
  -c AdventureWorksDbContext \
  -f net10.0 \
  --provider sqlserver \
  --connection-string "Server=localhost,1433;Database=AdventureWorks;User Id=sa;Password=YOUR_PASSWORD;Encrypt=false;TrustServerCertificate=true" \
  --fail-on critical \
  --json
```

Faster static-only gate (no database):

```bash
dotnet tool run efvibe -- scan lite \
  -p apps/api-dotnet/src/AdventureWorks.Infrastructure.Persistence/AdventureWorks.Infrastructure.Persistence.csproj \
  -s apps/api-dotnet/src/AdventureWorks.API/AdventureWorks.API.csproj \
  --fail-on critical
```

## Expected CI result

AdventureWorks contains many repository queries that materialize without `Take()` — the scanner reports them as **critical** (`unbounded-materialize`). Until those are fixed, dismissed in a REPL session (`--respect-dismissals`), or the gate is relaxed (e.g. `--fail-on error`), **this workflow is expected to fail** — that is the showcase: the gate blocks merges when LINQ risk is detected.

To pass CI while iterating:

- Fix queries (add `Take`, `AsNoTracking`, narrower `Select`), or
- Lower the gate: `--fail-on error` or `--min-severity warning` (not used in this repo’s workflow).

## Configuration

| File | Purpose |
|------|---------|
| `apps/api-dotnet/src/AdventureWorks.API/appsettings.CI.json` | Connection string when `ASPNETCORE_ENVIRONMENT=CI` |
| `database/dbup/AdventureWorks.DbUp/appsettings.CI.json` | DbUp target for the CI SQL instance |
| `.config/dotnet-tools.json` | Pinned `efvibe` tool version |
