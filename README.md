# QuickFolder

QuickFolder is a native macOS menu bar app for fast access to pinned and recent folders.

It stays out of the Dock, lives in the status bar, and opens folders directly in Finder.

## Features

- Native macOS menu bar app built with SwiftUI and AppKit.
- Pinned folders with persistent storage.
- Recent folders from QuickFolder usage.
- Best-effort macOS recent-folder import from shared file list data.
- Search across folder names and paths.
- Hover actions and context menu actions for pinning, revealing, removing, and forgetting folders.
- Settings for login at startup, recent limit, and macOS recent-folder import.

## Requirements

- macOS 14 or newer.
- Xcode 26.5 or newer is recommended for the current project format.

## Build

```sh
xcodebuild -project QuickFolder.xcodeproj -scheme QuickFolder -configuration Debug build
```

You can also open `QuickFolder.xcodeproj` in Xcode and run the `QuickFolder` scheme.

## Runtime Data

QuickFolder stores its local data at:

```text
~/Library/Application Support/QuickFolder/folders.json
```

Pinned folders use security-scoped bookmarks when available. macOS recent folders are imported on a best-effort basis because Apple does not expose a stable public Finder recent-folder API for this exact use case.

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for setup notes, project conventions, and pull request expectations.

## License

QuickFolder is released under the [MIT License](LICENSE).
