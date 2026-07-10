import XCTest
@testable import WindowAnchor

final class SnapEngineTests: XCTestCase {
    let screen = CGRect(x: 0, y: 25, width: 1600, height: 975) // visible frame under a menu bar

    func testFullCellFillsVisibleFrame() {
        let cell = LayoutCell(x: 0, y: 0, w: 1, h: 1)
        let frame = SnapEngine.frame(for: cell, in: screen, gap: 0, outerPadding: 0)
        XCTAssertEqual(frame, screen.integral)
    }

    func testHalvesShareGapEvenly() {
        let left = SnapEngine.frame(for: LayoutCell(x: 0, y: 0, w: 0.5, h: 1),
                                    in: screen, gap: 10, outerPadding: 0)
        let right = SnapEngine.frame(for: LayoutCell(x: 0.5, y: 0, w: 0.5, h: 1),
                                     in: screen, gap: 10, outerPadding: 0)
        XCTAssertEqual(left.minX, screen.minX)
        XCTAssertEqual(right.maxX, screen.maxX)
        XCTAssertEqual(right.minX - left.maxX, 10, accuracy: 1.5)
        XCTAssertEqual(left.height, screen.height)
    }

    func testOuterPaddingInsetsAllSides() {
        let cell = LayoutCell(x: 0, y: 0, w: 1, h: 1)
        let frame = SnapEngine.frame(for: cell, in: screen, gap: 0, outerPadding: 16)
        XCTAssertEqual(frame.minX, screen.minX + 16, accuracy: 1)
        XCTAssertEqual(frame.minY, screen.minY + 16, accuracy: 1)
        XCTAssertEqual(frame.maxX, screen.maxX - 16, accuracy: 1)
        XCTAssertEqual(frame.maxY, screen.maxY - 16, accuracy: 1)
    }

    func testQuartersDoNotOverlap() {
        let cells = SnapLayout.builtInPresets.first { $0.name == "Quarters" }!.cells
        let frames = cells.map { SnapEngine.frame(for: $0, in: screen, gap: 8, outerPadding: 0) }
        for i in 0..<frames.count {
            for j in (i + 1)..<frames.count {
                XCTAssertFalse(frames[i].insetBy(dx: 1, dy: 1).intersects(frames[j].insetBy(dx: 1, dy: 1)),
                               "quarters \(i) and \(j) overlap")
            }
        }
    }
}

final class SplitNodeTests: XCTestCase {
    func testLeafProducesSingleFullCell() {
        let cells = SplitNode.leaf.cells()
        XCTAssertEqual(cells, [LayoutCell(x: 0, y: 0, w: 1, h: 1)])
    }

    func testHorizontalSplitProducesColumns() {
        let tree = SplitNode.split(axis: .horizontal, ratio: 0.5, first: .leaf, second: .leaf)
        let cells = tree.cells()
        XCTAssertEqual(cells.count, 2)
        XCTAssertEqual(cells[0].w, 0.5, accuracy: 0.001)
        XCTAssertEqual(cells[1].x, 0.5, accuracy: 0.001)
    }

    func testSplittingLeafIncreasesLeafCount() {
        let tree = SplitNode.leaf.splittingLeaf(at: 0, axis: .horizontal)
        XCTAssertEqual(tree.leafCount, 2)
        let deeper = tree.splittingLeaf(at: 1, axis: .vertical)
        XCTAssertEqual(deeper.leafCount, 3)
        // Cells: left column, then right column split into top and bottom.
        let cells = deeper.cells()
        XCTAssertEqual(cells[1].h, 0.5, accuracy: 0.001)
        XCTAssertEqual(cells[2].y, 0.5, accuracy: 0.001)
    }

    func testDeletingLeafGivesSpaceToSibling() {
        let tree = SplitNode.leaf.splittingLeaf(at: 0, axis: .horizontal)
        let collapsed = tree.deletingLeaf(at: 0)
        XCTAssertEqual(collapsed.leafCount, 1)
        XCTAssertEqual(collapsed.cells(), [LayoutCell(x: 0, y: 0, w: 1, h: 1)])
    }

    func testDeletingOnlyLeafIsNoOp() {
        XCTAssertEqual(SplitNode.leaf.deletingLeaf(at: 0), .leaf)
    }

    func testAncestorRatioRoundTrips() {
        let tree = SplitNode.split(axis: .horizontal, ratio: 0.5, first: .leaf, second: .leaf)
        let adjusted = tree.settingAncestorRatio(ofLeaf: 0, to: 0.7)
        XCTAssertEqual(adjusted.ancestorRatio(ofLeaf: 0)!, 0.7, accuracy: 0.001)
        XCTAssertEqual(adjusted.cells()[0].w, 0.7, accuracy: 0.001)
    }

    func testCodableRoundTrip() throws {
        let tree = SplitNode.leaf
            .splittingLeaf(at: 0, axis: .horizontal)
            .splittingLeaf(at: 1, axis: .vertical)
        let data = try JSONEncoder().encode(tree)
        let decoded = try JSONDecoder().decode(SplitNode.self, from: data)
        XCTAssertEqual(decoded, tree)
    }
}

final class EdgeZoneTests: XCTestCase {
    let frame = CGRect(x: 0, y: 0, width: 1600, height: 1000)
    let prefs = Preferences(defaults: UserDefaults(suiteName: "EdgeZoneTests-\(UUID().uuidString)")!)

    func testTopCenterIsFlyoutZone() {
        let zone = EdgeZones.zone(at: CGPoint(x: 800, y: 3), screenFrame: frame, preferences: prefs)
        XCTAssertEqual(zone, .flyout)
    }

    func testLeftEdgeIsHalf() {
        let zone = EdgeZones.zone(at: CGPoint(x: 2, y: 500), screenFrame: frame, preferences: prefs)
        XCTAssertEqual(zone, .leftHalf)
    }

    func testTopLeftCornerIsQuarter() {
        let zone = EdgeZones.zone(at: CGPoint(x: 2, y: 60), screenFrame: frame, preferences: prefs)
        XCTAssertEqual(zone, .topLeftQuarter)
    }

    func testBottomRightCornerIsQuarter() {
        let zone = EdgeZones.zone(at: CGPoint(x: 1598, y: 950), screenFrame: frame, preferences: prefs)
        XCTAssertEqual(zone, .bottomRightQuarter)
    }

    func testTopEdgeAwayFromCenterMaximizes() {
        let zone = EdgeZones.zone(at: CGPoint(x: 400, y: 2), screenFrame: frame, preferences: prefs)
        XCTAssertEqual(zone, .maximize)
    }

    func testMiddleOfScreenIsNoZone() {
        let zone = EdgeZones.zone(at: CGPoint(x: 800, y: 500), screenFrame: frame, preferences: prefs)
        XCTAssertNil(zone)
    }

    func testDisabledFlyoutFallsThroughToMaximize() {
        prefs.layoutFlyoutEnabled = false
        defer { prefs.layoutFlyoutEnabled = true }
        let zone = EdgeZones.zone(at: CGPoint(x: 800, y: 3), screenFrame: frame, preferences: prefs)
        XCTAssertEqual(zone, .maximize)
    }
}

final class PreferencesMergeTests: XCTestCase {
    func testMergeKeepsCustomAndRestoresMissingPresets() {
        let custom = SnapLayout(name: "Mine", cells: [LayoutCell(x: 0, y: 0, w: 1, h: 1)])
        var disabledPreset = SnapLayout.builtInPresets[0]
        disabledPreset.isEnabled = false

        let merged = Preferences.merge(stored: [custom, disabledPreset])

        XCTAssertTrue(merged.contains { $0.id == custom.id })
        XCTAssertEqual(merged.first { $0.id == disabledPreset.id }?.isEnabled, false)
        for preset in SnapLayout.builtInPresets {
            XCTAssertTrue(merged.contains { $0.id == preset.id }, "missing preset \(preset.name)")
        }
        // User ordering preserved: custom first.
        XCTAssertEqual(merged.first?.id, custom.id)
    }

    func testPickerGeometryHitTest() {
        let layouts = Array(SnapLayout.builtInPresets.prefix(3))
        let geometry = PickerGeometry(layoutCount: layouts.count)
        // Center of the first tile's first cell (left half) should hit it.
        let tile = geometry.tileFrame(index: 0)
        let point = CGPoint(x: tile.minX + tile.width * 0.25, y: tile.midY)
        XCTAssertEqual(geometry.hitTest(point, layouts: layouts),
                       PickerTarget(layoutIndex: 0, cellIndex: 0))
        // A point outside every tile hits nothing.
        XCTAssertNil(geometry.hitTest(CGPoint(x: -5, y: -5), layouts: layouts))
    }
}
