import SwiftUI

struct FolderRowView: View {
    @EnvironmentObject private var store: FolderStore
    @State private var isHovering = false

    let item: FolderItem

    var body: some View {
        HStack(spacing: 8) {
            Button {
                store.openFolder(item)
            } label: {
                rowContent
            }
            .buttonStyle(.plain)
            .disabled(!item.exists)

            if isHovering {
                rowActions
            } else if !item.exists {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(.orange)
                    .help("Folder is unavailable")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.separator.opacity(isHovering ? 0.55 : 0.18))
        }
        .onHover { isHovering = $0 }
        .contextMenu {
            if item.isPinned {
                Button("Unpin") {
                    store.unpin(item)
                }
            } else {
                Button("Pin") {
                    store.pin(item)
                }
            }

            Button("Reveal in Finder") {
                store.revealInFinder(item)
            }
            .disabled(!item.exists)

            Button("Open in Terminal") {
                store.openInTerminal(item)
            }
            .disabled(!item.exists)

            Button("Remove from Recent") {
                store.removeFromRecents(item)
            }

            Button("Forget Folder", role: .destructive) {
                store.forget(item)
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                folderIcon

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(item.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(item.exists ? .primary : .secondary)
                            .lineLimit(1)

                        if item.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.blue)
                        }

                        if item.source == .finder {
                            Image(systemName: "sparkle.magnifyingglass")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .help("Best-effort macOS recent signal")
                        }
                    }

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var folderIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(item.exists ? Color.blue.opacity(0.13) : Color.orange.opacity(0.13))
            Image(systemName: item.exists ? "folder.fill" : "questionmark.circle")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(item.exists ? .blue : .orange)
        }
        .frame(width: 34, height: 34)
    }

    private var rowActions: some View {
        HStack(spacing: 6) {
            Button {
                item.isPinned ? store.unpin(item) : store.pin(item)
            } label: {
                Image(systemName: item.isPinned ? "pin.slash" : "pin")
            }
            .buttonStyle(.borderless)
            .help(item.isPinned ? "Unpin" : "Pin")

            Button {
                store.revealInFinder(item)
            } label: {
                Image(systemName: "arrow.up.forward.app")
            }
            .buttonStyle(.borderless)
            .disabled(!item.exists)
            .help("Reveal in Finder")

            Button {
                store.openInTerminal(item)
            } label: {
                Image(systemName: "terminal")
            }
            .buttonStyle(.borderless)
            .disabled(!item.exists)
            .help("Open in Terminal")

            Button {
                store.removeFromRecents(item)
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Remove from Recent")
        }
        .font(.system(size: 11, weight: .semibold))
    }

    private var rowBackground: some ShapeStyle {
        if isHovering {
            return AnyShapeStyle(.quaternary)
        }
        return AnyShapeStyle(.background.opacity(0.45))
    }

    private var subtitle: String {
        if !item.exists {
            return "Unavailable · \(item.parentPath)"
        }

        guard let lastOpenedAt = item.lastOpenedAt, lastOpenedAt > .distantPast else {
            return item.parentPath
        }

        return "\(lastOpenedAt.formatted(date: .abbreviated, time: .shortened)) · \(item.parentPath)"
    }
}
