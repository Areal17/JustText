# JustText

JustText is a lightweight, distraction-free text editor for macOS. It combines a clean writing surface with essential formatting, document statistics, and export to common formats, without the overhead of a full word processor.

Built with SwiftUI and AppKit (`NSTextView`) as a document-based app.

## Features

### Writing & Formatting
- **Paragraph styles:** Title, Heading, Subheading, Body text, and a proportional font style
- **Text styles:** Bold, Italic, Bold Italic, and font selection via the system font panel
- **Lists:** Bullet lists, dash lists, numbered lists, and checklists (checkboxes can be toggled by clicking)
- **Quote blocks**
- **Copy with formatting:** Copies the selection including its rich-text attributes
- **Format toolbar:** An optional toolbar with quick access to all formatting options

### Search & Replace
- Inline search bar with match highlighting
- Jump to the next or previous match
- Replace a single match or all matches at once

### Focus Mode
- Hides the window toolbar so you can concentrate on writing
- Toggle with `⇧⌘F`

### Inspector
A sidebar panel with live document statistics:
- Characters (with and without whitespace)
- Words, sentences, lines, and paragraphs
- Estimated reading time (200 words/min) and speaking time (150 words/min)

### File Formats

| Format | Open | Save | Export |
| --- | --- | --- | --- |
| JustText document (`.jute`, RTF-based) | ✅ | ✅ | |
| Rich Text (`.rtf`) | ✅ | ✅ | |
| Plain text (`.txt`) | ✅ | ✅ | ✅ |
| Markdown (`.md`) | ✅ | ✅ | ✅ |
| Word (`.docx`) | | | ✅ |
| PDF (A4) | | | ✅ |

Plain text and Markdown files are opened as raw text and saved back in their original format. The Markdown export converts headings, lists, quotes, and emphasis into Markdown syntax.

### Localization
The app ships in English and German.

## Keyboard Shortcuts

| Action | Shortcut |
| --- | --- |
| Search | `⌘F` |
| Next match | `⌘G` |
| Previous match | `⇧⌘G` |
| Focus mode | `⇧⌘F` |
| Show/hide format toolbar | `⌥⌘K` |
| Copy with formatting | `⇧⌘C` |
| Title | `⇧⌘T` |
| Heading | `⇧⌘H` |
| Subheading | `⇧⌘J` |
| Body text | `⇧⌘B` |
| Proportional | `⇧⌘M` |
| Bold | `⌘B` |
| Italic | `⌘I` |
| Bold and italic | `⇧⌘I` |
| Show fonts | `⌘T` |
| Bullet list | `⇧⌘7` |
| Dash list | `⇧⌘8` |
| Numbered list | `⇧⌘9` |
| Quote block | `⌘'` |
| Checklist | `⇧⌘L` |

## Requirements

- macOS 26.5 or later
- Xcode 26 or later to build

## Building

1. Open `JustText.xcodeproj` in Xcode.
2. Select the `JustText` scheme.
3. Build and run with `⌘R`.

Run the tests with `⌘U`.

## Project Structure

| File | Purpose |
| --- | --- |
| `JustText/JustTextApp.swift` | App entry point, document group, and menu commands |
| `JustText/JustTextDocument.swift` | `FileDocument` for reading and writing `.jute`, RTF, TXT, and Markdown |
| `JustText/ContentView.swift` | Main window: editor, search bar, toolbar, focus mode, inspector |
| `JustText/FormatToolbarView.swift` | Optional formatting toolbar |
| `JustText/JustTextExportDocument.swift` | Export formats and export document |
| `JustText/DOCXWriter.swift` | Generates Word (`.docx`) files, including a minimal ZIP writer |
| `JustText/PDFWriter.swift` | Renders the document to an A4 PDF |
| `JustText/MarkdownWriter.swift` | Converts attributed text to Markdown |
| `JustText/AttributedParagraphs.swift` | Helpers for splitting attributed text into paragraphs |
| `TextEditView.swift` | `NSViewRepresentable` wrapper around the text view |
| `FormattingTextView.swift` | `NSTextView` subclass with formatting, lists, checklists, and search highlighting |
| `InspectorView.swift` | Inspector panel showing document statistics |
| `TextStatistics.swift` | Statistics calculation using the NaturalLanguage framework |
| `SearchMatchFinder.swift` | Finds search matches in the text |
| `Localizable.xcstrings` | String Catalog (English, German) |
| `JustTextTests/` | Unit tests for the DOCX and Markdown exporters |
| `JustTextUITests/` | UI tests |

## Author

Ingo Wiederoder
