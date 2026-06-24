# Thesis Reader

Thesis Reader is an MVP Flutter app for importing academic PDFs, converting them into a structured local document package, and reading them with study tools such as translation, summarization, vocabulary capture, progress restore, and reference asset viewing.

The repository is a small monorepo:

- `apps/thesis_reader`: Flutter app for desktop/mobile reader workflows.
- `packages/document_contract`: shared Dart package for the document package contract.
- `services/converter`: FastAPI PDF converter that emits cached document packages.
- `docs/contracts`: JSON schema for the converter package format.
- `docs/testing/manual-mvp-checklist.md`: manual end-to-end MVP verification checklist.

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

- The converter job store is in-memory with local filesystem output; jobs are not durable across process restarts.
- Conversion is synchronous when a job is polled, so large PDFs can block a request during MVP testing.
- Only PDF uploads are supported by the converter.
- Server conversion falls back to the app's on-device path when the server is unavailable or times out.
- AI translation, summarization, and word meaning require a valid OpenAI API key configured in the app.
- Android volume-key paging requires testing on an Android device or emulator.
