import SwiftUI

/// Visual editor for custom layouts. Layouts are built by recursively
/// splitting zones: select a zone, split it left/right or top/bottom, adjust
/// the split ratio, or delete it (its sibling absorbs the space).
struct LayoutEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var tree: SplitNode
    @State private var selectedLeaf: Int?

    private let layoutID: UUID
    private let onSave: (SnapLayout) -> Void

    init(layout: SnapLayout, onSave: @escaping (SnapLayout) -> Void) {
        layoutID = layout.id
        _name = State(initialValue: layout.name)
        _tree = State(initialValue: layout.tree ?? .leaf)
        self.onSave = onSave
    }

    private var cells: [LayoutCell] { tree.cells() }

    var body: some View {
        VStack(spacing: 16) {
            TextField("Layout name", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.title3)

            // Canvas: click a zone to select it.
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                    ForEach(Array(cells.enumerated()), id: \.offset) { i, cell in
                        let rect = CGRect(
                            x: cell.x * proxy.size.width,
                            y: cell.y * proxy.size.height,
                            width: cell.w * proxy.size.width,
                            height: cell.h * proxy.size.height
                        ).insetBy(dx: 2, dy: 2)
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selectedLeaf == i ? Color.accentColor.opacity(0.5) : Color.accentColor.opacity(0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(selectedLeaf == i ? Color.accentColor : Color.accentColor.opacity(0.35),
                                                  lineWidth: selectedLeaf == i ? 2 : 1)
                            )
                            .overlay(Text("\(i + 1)").font(.headline).foregroundStyle(.secondary))
                            .frame(width: rect.width, height: rect.height)
                            .offset(x: rect.minX, y: rect.minY)
                            .onTapGesture { selectedLeaf = i }
                    }
                }
            }
            .aspectRatio(16.0 / 10.0, contentMode: .fit)

            // Tools for the selected zone.
            HStack(spacing: 10) {
                Button {
                    if let i = selectedLeaf { tree = tree.splittingLeaf(at: i, axis: .horizontal) }
                } label: {
                    Label("Split ⇆", systemImage: "rectangle.split.2x1")
                }
                Button {
                    if let i = selectedLeaf { tree = tree.splittingLeaf(at: i, axis: .vertical) }
                } label: {
                    Label("Split ⇅", systemImage: "rectangle.split.1x2")
                }
                Button(role: .destructive) {
                    if let i = selectedLeaf {
                        tree = tree.deletingLeaf(at: i)
                        selectedLeaf = nil
                    }
                } label: {
                    Label("Delete Zone", systemImage: "trash")
                }
                .disabled(tree.leafCount <= 1)
                Spacer()
            }
            .disabled(selectedLeaf == nil)

            if let i = selectedLeaf, let ratio = tree.ancestorRatio(ofLeaf: i) {
                LabeledContent("Split position") {
                    Slider(value: Binding(
                        get: { tree.ancestorRatio(ofLeaf: i) ?? ratio },
                        set: { tree = tree.settingAncestorRatio(ofLeaf: i, to: $0) }
                    ), in: 0.1...0.9)
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save Layout") {
                    var layout = SnapLayout(
                        id: layoutID,
                        name: name.isEmpty ? "Custom Layout" : name,
                        cells: tree.cells(),
                        tree: tree
                    )
                    layout.isEnabled = true
                    onSave(layout)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(tree.leafCount < 2)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}
