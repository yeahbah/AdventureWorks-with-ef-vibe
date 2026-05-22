<p align="center"><img width=128 height=128 src="https://github.com/theMickster/AdventureWorks/blob/main/_media/AdventureWorksIconBlue01.png"></p>

# AdventureWorks-with-ef-vibe

A fork of [AdventureWorks](https://github.com/theMickster/AdventureWorks) used as a **reference application** for [**efvibe**](https://github.com/yeahbah/my-ef-vibe) — a .NET global tool that inspects EF Core LINQ, translates queries to SQL, and runs execution plans from the terminal or CI.

This repository is not a separate product. It exists to show how a real Clean Architecture codebase (hundreds of repository queries, multiple `DbContext` patterns, SQL Server) can be checked automatically on every pull request.

[![efvibe LINQ scan](https://github.com/yeahbah/AdventureWorks-with-ef-vibe/actions/workflows/efvibe.yml/badge.svg)](https://github.com/yeahbah/AdventureWorks-with-ef-vibe/actions/workflows/efvibe.yml)

## What we are trying to do

**Goal:** Prove that efvibe fits into a normal GitHub Actions pipeline the same way unit tests or analyzers do — without running the full API or hitting every endpoint.

On each push and PR to `main`, CI:

1. Spins up **SQL Server** and creates the **AdventureWorks** database.
2. Runs **`efvibe scan deep`** against `AdventureWorksDbContext` and the persistence layer.
3. For each LINQ query call site, attempts **static rules**, **`ToQueryString()`**, and **`EXPLAIN`** (SQL Server showplan).
4. **Fails the workflow** when any finding is **critical** (`--fail-on critical`).

That last step is intentional. AdventureWorks has many queries that call `ToListAsync()` / `ToArrayAsync()` without `Take()` — efvibe flags them as **`unbounded-materialize` (critical)**. The showcase demonstrates the **gate**: the pipeline stops so teams must fix, dismiss, or relax the threshold before merging.

Lower-severity findings (`info`, `warning`) are filtered out of the CI report when `--fail-on critical` is set, so logs stay focused on what blocked the build.

| Concern | How this repo addresses it |
|--------|-----------------------------|
| “Can it run headless?” | Yes — `efvibe scan deep` (no REPL) |
| “Does it need our running API?” | No — builds the EF project and uses `--connection-string` |
| “Can we fail the build on bad LINQ?” | Yes — `--fail-on critical` → exit code `1` |
| “Can we get artifacts for review?” | Yes — JSON report, GitHub Step Summary, `myefvibe-scan-deep.json` |

Full CI details: [`docs/efvibe-ci.md`](docs/efvibe-ci.md) · Workflow: [`.github/workflows/efvibe.yml`](.github/workflows/efvibe.yml)

## Run the scan locally

```bash
dotnet tool restore   # efvibe 0.1.47 (see .config/dotnet-tools.json)

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

Static-only (no database):

```bash
dotnet tool run efvibe -- scan lite \
  -p apps/api-dotnet/src/AdventureWorks.Infrastructure.Persistence/AdventureWorks.Infrastructure.Persistence.csproj \
  -s apps/api-dotnet/src/AdventureWorks.API/AdventureWorks.API.csproj \
  --fail-on critical
```

## About the application

Adventure Works is a modern enterprise sample built with **.NET 10**, **Angular 21**, **Entity Framework Core**, and **Tailwind CSS + DaisyUI**. The backend follows **Clean Architecture** with **CQRS** (MediatR), backed by the classic Adventure Works Cycling SQL schema (with project-specific enhancements via DbUp).

| Layer             | Technology                                       |
| ----------------- | ------------------------------------------------ |
| **Backend API**   | .NET 10 (Clean Architecture + CQRS + MediatR)    |
| **Frontend**      | Angular 21 + Nx 22 monorepo (Signals, zoneless)  |
| **Design System** | Alpine Circuit v2 (Tailwind CSS v4 + DaisyUI v5) |
| **Database**      | SQL Server + Entity Framework Core               |
| **Testing**       | xUnit, Vitest, Playwright                        |

Upstream app development and features live in [theMickster/AdventureWorks](https://github.com/theMickster/AdventureWorks). This fork tracks that codebase and adds the efvibe CI workflow.

### Prerequisites

- [.NET 10 SDK](https://dotnet.microsoft.com/download) (see `global.json`)
- [Node.js 22+](https://nodejs.org/) for the Angular workspace
- [SQL Server](https://www.microsoft.com/en-us/sql-server/) (local or Docker) for API and deep scan

### Quick start (application)

```bash
# Backend API
cd apps/api-dotnet
dotnet restore && dotnet run --project src/AdventureWorks.API

# Frontend (separate terminal)
cd apps/angular-web
npm install && npx nx serve adventureworks-web
```

### Project structure

```
AdventureWorks-with-ef-vibe/
├── .github/workflows/
│   ├── efvibe.yml              # LINQ scan showcase (this repo’s focus)
│   └── pr-validation.yml       # DbUp, API tests, Angular
├── apps/
│   ├── api-dotnet/             # .NET 10 REST API
│   └── angular-web/            # Angular 21 SPA
├── database/
│   └── dbup/                   # SQL Server migrations
├── docs/
│   └── efvibe-ci.md            # CI/CD documentation
└── .config/dotnet-tools.json   # Pinned efvibe 0.1.47 (local + CI)
```

### Database enhancements

Schema changes relative to classic AdventureWorks are documented here:

- [DbUp README](database/dbup/AdventureWorks.DbUp/README.md)

## Related links

- [efvibe (my-ef-vibe)](https://github.com/yeahbah/my-ef-vibe) — tool source, REPL, scan rules
- [LINQ scan rules](https://github.com/yeahbah/my-ef-vibe/blob/main/docs/linq-scan-rules.md) — rule ids and severities
- [Original AdventureWorks](https://github.com/theMickster/AdventureWorks)

## License

This project is licensed under the MIT License.
