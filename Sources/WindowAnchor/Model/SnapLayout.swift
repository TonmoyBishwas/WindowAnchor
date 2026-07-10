import CoreGraphics
import Foundation

/// A cell inside a layout, in normalized coordinates (0...1, top-left origin).
struct LayoutCell: Codable, Equatable, Hashable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double

    var rect: CGRect { CGRect(x: x, y: y, width: w, height: h) }

    init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }

    init(rect: CGRect) {
        self.init(x: rect.origin.x, y: rect.origin.y, w: rect.width, h: rect.height)
    }
}

/// A binary-split tree used by the custom layout editor.
/// Leaves are cells; internal nodes split their region at `ratio`.
indirect enum SplitNode: Codable, Equatable {
    case leaf
    case split(axis: Axis, ratio: Double, first: SplitNode, second: SplitNode)

    enum Axis: String, Codable { case horizontal, vertical } // horizontal = side-by-side columns

    private enum CodingKeys: String, CodingKey { case kind, axis, ratio, first, second }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        if kind == "leaf" {
            self = .leaf
        } else {
            self = .split(
                axis: try c.decode(Axis.self, forKey: .axis),
                ratio: try c.decode(Double.self, forKey: .ratio),
                first: try c.decode(SplitNode.self, forKey: .first),
                second: try c.decode(SplitNode.self, forKey: .second)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .leaf:
            try c.encode("leaf", forKey: .kind)
        case let .split(axis, ratio, first, second):
            try c.encode("split", forKey: .kind)
            try c.encode(axis, forKey: .axis)
            try c.encode(ratio, forKey: .ratio)
            try c.encode(first, forKey: .first)
            try c.encode(second, forKey: .second)
        }
    }

    /// Flattens the tree into normalized cells within `region`.
    func cells(in region: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)) -> [LayoutCell] {
        switch self {
        case .leaf:
            return [LayoutCell(rect: region)]
        case let .split(axis, ratio, first, second):
            let r = min(max(ratio, 0.05), 0.95)
            let (a, b): (CGRect, CGRect)
            switch axis {
            case .horizontal:
                let w = region.width * r
                a = CGRect(x: region.minX, y: region.minY, width: w, height: region.height)
                b = CGRect(x: region.minX + w, y: region.minY, width: region.width - w, height: region.height)
            case .vertical:
                let h = region.height * r
                a = CGRect(x: region.minX, y: region.minY, width: region.width, height: h)
                b = CGRect(x: region.minX, y: region.minY + h, width: region.width, height: region.height - h)
            }
            return first.cells(in: a) + second.cells(in: b)
        }
    }

    var leafCount: Int {
        switch self {
        case .leaf: return 1
        case let .split(_, _, a, b): return a.leafCount + b.leafCount
        }
    }
}

/// A snap layout: a named set of cells the user can drop windows into.
struct SnapLayout: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var cells: [LayoutCell]
    var tree: SplitNode?      // present for user-editable layouts
    var isEnabled: Bool
    var isBuiltIn: Bool

    init(id: UUID = UUID(), name: String, cells: [LayoutCell], tree: SplitNode? = nil,
         isEnabled: Bool = true, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.cells = cells
        self.tree = tree
        self.isEnabled = isEnabled
        self.isBuiltIn = isBuiltIn
    }
}

extension SnapLayout {
    /// The six Windows 11 style presets. Stable IDs so enabled/disabled state
    /// and ordering survive relaunches.
    static let builtInPresets: [SnapLayout] = [
        SnapLayout(
            id: UUID(uuidString: "9A1DE7F0-0001-4000-8000-000000000001")!,
            name: "Two Halves",
            cells: [
                LayoutCell(x: 0, y: 0, w: 0.5, h: 1),
                LayoutCell(x: 0.5, y: 0, w: 0.5, h: 1),
            ],
            isBuiltIn: true
        ),
        SnapLayout(
            id: UUID(uuidString: "9A1DE7F0-0002-4000-8000-000000000002")!,
            name: "Wide Left",
            cells: [
                LayoutCell(x: 0, y: 0, w: 2.0 / 3.0, h: 1),
                LayoutCell(x: 2.0 / 3.0, y: 0, w: 1.0 / 3.0, h: 1),
            ],
            isBuiltIn: true
        ),
        SnapLayout(
            id: UUID(uuidString: "9A1DE7F0-0003-4000-8000-000000000003")!,
            name: "Three Columns",
            cells: [
                LayoutCell(x: 0, y: 0, w: 1.0 / 3.0, h: 1),
                LayoutCell(x: 1.0 / 3.0, y: 0, w: 1.0 / 3.0, h: 1),
                LayoutCell(x: 2.0 / 3.0, y: 0, w: 1.0 / 3.0, h: 1),
            ],
            isBuiltIn: true
        ),
        SnapLayout(
            id: UUID(uuidString: "9A1DE7F0-0004-4000-8000-000000000004")!,
            name: "Half + Stack",
            cells: [
                LayoutCell(x: 0, y: 0, w: 0.5, h: 1),
                LayoutCell(x: 0.5, y: 0, w: 0.5, h: 0.5),
                LayoutCell(x: 0.5, y: 0.5, w: 0.5, h: 0.5),
            ],
            isBuiltIn: true
        ),
        SnapLayout(
            id: UUID(uuidString: "9A1DE7F0-0005-4000-8000-000000000005")!,
            name: "Quarters",
            cells: [
                LayoutCell(x: 0, y: 0, w: 0.5, h: 0.5),
                LayoutCell(x: 0.5, y: 0, w: 0.5, h: 0.5),
                LayoutCell(x: 0, y: 0.5, w: 0.5, h: 0.5),
                LayoutCell(x: 0.5, y: 0.5, w: 0.5, h: 0.5),
            ],
            isBuiltIn: true
        ),
        SnapLayout(
            id: UUID(uuidString: "9A1DE7F0-0006-4000-8000-000000000006")!,
            name: "Center Focus",
            cells: [
                LayoutCell(x: 0, y: 0, w: 0.25, h: 1),
                LayoutCell(x: 0.25, y: 0, w: 0.5, h: 1),
                LayoutCell(x: 0.75, y: 0, w: 0.25, h: 1),
            ],
            isBuiltIn: true
        ),
    ]
}
