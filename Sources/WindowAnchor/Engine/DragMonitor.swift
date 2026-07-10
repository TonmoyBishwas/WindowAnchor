import AppKit
import ApplicationServices

protocol DragMonitorDelegate: AnyObject {
    /// A window drag was confirmed (the window is tracking the cursor).
    func dragBegan(window: AXWindow, at location: CGPoint)
    /// The cursor moved during a confirmed drag.
    func dragMoved(to location: CGPoint, optionDown: Bool)
    /// The mouse button was released during a confirmed drag.
    func dragEnded(at location: CGPoint)
}

/// Watches global mouse events through a listen-only CGEventTap and detects
/// when the user is dragging a window: at mouse-down it captures the AX window
/// under the cursor, and the drag is confirmed once the window's position
/// tracks the cursor movement.
final class DragMonitor {
    weak var delegate: DragMonitorDelegate?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Per-gesture state
    private var mouseDownLocation: CGPoint?
    private var candidateWindow: AXWindow?
    private var candidateStartFrame: CGRect?
    private var dragConfirmed = false
    private var lastFrameCheck: CFTimeInterval = 0

    private let ownPid = ProcessInfo.processInfo.processIdentifier

    func start() {
        guard tap == nil else { return }
        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<DragMonitor>.fromOpaque(refcon).takeUnretainedValue()
            monitor.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        ) else {
            NSLog("WindowAnchor: failed to create event tap (missing Accessibility permission?)")
            return
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        runLoopSource = nil
        tap = nil
        resetGesture()
    }

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .leftMouseDown:
            beginGesture(at: event.location)
        case .leftMouseDragged:
            continueGesture(at: event.location, flags: event.flags)
        case .leftMouseUp:
            endGesture(at: event.location)
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        default:
            break
        }
    }

    private func beginGesture(at location: CGPoint) {
        resetGesture()
        mouseDownLocation = location
        guard let window = AXWindow.at(point: location),
              window.pid != ownPid,
              window.isStandard || window.subrole == nil else { return }
        candidateWindow = window
        candidateStartFrame = window.frame
    }

    private func continueGesture(at location: CGPoint, flags: CGEventFlags) {
        guard let downAt = mouseDownLocation else { return }

        if dragConfirmed {
            delegate?.dragMoved(to: location, optionDown: flags.contains(.maskAlternate))
            return
        }

        guard let window = candidateWindow, let startFrame = candidateStartFrame else { return }

        let mouseDelta = CGPoint(x: location.x - downAt.x, y: location.y - downAt.y)
        let mouseDistance = hypot(mouseDelta.x, mouseDelta.y)
        guard mouseDistance > 8 else { return }

        // Reading AX frames is not free; sample at most every 50 ms.
        let now = CACurrentMediaTime()
        guard now - lastFrameCheck > 0.05 else { return }
        lastFrameCheck = now

        guard let frame = window.frame else { return }
        let windowDelta = CGPoint(x: frame.minX - startFrame.minX, y: frame.minY - startFrame.minY)
        let windowDistance = hypot(windowDelta.x, windowDelta.y)

        // The window counts as "being dragged" when it moved roughly with the
        // cursor. Tolerance is generous: apps may lag behind the cursor.
        if windowDistance > 4,
           abs(windowDelta.x - mouseDelta.x) < 100,
           abs(windowDelta.y - mouseDelta.y) < 100 {
            dragConfirmed = true
            delegate?.dragBegan(window: window, at: location)
            delegate?.dragMoved(to: location, optionDown: flags.contains(.maskAlternate))
        }
    }

    private func endGesture(at location: CGPoint) {
        if dragConfirmed {
            delegate?.dragEnded(at: location)
        }
        resetGesture()
    }

    private func resetGesture() {
        mouseDownLocation = nil
        candidateWindow = nil
        candidateStartFrame = nil
        dragConfirmed = false
        lastFrameCheck = 0
    }
}
