import Foundation

/// Editing operations for the custom layout editor. Leaves are addressed by
/// their DFS index, which matches the order of `cells(in:)`.
extension SplitNode {
    /// Replaces the leaf at `index` with a 50/50 split.
    func splittingLeaf(at index: Int, axis: Axis) -> SplitNode {
        var counter = 0
        return replacingLeaf(at: index, counter: &counter) {
            .split(axis: axis, ratio: 0.5, first: .leaf, second: .leaf)
        }
    }

    /// Removes the leaf at `index`; its sibling absorbs the space.
    /// Deleting the only leaf returns the tree unchanged.
    func deletingLeaf(at index: Int) -> SplitNode {
        guard case .split = self else { return self }
        var counter = 0
        return deletingLeafImpl(at: index, counter: &counter) ?? .leaf
    }

    /// The split ratio of the nearest ancestor of the leaf at `index`.
    func ancestorRatio(ofLeaf index: Int) -> Double? {
        nearestAncestor(ofLeaf: index)?.ratio
    }

    /// Sets the split ratio of the nearest ancestor of the leaf at `index`.
    func settingAncestorRatio(ofLeaf index: Int, to ratio: Double) -> SplitNode {
        var counter = 0
        return settingRatioImpl(ofLeaf: index, to: ratio, counter: &counter).node
    }

    // MARK: Implementation

    private func replacingLeaf(at index: Int, counter: inout Int,
                               with replacement: () -> SplitNode) -> SplitNode {
        switch self {
        case .leaf:
            defer { counter += 1 }
            return counter == index ? replacement() : self
        case let .split(axis, ratio, first, second):
            let newFirst = first.replacingLeaf(at: index, counter: &counter, with: replacement)
            let newSecond = second.replacingLeaf(at: index, counter: &counter, with: replacement)
            return .split(axis: axis, ratio: ratio, first: newFirst, second: newSecond)
        }
    }

    /// Returns nil when this entire subtree is the deleted leaf.
    private func deletingLeafImpl(at index: Int, counter: inout Int) -> SplitNode? {
        switch self {
        case .leaf:
            defer { counter += 1 }
            return counter == index ? nil : self
        case let .split(axis, ratio, first, second):
            let newFirst = first.deletingLeafImpl(at: index, counter: &counter)
            let newSecond = second.deletingLeafImpl(at: index, counter: &counter)
            switch (newFirst, newSecond) {
            case let (a?, b?): return .split(axis: axis, ratio: ratio, first: a, second: b)
            case let (a?, nil): return a
            case let (nil, b?): return b
            case (nil, nil): return nil
            }
        }
    }

    private func nearestAncestor(ofLeaf index: Int) -> (axis: Axis, ratio: Double)? {
        var counter = 0
        return nearestAncestorImpl(ofLeaf: index, counter: &counter).found
    }

    private func nearestAncestorImpl(ofLeaf index: Int, counter: inout Int)
        -> (contains: Bool, found: (axis: Axis, ratio: Double)?) {
        switch self {
        case .leaf:
            defer { counter += 1 }
            return (counter == index, nil)
        case let .split(axis, ratio, first, second):
            let a = first.nearestAncestorImpl(ofLeaf: index, counter: &counter)
            if a.contains { return (true, a.found ?? (axis, ratio)) }
            let b = second.nearestAncestorImpl(ofLeaf: index, counter: &counter)
            if b.contains { return (true, b.found ?? (axis, ratio)) }
            return (false, nil)
        }
    }

    private func settingRatioImpl(ofLeaf index: Int, to newRatio: Double, counter: inout Int)
        -> (node: SplitNode, contains: Bool, applied: Bool) {
        switch self {
        case .leaf:
            defer { counter += 1 }
            return (self, counter == index, false)
        case let .split(axis, ratio, first, second):
            let a = first.settingRatioImpl(ofLeaf: index, to: newRatio, counter: &counter)
            if a.contains {
                let applied = a.applied
                let node = SplitNode.split(axis: axis, ratio: applied ? ratio : newRatio,
                                           first: a.node, second: second)
                return (node, true, true)
            }
            let b = second.settingRatioImpl(ofLeaf: index, to: newRatio, counter: &counter)
            if b.contains {
                let applied = b.applied
                let node = SplitNode.split(axis: axis, ratio: applied ? ratio : newRatio,
                                           first: a.node, second: b.node)
                return (node, true, true)
            }
            return (.split(axis: axis, ratio: ratio, first: a.node, second: b.node), false, false)
        }
    }
}
