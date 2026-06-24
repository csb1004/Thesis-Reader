# Manual MVP Checklist

Use this checklist for one end-to-end pass before handing the MVP to a tester or pointing the app at a hosted converter.

## Setup

- [ ] Install Flutter dependencies in `apps/thesis_reader`.
- [ ] Start the converter locally with `services/converter/.venv/Scripts/python -m uvicorn services.converter.app.main:app --host 0.0.0.0 --port 8000` from the repo root.
- [ ] Confirm `GET http://localhost:8000/health` returns `{"status":"ok"}`.
- [ ] Configure the app to use the local or Railway converter base URL.
- [ ] Use at least one text-heavy PDF with references and one PDF that should exercise fallback behavior.
- [ ] For AI flows, store a valid OpenAI API key in the app settings or secure key flow.

## Import And Conversion

- [ ] Import a PDF from the device file picker.
- [ ] Confirm the import status moves through waiting, converting, and preview-ready states.
- [ ] Confirm server conversion creates a cached document package with `package.json` and referenced assets.
- [ ] Stop or block the converter server, import another PDF, and confirm fallback conversion completes without losing the import.
- [ ] Reopen a document imported from a cached package while offline and confirm it opens without contacting the converter.

## Reader Experience

- [ ] Open an imported document and confirm page mode shows stable page numbers and expected content.
- [ ] Switch to scroll mode and confirm continuous scrolling works without losing the current section.
- [ ] Change page/scroll settings, close the reader, reopen it, and confirm settings persist.
- [ ] Navigate near the references section and open a reference asset.
- [ ] Confirm the reference asset viewer renders the expected image/table/file and can return to the reader.

## AI Assistance

- [ ] Select a paragraph or sentence and request translation.
- [ ] Confirm the translated text is relevant and errors are surfaced cleanly if the API key is missing or invalid.
- [ ] Request a summary for the current range or section.
- [ ] Confirm the summary references the selected content rather than unrelated text.

## Vocabulary

- [ ] Select a word or phrase and add it to vocabulary.
- [ ] Confirm duplicate words normalize to the existing entry instead of creating noisy duplicates.
- [ ] Edit or delete a vocabulary entry and confirm the list updates immediately.
- [ ] Reopen the app and confirm saved vocabulary remains available.

## Reopen Progress

- [ ] Read into the middle of a document in page mode, close the app, reopen it, and confirm progress resumes near the same page.
- [ ] Repeat in scroll mode and confirm the scroll offset or progress resumes near the same location.
- [ ] Confirm the library list shows the last-read progress percentage after returning from the reader.

## Android Volume Keys

- [ ] Run the Android app on a device or emulator.
- [ ] Open a document in page mode and press volume up/down.
- [ ] Confirm volume keys move between pages when reader controls are active.
- [ ] Confirm volume keys do not crash the app when pressed rapidly or at the first/last page.
