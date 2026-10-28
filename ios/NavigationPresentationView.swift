import MapboxNavigationCore
import MapboxNavigationUIKit
import MapboxDirections
import UIKit

extension ExpoMapboxNavigationViewController {
    func installNavigationIndicators() {
        loadViewIfNeeded()
        if speedLimitIndicator.superview == nil {
            view.addSubview(speedLimitIndicator)
            NSLayoutConstraint.activate([
                speedLimitIndicator.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16)
            ])
        }
        navigationViewController?.navigationView.speedLimitView.isAlwaysHidden = true
        view.bringSubviewToFront(speedLimitIndicator)
        positionSpeedLimitIndicator()
    }

    func positionSpeedLimitIndicator() {
        guard speedLimitIndicator.superview != nil else { return }
        speedLimitTopConstraint?.isActive = false
        let nativeBanner = navigationViewController.flatMap { controller in
            controller.viewIfLoaded?.isDescendant(of: view) == true ? controller.navigationView.topBannerContainerView : nil
        }
        let anchor = nativeBanner.flatMap { $0.isHidden ? nil : $0.bottomAnchor }
            ?? view.safeAreaLayoutGuide.topAnchor
        speedLimitTopConstraint = speedLimitIndicator.topAnchor.constraint(equalTo: anchor, constant: 8)
        speedLimitTopConstraint?.isActive = true
    }

    func updateSpeedLimit(_ state: MapMatchingState) {
        let coordinate = state.location.coordinate
        let inUS = isUS(lat: coordinate.latitude, lon: coordinate.longitude)
        let unit: UnitSpeed = inUS ? .milesPerHour : .kilometersPerHour
        let speed = state.speedLimit.value?.converted(to: unit).value
        lastSpeedValue = speed
        lastSpeedUnit = inUS ? "mph" : "km/h"
        refreshSpeedLimit()
        onEvent?("onSpeedLimitChanged", [
            "speedLimit": speed.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }.map { $0 as Any } ?? NSNull(),
            "unit": lastSpeedUnit,
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude,
            "timestamp": Date().timeIntervalSince1970 * 1000
        ])
    }

    func refreshSpeedLimit() {
        speedLimitIndicator.render(.from(speed: lastSpeedValue, unit: lastSpeedUnit, locale: currentLocale))
    }

    func refreshPlannedInstructions() {
        guard plannedMode else {
            navigationViewController?.navigationView.topBannerContainerView.isHidden = false
            positionSpeedLimitIndicator()
            return
        }
        let progress = latestGuidanceProgress
        let step = progress?.currentLegProgress.currentStepProgress
        let instruction = step?.currentVisualInstruction
        let instructionType = instruction?.primaryInstruction.maneuverType?.rawValue
            ?? progress?.currentLegProgress.currentStep.maneuverType.rawValue
        let canPresent = canPresentNativeManeuver(
            planned: true, enabled: guidanceEnabled && guidanceStatus == "available", revisionMatches: installedRouteRevision == routeRevision,
            onRoute: isOnPlannedRoute, finalChunk: finalRouteChunk,
            instructionType: instructionType, hasInstruction: instruction != nil
        )
        let suppressed = !canPresent
        let synthesizer = ExpoMapboxNavigationViewController.navigationProvider.routeVoiceController.speechSynthesizer
        if !guidanceWasSuppressed { requestedMute = synthesizer.muted }
        if suppressed { synthesizer.stopSpeaking() }
        synthesizer.muted = requestedMute || suppressed
        guidanceWasSuppressed = suppressed

        var showsNativeInstruction = false
        if canPresent, let instruction = instruction, let step = step,
           let banner = navigationViewController?.view.findViews(subclassOf: InstructionsBannerView.self).first {
            // Reapply the current instruction when rejoining, without waiting for a new instruction event.
            banner.update(for: instruction)
            banner.updateDistance(for: step)
            showsNativeInstruction = true
        }
        navigationViewController?.navigationView.topBannerContainerView.isHidden = !showsNativeInstruction
        installNavigationIndicators()
    }
}
