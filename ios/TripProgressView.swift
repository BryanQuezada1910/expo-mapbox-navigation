import UIKit
import MapboxNavigationUIKit

extension ExpoMapboxNavigationViewController {
    func setShowTripProgress(show: Bool?) {
        showTripProgress = show ?? true
        updateTripProgressVisibility()
    }

    func setBottomLegend(legend: String?) {
        currentBottomLegend = legend
        updateTripProgressVisibility()
    }

    func updateTripProgressVisibility() {
        navigationViewController?.navigationView.bottomBannerContainerView.isHidden = !showTripProgress || plannedMode
        plannedProgressLabel?.isHidden = !showTripProgress || !plannedMode
        bottomLegendLabel?.text = currentBottomLegend
        bottomLegendLabel?.isHidden = !showTripProgress || (currentBottomLegend?.isEmpty ?? true)
    }
}
