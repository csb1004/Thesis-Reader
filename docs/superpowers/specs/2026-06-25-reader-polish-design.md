# Reader Polish Design

## Goal

Fix the reader's page-mode empty lower area, add a manual conversion action for documents that open as original PDFs after updates, add a pure white reader theme, and normalize visible app language to Korean.

## Design

Page mode should use the available viewport more accurately. The reader will reserve a small fixed footer area for the page number, then pass the remaining height to the layout engine. The page body itself will not scroll in page mode.

Manual conversion will be exposed from each document's library menu as "PDF 다시 변환". It will call the same Railway conversion path used after import. Conversion success will update the database, in-memory package cache, and document status so opening the document uses the converted reader instead of the original PDF fallback. Conversion failure will keep the original PDF available.

Reader themes will gain a "흰색" option with a white background and near-black text. Reader settings labels, selection context menu actions, snackbars, dialogs, asset labels, fallback text, and library conversion labels will be Korean.

## Testing

Add or update Flutter tests for:

- Page-mode layout uses a larger body height without internal scroll.
- Reader settings show the white theme and Korean labels.
- Library exposes a manual reconvert document action.
- Existing reader, library, AI, vocabulary, and storage tests still pass.
