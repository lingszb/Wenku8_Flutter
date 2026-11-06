# Wenku8 Flutter · Local Reader

[简体中文](README.md) · [Documentation index](docs/README.md) · [Agent project guide](.agents/PROJECT_GUIDE.md) · [Project skills](.agents/skills/README.md)

A local-reading fork of [Wenku8 Flutter](https://github.com/mikufoxxx/Wenku8_Flutter), targeting Android: import your own TXT / EPUB books, read offline, organize a local library, and listen to text-to-speech.

> [!IMPORTANT]
> This is a third-party reading tool. It is not affiliated with Wenku8 and is not its official app. The app does not operate an online library, publish novels, or bundle any book files. Novels, covers and illustrations remain the property of their respective rights holders; import only content you are entitled to use.

## Scope

The app has two main tabs: **Local** and **Mine**. Online discovery and rankings, online search, accounts, the Wenku8 cloud shelf, reviews, online catalogs and chapter requests, and site downloads have been removed and are not reintroduced without an explicit task.

What remains:

- A local library, TXT / EPUB import and reading, covers and illustrations, bookmarks, reading statistics, settings, backup and local search.
- Text-to-speech, font downloads and in-app updates.
- Independent cloud import and manual sync, so the app is not fully offline.

## Features

### Local library

- Import TXT / EPUB through the system file picker, either linking the original file or copying it into the app.
- On Android, recursively scan a granted folder or the primary shared storage, review candidates, then import the selected books.
- Merge volumes of the same series, organize categories, move or delete books in bulk, and replace covers.
- Local search by title, author or tag.

### Reading

- Scrolling, horizontal paging and vertical paging modes, with adjustable page-turn effect and speed.
- Font, size, weight, letter spacing, line height and all four margins; independent theme colors and backgrounds.
- Auto page turn or auto scroll, volume-key page turns and in-chapter search.
- Pinch to zoom covers and illustrations, or save the original image.
- Bookmarks, annotations, excerpt cards and reading keepsakes, with seasonal artwork chosen by record date and exportable images.
- Reading statistics (overview, rhythm, books, marks, touch).
- Android home-screen widgets in small, medium and large sizes, with light and dark modes.
- Backup and restore of the shelf, reading progress, bookmarks, history, recent searches and preferences.

### Listening

- System TTS, Edge online voices, and custom Microsoft SSML / OpenAI Speech endpoints.
- Playback speed, paragraph following, sleep timer, background playback, lock-screen and headset controls.
- Configuration and credential storage are described in [CUSTOM_SPEECH.md](docs/CUSTOM_SPEECH.md).

### Other

- Download reading fonts on demand, or import TTF / OTF files.
- Cloud import through OpenList / WebDAV, Quark Drive and S3-compatible storage.
- In-app update checks.

## Current limitations

- Only TXT and EPUB can be imported; no other format conversion is provided.
- LAN continuation, audio enhancement, advanced format conversion, bulk series management and full reading-report editing / export are not implemented. The presence of an entry point does not mean it works.
- The iOS and HarmonyOS host projects remain in the repository, but this fork is verified on Android only. Do not infer support for those platforms from Flutter's cross-platform capabilities.
- Widgets are configured inside the app on Android; the system decides refresh timing, and no continuous animation runs.

## Build

The CI baseline is Flutter `3.47.9`, JDK `17` and Android SDK `36`. Confirm versions, paths and device IDs on your own machine.

```powershell
flutter pub get

# Static checks and tests
flutter analyze lib test --no-pub --no-fatal-infos
flutter test --no-pub

# Choose the target architecture
flutter build apk --debug --target-platform android-arm64 --no-pub
flutter build apk --debug --target-platform android-x64 --no-pub

# Install and run
adb devices
flutter run -d <device-id>
```

See [SOURCE_BUILD.md](docs/SOURCE_BUILD.md), [CI_CD.md](docs/CI_CD.md) and [RELEASING.md](docs/RELEASING.md) for build, signing and release details.

## Data and privacy

- Book references, reading progress, bookmarks, categories and preferences stay on the device; backups are exported manually and exclude offline text and account data.
- Custom speech API keys are encrypted with the Android Keystore and kept out of regular preferences and backups.
- There is no account system and reading records are not uploaded. Cloud import, online speech and update checks contact the services you configure.

## Documentation

| Document | Content |
| --- | --- |
| [docs/README.md](docs/README.md) | Documentation index and maintenance rules |
| [docs/SOURCE_BUILD.md](docs/SOURCE_BUILD.md) | Current build scope, scanning and known limits |
| [docs/READER.md](docs/READER.md) | Reader, typography and import reference |
| [docs/CUSTOM_SPEECH.md](docs/CUSTOM_SPEECH.md) | Custom speech protocols and credential boundaries |
| [docs/CLOUD_IMPORT.md](docs/CLOUD_IMPORT.md) | Cloud import reference |
| [docs/READING_WIDGETS.md](docs/READING_WIDGETS.md) | Home-screen widgets |
| [docs/READING_STATISTICS.md](docs/READING_STATISTICS.md) | Reading statistics |
| [docs/SEASONAL_ART.md](docs/SEASONAL_ART.md) | Seasonal keepsake and excerpt artwork |
| [docs/DESIGN.md](docs/DESIGN.md) | Visual and interaction guidelines |
| [docs/THIRD_PARTY.md](docs/THIRD_PARTY.md) | Third-party components and licenses |

Some documents are written in Chinese; the source code and executable checks take precedence over historical descriptions.

## Acknowledgments and license

This project is based on [mikufoxxx/Wenku8_Flutter](https://github.com/mikufoxxx/Wenku8_Flutter) and keeps its original license and attribution requirements. Thanks to the upstream author and to the authors of all open-source components and fonts used here.

- The repository's [LICENSE](LICENSE) and [GPL v3 text](assets/licenses/GPL-3.0.txt) apply to published source files; see [NOTICE](NOTICE) for details.
- Downloadable fonts follow their respective SIL OFL 1.1 licenses.
- The online voice integration references [rany2/edge-tts](https://github.com/rany2/edge-tts), [LGPL v3](assets/licenses/edge-tts.txt).

Third-party components retain their own copyrights and licenses. The source-code license grants no rights to book content.