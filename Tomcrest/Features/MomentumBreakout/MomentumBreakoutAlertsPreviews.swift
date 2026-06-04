import SwiftUI

#if DEBUG
#Preview("Pending alert card") {
    AppPreview.environments {
        ScrollView {
            MomentumBreakoutAlertCard(alert: MomentumBreakoutAlertMocks.pending)
                .padding()
        }
        .appCanvasScreen()
    }
}

#Preview("Open alert card") {
    AppPreview.environments {
        ScrollView {
            MomentumBreakoutAlertCard(alert: MomentumBreakoutAlertMocks.open)
                .padding()
        }
        .appCanvasScreen()
    }
}

#Preview("Target hit card") {
    AppPreview.environments {
        ScrollView {
            MomentumBreakoutAlertCard(alert: MomentumBreakoutAlertMocks.targetHit)
                .padding()
        }
        .appCanvasScreen()
    }
}

#Preview("Stop hit card") {
    AppPreview.environments {
        ScrollView {
            MomentumBreakoutAlertCard(alert: MomentumBreakoutAlertMocks.stopHit)
                .padding()
        }
        .appCanvasScreen()
    }
}

#Preview("Blocked risk gate card") {
    AppPreview.environments {
        ScrollView {
            MomentumBreakoutAlertCard(alert: MomentumBreakoutAlertMocks.blockedRiskGate)
                .padding()
        }
        .appCanvasScreen()
    }
}

#Preview("Warning risk gate card") {
    AppPreview.environments {
        ScrollView {
            MomentumBreakoutAlertCard(alert: MomentumBreakoutAlertMocks.warningRiskGate)
                .padding()
        }
        .appCanvasScreen()
    }
}

#Preview("Alerts panel") {
    AppPreview.environments {
        let auth = AuthSession()
        let vm = MomentumBreakoutAlertsViewModel(auth: auth)
        vm.disclaimer = MomentumBreakoutAlertMocks.disclaimer
        vm.activeAlerts = [MomentumBreakoutAlertMocks.pending, MomentumBreakoutAlertMocks.open]
        vm.historyAlerts = [
            MomentumBreakoutAlertMocks.targetHit,
            MomentumBreakoutAlertMocks.stopHit,
        ]
        return ScrollView {
            MomentumBreakoutAlertsView(viewModel: vm)
                .padding()
        }
        .appCanvasScreen()
    }
}
#endif
