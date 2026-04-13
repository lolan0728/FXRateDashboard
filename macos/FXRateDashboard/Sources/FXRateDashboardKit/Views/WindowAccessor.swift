import AppKit
import SwiftUI

public struct WindowAccessor: NSViewRepresentable {
    private let onResolve: (NSWindow) -> Void

    public init(onResolve: @escaping (NSWindow) -> Void) {
        self.onResolve = onResolve
    }

    public func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }

        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onResolve(window)
            }
        }
    }
}
