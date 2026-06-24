# Thesis Reader MVP

Thesis Reader is an MVP monorepo for academic PDF reading experiments. This branch contains the main building blocks for a Flutter reader app, a shared document package contract, and a FastAPI converter service, but the top-level Flutter app shell is not yet a complete end-to-end product flow.

Current app work is best understood as component and service slices: library/import status screens, reader rendering controls, AI service clients, vocabulary persistence repositories, document package parsing, and server/on-device conversion orchestration. The default app shell still launches mostly unbound screens, so import, conversion, package loading, AI actions, vocabulary capture, and progress persistence need integration work before a tester can complete the whole workflow from one UI session.

The repository is a small monorepo:

- `apps/thesis_reader`: Flutter app for desktop/mobile reader workflows.
- `packages/document_contract`: shared Dart package for the document package contract.
- `services/converter`: FastAPI PDF converter that emits cached document packages.
- `docs/contracts`: JSON schema for the converter package format.
- `docs/testing/manual-mvp-checklist.md`: component/service verification checklist for the current MVP branch.

## Local Development

Install Flutter dependencies:

```powershell
cd apps/thesis_reader
flutter pub get
```

Run the app:

```powershell
cd apps/thesis_reader
flutter run
```

Run app checks:

```powershell
cd apps/thesis_reader
flutter test
flutter analyze
```

Run document contract checks:

```powershell
cd packages/document_contract
flutter test
```

Create or refresh the converter virtual environment from the repo root:

```powershell
python -m venv services/converter/.venv
services/converter/.venv/Scripts/python -m pip install -r services/converter/requirements.txt
```

Run the converter locally from the repo root so `services.converter...` imports resolve:

```powershell
services/converter/.venv/Scripts/python -m uvicorn services.converter.app.main:app --host 0.0.0.0 --port 8000
```

Run converter tests from the repo root:

```powershell
services/converter/.venv/Scripts/python -m pytest services/converter/tests -q
```

## Railway Converter Prep

The converter is prepared for Railway Dockerfile deploys with:

- `services/converter/Dockerfile`
- `services/converter/railway.json`

Use the repository root (`/`) as the Railway service root directory and configure Railway's config file path as `/services/converter/railway.json`. The Dockerfile path is `services/converter/Dockerfile` so the build context includes the monorepo root and the FastAPI app can import `services.converter.app.main`.

Railway provides `${PORT}` at runtime. The deploy start command runs:

```text
uvicorn services.converter.app.main:app --host 0.0.0.0 --port ${PORT}
```

Health checks use `/health`.

## Current Limitations

- The Flutter app shell does not yet wire the full workflow together. The library screen is launched without repository data or import/document callbacks, the import status route uses default placeholder state, and the reader route is not loading a document package by `documentId`.
- Converter base URL configuration exists at the service-client level, but there is no in-app settings flow that lets a tester switch between local and hosted converter URLs.
- File picker import, server/fallback conversion orchestration, cached package reopening, and package-to-reader loading are implemented as services or screen inputs, not as one integrated UI path.
- AI translation and summary services exist, but selected-text reader actions are not wired into the reader UI.
- Vocabulary repositories and list/edit UI exist, but adding selected reader text to vocabulary and deleting vocabulary entries are not wired into the app shell.
- Reader progress callbacks exist, but progress is not persisted and restored through the shell.
- The converter job store is in-memory with local filesystem output; jobs are not durable across process restarts.
- Conversion is synchronous when a job is polled, so large PDFs can block a request during MVP testing.
- Only PDF uploads are supported by the converter.
- Server conversion fallback exists in `ConversionOrchestrator`, but the default app UI does not currently drive it.
- AI translation, summarization, and word meaning require a valid OpenAI API key when exercised through the service layer.
- Android volume-key paging requires testing on an Android device or emulator.
