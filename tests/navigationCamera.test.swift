import Foundation

@main
struct NavigationCameraTests {
    static func main() {
        let policy = NavigationCameraPolicy()

        // Starts in following mode with overview visible and recenter hidden.
        precondition(policy.mode == .following)
        precondition(policy.shouldFollowLocationUpdates)
        precondition(policy.buttonState == NavigationCameraButtonState(isOverviewVisible: true, isRecenterVisible: false))

        // Manual pan/zoom switches to idle, stops location re-centering, and reveals recenter button.
        policy.userDidInteractWithMap()
        precondition(policy.mode == .idle)
        precondition(!policy.shouldFollowLocationUpdates)
        precondition(policy.buttonState == NavigationCameraButtonState(isOverviewVisible: false, isRecenterVisible: true))

        // Viewport replacement while idle intercepts SDK .following reset back to .idle.
        policy.willReassignViewportDataSource()
        precondition(policy.didObserveCameraState(.following) == .idle)
        precondition(policy.mode == .idle)
        precondition(policy.buttonState == NavigationCameraButtonState(isOverviewVisible: false, isRecenterVisible: true))

        // Requesting full route overview switches buttons to recenter mode and disables auto-follow.
        policy.requestOverview()
        precondition(policy.mode == .overview)
        precondition(!policy.shouldFollowLocationUpdates)
        precondition(policy.buttonState == NavigationCameraButtonState(isOverviewVisible: false, isRecenterVisible: true))

        // Transitioning from fallback map to NavigationViewController preserves non-following mode.
        policy.userDidInteractWithMap()
        policy.prepareForAttachment(preserving: .idle)
        precondition(policy.didObserveCameraState(.following) == .idle)
        precondition(policy.mode == .idle)

        // Explicit recenter re-enables following and swaps buttons back to overview.
        policy.requestFollowing()
        precondition(policy.mode == .following)
        precondition(policy.shouldFollowLocationUpdates)
        precondition(policy.buttonState == NavigationCameraButtonState(isOverviewVisible: true, isRecenterVisible: false))
        precondition(policy.didObserveCameraState(.following) == nil)

        // Reset restores default following state.
        policy.requestOverview()
        policy.reset()
        precondition(policy.mode == .following)
        precondition(policy.buttonState == NavigationCameraButtonState(isOverviewVisible: true, isRecenterVisible: false))

        print("iOS NavigationCameraPolicy tests passed")
    }
}

