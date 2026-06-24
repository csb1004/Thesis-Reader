# Thesis Reader Library Management Design

## Goal

Add library management so imported papers can be organized, renamed, moved, deleted, and configured from the main screen. The app already copies each PDF into internal storage and stores converted reader packages separately; this feature makes those internal files visible as manageable library items without exposing raw filesystem paths to the user.

## User Experience

The main library screen uses a two-pane layout:

- Left pane: folder list with `All`, `Unfiled`, user-created folders, and a create-folder action.
- Right pane: papers in the selected folder, each showing title, conversion status, read progress, and an overflow menu.

On narrow phone layouts, the panes collapse into a folder selector row above the document list. The selected folder still controls which documents appear.

Each document overflow menu includes:

- Rename: edits the display title stored in the database.
- Move to folder: opens a folder picker and updates the document's folder assignment.
- Delete: asks for confirmation, then deletes the document record and all internal files for that document.

The top-level app bar includes a settings action. Settings include:

- OpenAI API token input, update, and delete.
- Default translation mode: simple translation or OpenAI translation.
- A reserved import/conversion section for future options, shown only when concrete settings exist.

## Data Model

Add a `LibraryFolders` table:

- `id`: primary key.
- `name`: user-facing folder name.
- `createdAt`: UTC timestamp.
- `updatedAt`: UTC timestamp.

Add `folderId` to `Documents` as nullable:

- `null` means the document appears under `Unfiled`.
- Documents with a folder ID appear under that folder.
- `All` is a virtual view, not a stored folder.

Increase the Drift schema version and migrate existing databases by adding the new table and nullable column. Existing documents remain unfiled.

## Storage and Deletion

The existing internal storage layout remains:

- Original PDF: `documents/{documentId}/source.pdf`
- Converted package: `packages/{documentId}/package.json` plus assets

Deleting a document removes:

- The row from `documents`.
- Dependent vocabulary entries and viewer settings.
- The copied original PDF directory.
- The converted package directory.
- Saved read progress keys in `SharedPreferences`.

Deletion should be best-effort for files after the database transaction: if file removal fails, the app reports the error and leaves the UI consistent with database state. File cleanup errors should not delete unrelated paths.

## Components

Library screen:

- Renders folder navigation and filtered document list.
- Emits callbacks for import, open, rename, move, delete, create folder, select folder, and settings.

Library controller state in `app.dart`:

- Loads folders and documents from Drift.
- Maintains selected folder ID.
- Performs rename, move, create folder, and delete operations.
- Supplies settings dependencies to settings and reader screens.

Storage helpers:

- Add safe recursive deletion methods for a document's internal directories.
- Resolve paths only under the app documents directory.

Settings screen:

- Uses `OpenAiKeyStore` for API token actions.
- Uses `SharedPreferences` for default translation mode.
- Keeps settings independent from per-document reader settings.

## Error Handling

- Rename rejects empty titles.
- Folder creation rejects empty names and trims whitespace.
- Delete requires confirmation and reports cleanup failures through a snackbar.
- Move handles deleted or missing folders by returning the document to `Unfiled`.
- Settings token save trims whitespace and allows clearing the token.

## Testing

Widget tests:

- Library shows folders and filters documents by folder.
- Document overflow exposes rename, move, and delete actions.
- Settings screen can save and clear an OpenAI token and choose default translation mode.

Unit/storage tests:

- Folder repository creates and lists folders.
- Document update operations rename and move documents.
- Delete removes database rows and calls safe storage cleanup.
- Migration preserves existing documents as unfiled.

Manual verification:

- Import a PDF, rename it, move it into a folder, close/reopen the app, and confirm it remains in that folder.
- Delete a PDF and confirm it disappears from the library and no longer opens.
