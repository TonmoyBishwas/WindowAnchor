import SwiftUI

/// Enable/disable, reorder, create, edit, and delete snap layouts.
struct LayoutsSettingsView: View {
    @ObservedObject private var prefs = Preferences.shared
    @State private var editingLayout: SnapLayout?

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(Array(prefs.layouts.enumerated()), id: \.element.id) { index, layout in
                    HStack(spacing: 12) {
                        LayoutThumbnail(cells: layout.cells)
                            .frame(width: 64, height: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(layout.name).fontWeight(.medium)
                            Text(layout.isBuiltIn ? "Built-in · \(layout.cells.count) zones" : "Custom · \(layout.cells.count) zones")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !layout.isBuiltIn {
                            Button {
                                editingLayout = layout
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)
                            .help("Edit layout")
                            Button(role: .destructive) {
                                prefs.layouts.removeAll { $0.id == layout.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Delete layout")
                        }
                        Toggle("", isOn: Binding(
                            get: { prefs.layouts.first(where: { $0.id == layout.id })?.isEnabled ?? false },
                            set: { newValue in
                                if let i = prefs.layouts.firstIndex(where: { $0.id == layout.id }) {
                                    prefs.layouts[i].isEnabled = newValue
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }
                    .padding(.vertical, 4)
                }
                .onMove { source, destination in
                    prefs.layouts.move(fromOffsets: source, toOffset: destination)
                }
            }

            HStack {
                Button {
                    editingLayout = SnapLayout(
                        name: "Custom Layout",
                        cells: SplitNode.leaf.cells(),
                        tree: .leaf
                    )
                } label: {
                    Label("New Custom Layout", systemImage: "plus")
                }
                Spacer()
                Text("Drag rows to reorder. The flyout shows enabled layouts in this order.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .sheet(item: $editingLayout) { layout in
            LayoutEditorView(layout: layout) { saved in
                if let i = prefs.layouts.firstIndex(where: { $0.id == saved.id }) {
                    prefs.layouts[i] = saved
                } else {
                    prefs.layouts.append(saved)
                }
            }
        }
    }
}

/// Small preview of a layout's cells.
struct LayoutThumbnail: View {
    let cells: [LayoutCell]

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    let rect = CGRect(
                        x: cell.x * proxy.size.width,
                        y: cell.y * proxy.size.height,
                        width: cell.w * proxy.size.width,
                        height: cell.h * proxy.size.height
                    ).insetBy(dx: 1.5, dy: 1.5)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.accentColor.opacity(0.55))
                        .frame(width: max(0, rect.width), height: max(0, rect.height))
                        .offset(x: rect.minX, y: rect.minY)
                }
            }
        }
    }
}
