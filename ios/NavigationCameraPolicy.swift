import Foundation

/// Normalized camera following state used across UIKit NavigationViewController and fallback MapView.
enum NavigationCameraMode: Equatable {
    case idle
    case following
    case overview
}

/// Exclusive visibility state for the Android-parity camera controls.
struct NavigationCameraButtonState: Equatable {
    let isOverviewVisible: Bool
    let isRecenterVisible: Bool
}

/// Pure state coordinator that keeps manual user pan/zoom gestures in `.idle`
/// and prevents asynchronous viewport reassignments from snapping the camera back to `.following`.
final class NavigationCameraPolicy {
    private(set) var mode: NavigationCameraMode = .following
    private(set) var pendingPreservedMode: NavigationCameraMode?

    var buttonState: NavigationCameraButtonState {
        NavigationCameraButtonState(
            isOverviewVisible: mode == .following,
            isRecenterVisible: mode != .following
        )
    }

    var shouldFollowLocationUpdates: Bool {
        mode == .following
    }

    func userDidInteractWithMap() {
        mode = .idle
        pendingPreservedMode = nil
    }

    func requestOverview() {
        mode = .overview
        pendingPreservedMode = nil
    }

    func requestFollowing() {
        mode = .following
        pendingPreservedMode = nil
    }

    func prepareForAttachment(preserving previousMode: NavigationCameraMode?) {
        if let previousMode = previousMode {
            mode = previousMode
        }
        pendingPreservedMode = mode == .following ? nil : mode
    }

    func willReassignViewportDataSource() {
        if mode != .following {
            pendingPreservedMode = mode
        }
    }

    /// Reconciles an SDK camera state emission with any preserved non-following state.
    /// Returns a mode to immediately re-apply if the SDK unexpectedly reset to `.following`.
    func didObserveCameraState(_ observed: NavigationCameraMode) -> NavigationCameraMode? {
        if observed == .following, let preserved = pendingPreservedMode {
            pendingPreservedMode = nil
            mode = preserved
            return preserved
        }
        if observed != .following {
            pendingPreservedMode = nil
        }
        mode = observed
        return nil
    }

    func reset() {
        mode = .following
        pendingPreservedMode = nil
    }
}

