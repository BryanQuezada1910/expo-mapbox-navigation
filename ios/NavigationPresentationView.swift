import MapboxNavigationCore
import MapboxNavigationUIKit
import MapboxDirections
import UIKit

extension ExpoMapboxNavigationViewController {
    func installNavigationIndicators() {
        loadViewIfNeeded()
        if guidanceStatusBanner.superview == nil {
            view.addSubview(guidanceStatusBanner)
            view.addSubview(speedLimitIndicator)
            NSLayoutConstraint.activate([
                guidanceStatusBanner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
                guidanceStatusBanner.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 4),
                guidanceStatusBanner.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -4),
                speedLimitIndicator.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16)
            ])
        }
        navigationViewController?.navigationView.speedLimitView.isAlwaysHidden = true
        view.bringSubviewToFront(guidanceStatusBanner)
        view.bringSubviewToFront(speedLimitIndicator)
        positionSpeedLimitIndicator()
    }

    func positionSpeedLimitIndicator() {
        guard guidanceStatusBanner.superview != nil else { return }
        speedLimitTopConstraint?.isActive = false
        let nativeBanner = navigationViewController.flatMap { controller in
            controller.viewIfLoaded?.isDescendant(of: view) == true ? controller.navigationView.topBannerContainerView : nil
        }
        let anchor = guidanceStatusBanner.isHidden
            ? nativeBanner?.bottomAnchor ?? guidanceStatusBanner.bottomAnchor
            : guidanceStatusBanner.bottomAnchor
        speedLimitTopConstraint = speedLimitIndicator.topAnchor.constraint(equalTo: anchor, constant: 8)
        speedLimitTopConstraint?.isActive = true
    }

    func updateSpeedLimit(_ state: MapMatchingState) {
        let coordinate = state.location.coordinate
        let inUS = isUS(lat: coordinate.latitude, lon: coordinate.longitude)
        let unit: UnitSpeed = inUS ? .milesPerHour : .kilometersPerHour
        let speed = state.speedLimit.value?.converted(to: unit).value
        speedLimitIndicator.render(.from(speed: speed, unit: inUS ? "mph" : "km/h"))
    }

    func refreshPlannedInstructions() {
        guard plannedMode else {
            navigationViewController?.navigationView.topBannerContainerView.isHidden = false
            guidanceStatusBanner.show(nil)
            positionSpeedLimitIndicator()
            return
        }
        let progress = latestGuidanceProgress
        let step = progress?.currentLegProgress.currentStepProgress
        let instruction = step?.currentVisualInstruction
        let instructionType = instruction?.primaryInstruction.maneuverType?.rawValue
            ?? progress?.currentLegProgress.currentStep.maneuverType.rawValue
        let enabled = guidanceEnabled && installedRouteRevision == routeRevision && isOnPlannedRoute != false
        let roadName = currentRoadName ?? progress?.currentLegProgress.currentStep.names?.joined(separator: " ")
        let message = plannedGuidanceMessage(status: guidanceStatus, enabled: enabled, onRoute: isOnPlannedRoute)
        let suppressed = !enabled || isArtificialArrival(finalChunk: finalRouteChunk, instructionType: instructionType)
        let synthesizer = ExpoMapboxNavigationViewController.navigationProvider.routeVoiceController.speechSynthesizer
        if !guidanceWasSuppressed { requestedMute = synthesizer.muted }
        if suppressed { synthesizer.stopSpeaking() }
        synthesizer.muted = requestedMute || suppressed
        guidanceWasSuppressed = suppressed

        var showsNativeInstruction = false
        if let message = message {
            guidanceStatusBanner.show(message)
        } else {
            if enabled, !isArtificialArrival(finalChunk: finalRouteChunk, instructionType: instructionType),
               let instruction = instruction, let step = step,
               let banner = navigationViewController?.view.findViews(subclassOf: InstructionsBannerView.self).first {
                // Reapply the current instruction when rejoining, even without a new instruction event.
                banner.update(for: instruction)
                banner.updateDistance(for: step)
                showsNativeInstruction = true
                guidanceStatusBanner.show(nil)
            } else {
                guidanceStatusBanner.showContinuation(roadName: roadName)
            }
        }
        navigationViewController?.navigationView.topBannerContainerView.isHidden = !showsNativeInstruction
        installNavigationIndicators()
    }
}
