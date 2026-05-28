# Contributing to QuickFolder

Thanks for helping improve QuickFolder.

## Development Setup

1. Clone the repository.
2. Open `QuickFolder.xcodeproj` in Xcode.
3. Select the `QuickFolder` scheme.
4. Build and run the app.

Command-line build:

```sh
xcodebuild -project QuickFolder.xcodeproj -scheme QuickFolder -configuration Debug build
```

## Project Conventions

- Keep the app native and lightweight.
- Prefer public macOS APIs.
- Avoid private APIs and fragile system mutations.
- Keep code comments in English.
- Keep UI copy concise and consistent with macOS conventions.
- Do not commit `xcuserdata`, DerivedData, runtime JSON data, or local logs.

## Pull Requests

Before opening a pull request:

- Build the app successfully.
- Test the menu bar icon and popover behavior manually.
- Verify pinned folders persist after relaunch.
- Verify unavailable folders do not crash the app.
- Keep changes focused and explain user-visible behavior changes.

## Good First Issues

Useful first contributions include:

- Improving accessibility labels and keyboard navigation.
- Adding small UI polish without changing core behavior.
- Improving error messages for unavailable folders.
- Adding focused tests around folder persistence.
