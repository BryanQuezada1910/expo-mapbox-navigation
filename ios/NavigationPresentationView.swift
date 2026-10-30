import MapboxNavigationCore
import MapboxNavigationUIKit
import MapboxDirections
import CoreLocation
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
        if let fallbackBanner = plannedFallbackBanner, !fallbackBanner.isHidden {
            view.bringSubviewToFront(fallbackBanner)
        }
        view.bringSubviewToFront(speedLimitIndicator)
        positionSpeedLimitIndicator()
    }

    func positionSpeedLimitIndicator() {
        guard speedLimitIndicator.superview != nil else { return }
        speedLimitTopConstraint?.isActive = false
        let nativeBanner = navigationViewController.flatMap { controller in
            controller.viewIfLoaded?.isDescendant(of: view) == true ? controller.navigationView.topBannerContainerView : nil
        }
        let fallbackBanner = plannedFallbackBanner.flatMap {
            $0.superview != nil && !$0.isHidden ? $0 : nil
        }
        let anchor = nativeBanner.flatMap { $0.isHidden ? nil : $0.bottomAnchor }
            ?? fallbackBanner?.bottomAnchor
            ?? view.safeAreaLayoutGuide.topAnchor
        speedLimitTopConstraint = speedLimitIndicator.topAnchor.constraint(equalTo: anchor, constant: 8)
        speedLimitTopConstraint?.isActive = true
    }

    func extractRouteAnnotatedSpeedLimit(unit: UnitSpeed) -> Double? {
        if let currentLimit = latestGuidanceProgress?.currentLegProgress.currentSpeedLimit?.converted(to: unit).value,
           currentLimit.isFinite, currentLimit > 0 {
            return round(currentLimit)
        }
        let legProgress = latestGuidanceProgress?.currentLegProgress
        let limits = legProgress?.leg.segmentMaximumSpeedLimits
            ?? installedGuidanceRoute?.legs.first?.segmentMaximumSpeedLimits
        guard let limits = limits, !limits.isEmpty else { return nil }
        let baseIndex = min(max(legProgress?.shapeIndex ?? 0, 0), limits.count - 1)
        for offset in 0...8 {
            let forwardIdx = min(baseIndex + offset, limits.count - 1)
            if let value = limits[forwardIdx]?.converted(to: unit).value, value.isFinite, value > 0 {
                return round(value)
            }
            let backwardIdx = max(baseIndex - offset, 0)
            if let value = limits[backwardIdx]?.converted(to: unit).value, value.isFinite, value > 0 {
                return round(value)
            }
        }
        return nil
    }

    func updateSpeedLimit(_ state: MapMatchingState) {
        let coordinate = state.location.coordinate
        let inUS = isUS(lat: coordinate.latitude, lon: coordinate.longitude)
        let nextUnit = inUS ? "mph" : "km/h"
        if nextUnit != lastSpeedUnit {
            lastValidSpeedValue = nil
        }
        lastSpeedUnit = nextUnit
        let unit: UnitSpeed = inUS ? .milesPerHour : .kilometersPerHour
        let liveSpeed = state.speedLimit.value.map { round($0.converted(to: unit).value) }
        let annotatedSpeed = extractRouteAnnotatedSpeedLimit(unit: unit)
        let resolvedSpeed = resolveEffectiveSpeedLimit(
            liveSpeed: liveSpeed,
            routeAnnotatedSpeed: annotatedSpeed,
            lastValidSpeed: lastValidSpeedValue
        )
        if let resolvedSpeed = resolvedSpeed, resolvedSpeed > 0 {
            lastValidSpeedValue = resolvedSpeed
        }
        lastSpeedValue = resolvedSpeed
        refreshSpeedLimit()
        onEvent?("onSpeedLimitChanged", [
            "speedLimit": resolvedSpeed.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }.map { $0 as Any } ?? NSNull(),
            "unit": lastSpeedUnit,
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude,
            "timestamp": Date().timeIntervalSince1970 * 1000
        ])
    }

    func refreshSpeedLimit() {
        speedLimitIndicator.render(.from(speed: lastSpeedValue, unit: lastSpeedUnit, locale: currentLocale))
    }

    func resolveCurrentRoadName() -> String? {
        if let current = currentRoadName?.trimmingCharacters(in: .whitespacesAndNewlines), !current.isEmpty {
            return current
        }
        if let step = latestGuidanceProgress?.currentLegProgress.currentStep {
            if let code = step.codes?.first?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty {
                return code
            }
            if let name = step.names?.first?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                return name
            }
        }
        if let last = lastKnownRoadName?.trimmingCharacters(in: .whitespacesAndNewlines), !last.isEmpty {
            return last
        }
        return nil
    }

    private func makeContinuationBannerInstruction(
        text: String,
        distanceRemaining: CLLocationDistance,
        drivingSide: DrivingSide = .right
    ) -> VisualInstructionBanner {
        let component = VisualInstruction.Component.text(text: .init(
            text: text,
            abbreviation: nil,
            abbreviationPriority: nil
        ))
        let primary = VisualInstruction(
            text: text,
            maneuverType: .continue,
            maneuverDirection: .straightAhead,
            components: [component]
        )
        return VisualInstructionBanner(
            distanceAlongStep: distanceRemaining,
            primary: primary,
            secondary: nil,
            tertiary: nil,
            quaternary: nil,
            drivingSide: drivingSide
        )
    }

    private func ensurePlannedFallbackBanner() -> InstructionsBannerView {
        if let existing = plannedFallbackBanner {
            return existing
        }
        DayStyle().apply()
        let banner = InstructionsBannerView(frame: .zero)
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.swipeable = false
        banner.showStepIndicator = false
        banner.backgroundColor = .white
        banner.layer.cornerRadius = 10
        banner.layer.masksToBounds = true
        view.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            banner.heightAnchor.constraint(greaterThanOrEqualToConstant: 76)
        ])
        plannedFallbackBanner = banner
        return banner
    }

    func refreshPlannedInstructions() {
        guard plannedMode else {
            plannedFallbackBanner?.isHidden = true
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

        let hasPlannedRoute = plannedCoordinates.count >= 2 || (currentCoordinates?.count ?? 0) >= 2
        let continuationText = plannedContinuationInstruction(roadName: resolveCurrentRoadName(), locale: currentLocale)
        let stepDistance = step?.distanceRemaining
            ?? progress?.distanceRemaining
            ?? lastPlannedProgress?["distanceRemaining"]
            ?? 0

        if let banner = navigationViewController?.view.findViews(subclassOf: InstructionsBannerView.self).first {
            plannedFallbackBanner?.isHidden = true
            banner.distanceFormatter.locale = currentLocale
            if canPresent, let instruction = instruction, let step = step {
                // Reapply the current instruction when rejoining, without waiting for a new instruction event.
                banner.update(for: instruction)
                banner.updateDistance(for: step)
                if let nextBanner = navigationViewController?.view.findViews(subclassOf: NextBannerView.self).first,
                   isArtificialArrival(finalChunk: finalRouteChunk, instructionType: instruction.quaternaryInstruction?.maneuverType?.rawValue) {
                    nextBanner.isHidden = true
                }
                navigationViewController?.navigationView.topBannerContainerView.isHidden = false
            } else if shouldPresentPlannedBanner(planned: true, hasNativeManeuver: false, hasPlannedRoute: hasPlannedRoute) {
                let continuation = makeContinuationBannerInstruction(
                    text: continuationText,
                    distanceRemaining: stepDistance,
                    drivingSide: instruction?.drivingSide ?? .right
                )
                banner.update(for: continuation)
                banner.distance = stepDistance > 5 ? stepDistance : nil
                navigationViewController?.view.findViews(subclassOf: NextBannerView.self).forEach { $0.isHidden = true }
                navigationViewController?.navigationView.topBannerContainerView.isHidden = false
            } else {
                navigationViewController?.navigationView.topBannerContainerView.isHidden = true
            }
        } else if shouldPresentPlannedBanner(planned: true, hasNativeManeuver: false, hasPlannedRoute: hasPlannedRoute) {
            let fallbackBanner = ensurePlannedFallbackBanner()
            fallbackBanner.distanceFormatter.locale = currentLocale
            let continuation = makeContinuationBannerInstruction(
                text: continuationText,
                distanceRemaining: stepDistance
            )
            fallbackBanner.update(for: continuation)
            fallbackBanner.distance = stepDistance > 5 ? stepDistance : nil
            fallbackBanner.isHidden = false
            view.bringSubviewToFront(fallbackBanner)
        } else {
            plannedFallbackBanner?.isHidden = true
        }
        installNavigationIndicators()
    }
}
