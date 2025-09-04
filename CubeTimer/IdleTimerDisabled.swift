import SwiftUI
import UIKit

private struct IdleTimerDisabledModifier: ViewModifier {
    var disabled: Bool

    func body(content: Content) -> some View {
        content
            .onAppear { UIApplication.shared.isIdleTimerDisabled = disabled }
            .onChange(of: disabled) {
                UIApplication.shared.isIdleTimerDisabled = disabled
            }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

extension View {
    /// Disables the system's idle timer while `disabled` is `true`, re-enabling it when `false`.
    func idleTimerDisabled(_ disabled: Bool) -> some View {
        modifier(IdleTimerDisabledModifier(disabled: disabled))
    }
}

