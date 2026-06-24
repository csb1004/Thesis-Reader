# Manual MVP Component Checklist

Use this checklist to verify the current MVP branch as component and service slices. It is not an end-to-end app-shell acceptance script yet: the Flutter shell does not currently wire import, converter orchestration, package loading, reader AI actions, vocabulary capture, or progress restore into one complete UI workflow.

## Setup

- [ ] Install Flutter dependencies in `apps/thesis_reader`.
- [ ] Create or refresh the converter virtual environment from the repository root.
- [ ] Start the converter locally with `services/converter/.venv/Scripts/python -m uvicorn services.converter.app.main:app --host 0.0.0.0 --port 8000` from the repository root.
- [ ] Confirm `GET http://localhost:8000/health` returns `{"status":"ok"}`.
- [ ] Prepare at least one text-heavy PDF with references for converter/service checks.
- [ ] For AI service checks, provide a valid OpenAI API key through the service/key-store path under test.

## Converter Service

- [ ] Upload a PDF to the converter API and confirm a job is created.
- [ ] Poll the job until it reaches a terminal state.
- [ ] Download the generated package and confirm it contains `package.json`.
- [ ] Confirm referenced assets listed in `package.json` are present in the downloaded package.
- [ ] Restart the converter and note that in-memory jobs from the previous process are no longer available.

## Flutter Library And Import Components

- [ ] Render `LibraryScreen` with an empty document list and confirm the empty state appears.
- [ ] Render `LibraryScreen` with injected document view models and confirm status/progress rows appear.
- [ ] Verify `onImportPressed` and `onDocumentSelected` callbacks fire when injected by a widget test or harness.
- [ ] Render `ImportStatusScreen` in `waitingForServer`, `converting`, `previewReady`, and `failed` states.
- [ ] Verify preview and retry callbacks fire when supplied to `ImportStatusScreen`.
- [ ] Not implemented in the app shell yet: device file-picker import callback wiring.
- [ ] Not implemented in the app shell yet: in-app converter base URL configuration for local versus Railway-hosted services.
- [ ] Not implemented in the app shell yet: UI-driven server conversion plus on-device fallback orchestration.
- [ ] Not implemented in the app shell yet: reopening a cached converter package from the library while offline.

## Conversion And Package Services

- [ ] Exercise `HttpConverterClient` against the local converter and confirm it can create, poll, and download a package.
- [ ] Exercise `ConversionOrchestrator` with an available server and confirm the server conversion path returns a package path.
- [ ] Exercise `ConversionOrchestrator` with an unavailable or timing-out server and confirm the on-device fallback path is used.
- [ ] Load a generated package through the document contract/package parsing path and confirm expected metadata, blocks, and assets are available to callers.

## Reader Component

- [ ] Render `ReaderScreen` with an injected `DocumentPackage` and confirm page mode shows stable page numbers and expected content.
- [ ] Switch to scroll mode and confirm continuous scrolling renders the same package content.
- [ ] Change reader settings in the settings sheet and confirm the visible reader updates in the current session.
- [ ] Open a reference asset link and confirm the configured bottom-sheet or full-screen asset viewer appears.
- [ ] Verify volume-key paging on an Android device or emulator when page mode is active.
- [ ] Not implemented in the app shell yet: loading a `DocumentPackage` into `ReaderScreen` by route `documentId`.
- [ ] Not implemented in the app shell yet: persisting reader settings through the shell.
- [ ] Not implemented in the app shell yet: persisted reader progress restore or library progress updates.

## AI Assistance Services

- [ ] Exercise the translation service with representative selected text and confirm the response maps to the requested content.
- [ ] Exercise the summary service with representative section/range text and confirm the response references that input.
- [ ] Confirm missing or invalid API-key errors are surfaced cleanly at the service boundary.
- [ ] Not implemented in the reader UI yet: selected-text translate, summarize, or word-meaning actions.

## Vocabulary Components And Services

- [ ] Upsert a vocabulary draft and confirm the entry is stored for the document.
- [ ] Upsert the same expression with different casing or spacing and confirm normalization updates the existing entry instead of creating a duplicate.
- [ ] Render `VocabularyScreen` with a repository containing entries and confirm the list appears.
- [ ] Edit a vocabulary entry's user meaning or memo and confirm the list refreshes.
- [ ] Recreate the persistent repository/database and confirm saved entries remain available when using the Drift-backed repository.
- [ ] Not implemented in the app shell yet: adding selected reader text to vocabulary.
- [ ] Not implemented yet: vocabulary delete flow in the UI/repository contract.

## Railway Converter Prep

- [ ] Confirm `services/converter/Dockerfile` and `services/converter/railway.json` are present.
- [ ] Confirm Railway should use the repository root (`/`) as the service root directory.
- [ ] Confirm Railway's config file path should be `/services/converter/railway.json`.
- [ ] Confirm the Dockerfile path is `services/converter/Dockerfile`.
- [ ] Confirm the start command uses Railway's runtime `${PORT}` value.
- [ ] Do not mark a live deployment as complete unless a Railway service has actually been created and verified separately.
