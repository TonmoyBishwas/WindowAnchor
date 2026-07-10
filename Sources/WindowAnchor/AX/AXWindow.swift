import AppKit
import ApplicationServices

/// A window controlled through the Accessibility API.
/// All frames are in CG global coordinates (top-left origin, y down).
struct AXWindow: Equatable {
    let element: AXUIElement
    let pid: pid_t

    static func == (lhs: AXWindow, rhs: AXWindow) -> Bool {
        CFEqual(lhs.element, rhs.element)
    }

    // MARK: Lookup

    /// The window under a point in CG global coordinates, found by walking up
    /// from the deepest accessibility element at that point.
    static func at(point: CGPoint) -> AXWindow? {
        let systemWide = AXUIElementCreateSystemWide()
        var elementRef: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &elementRef) == .success,
              let element = elementRef else { return nil }

        var current: AXUIElement? = element
        while let el = current {
            if role(of: el) == kAXWindowRole {
                return wrap(el)
            }
            current = attribute(el, kAXParentAttribute) as! AXUIElement?
        }
        // Fall back to the element's window attribute.
        if let windowRef = attribute(element, kAXWindowAttribute) {
            let win = windowRef as! AXUIElement
            return wrap(win)
        }
        return nil
    }

    private static func wrap(_ element: AXUIElement) -> AXWindow? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return nil }
        return AXWindow(element: element, pid: pid)
    }

    /// All windows of an app, via its AX application element.
    static func windows(ofPid pid: pid_t) -> [AXWindow] {
        let app = AXUIElementCreateApplication(pid)
        guard let value = attribute(app, kAXWindowsAttribute) else { return [] }
        let list = value as! [AXUIElement]
        return list.map { AXWindow(element: $0, pid: pid) }
    }

    // MARK: Attributes

    var title: String? {
        Self.attribute(element, kAXTitleAttribute) as? String
    }

    var role: String? { Self.role(of: element) }

    var subrole: String? {
        Self.attribute(element, kAXSubroleAttribute) as? String
    }

    var isStandard: Bool { subrole == kAXStandardWindowSubrole as String }

    var frame: CGRect? {
        guard let posValue = Self.attribute(element, kAXPositionAttribute),
              let sizeValue = Self.attribute(element, kAXSizeAttribute) else { return nil }
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(posValue as! AXValue, .cgPoint, &origin),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    var isResizable: Bool {
        var settable = DarwinBoolean(false)
        AXUIElementIsAttributeSettable(element, kAXSizeAttribute as CFString, &settable)
        return settable.boolValue
    }

    /// Moves and resizes the window. Position is set before and after the size
    /// change because some apps clamp one based on the other.
    func setFrame(_ rect: CGRect) {
        setPosition(rect.origin)
        setSize(rect.size)
        setPosition(rect.origin)
    }

    func setPosition(_ point: CGPoint) {
        var p = point
        if let value = AXValueCreate(.cgPoint, &p) {
            AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
        }
    }

    func setSize(_ size: CGSize) {
        var s = size
        if let value = AXValueCreate(.cgSize, &s) {
            AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
        }
    }

    /// Raises the window and brings its app forward.
    func raise() {
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        if let app = NSRunningApplication(processIdentifier: pid) {
            app.activate()
        }
    }

    // MARK: Plumbing

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private static func role(of element: AXUIElement) -> String? {
        attribute(element, kAXRoleAttribute) as? String
    }
}
