import UIKit

/// Floating trailing camera controls matching Android: toggles between full-route overview and resume-following.
final class NavigationCameraControlsView: UIView {
    let overviewButton = UIButton(type: .system)
    let recenterButton = UIButton(type: .system)

    var onOverviewTap: (() -> Void)?
    var onRecenterTap: (() -> Void)?

    private static let buttonSize: CGFloat = 48

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        configureActionButton(
            overviewButton,
            symbolNames: ["point.topleft.down.curvedto.point.bottomright.up", "arrow.up.left.and.arrow.down.right", "map"],
            accessibilityIdentifier: "expoMapboxOverviewButton",
            action: #selector(handleOverviewTap)
        )

        configureActionButton(
            recenterButton,
            symbolNames: ["location.fill", "location"],
            accessibilityIdentifier: "expoMapboxRecenterButton",
            action: #selector(handleRecenterTap)
        )

        recenterButton.isHidden = true

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.buttonSize),
            heightAnchor.constraint(equalToConstant: Self.buttonSize)
        ])
    }

    private func configureActionButton(
        _ button: UIButton,
        symbolNames: [String],
        accessibilityIdentifier: String,
        action: Selector
    ) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityIdentifier = accessibilityIdentifier
        button.tintColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? .white : UIColor(white: 0.14, alpha: 1.0)
        }
        button.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 0.16, alpha: 0.94) : UIColor.white.withAlphaComponent(0.96)
        }
        button.layer.cornerRadius = Self.buttonSize / 2
        button.layer.borderWidth = 0.5
        button.layer.borderColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 1.0, alpha: 0.16) : UIColor(white: 0.0, alpha: 0.1)
        }.cgColor
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.2
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 6

        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let image = symbolNames.lazy.compactMap { UIImage(systemName: $0, withConfiguration: config) }.first
        button.setImage(image, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)

        addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        let borderColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 1.0, alpha: 0.16) : UIColor(white: 0.0, alpha: 0.1)
        }.resolvedColor(with: traitCollection).cgColor
        overviewButton.layer.borderColor = borderColor
        recenterButton.layer.borderColor = borderColor
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        subviews.contains { subview in
            !subview.isHidden && subview.isUserInteractionEnabled && subview.frame.contains(point)
        }
    }

    func update(buttonState: NavigationCameraButtonState, strings: NavigationStrings) {
        overviewButton.isHidden = !buttonState.isOverviewVisible
        overviewButton.accessibilityLabel = strings.overviewRoute
        recenterButton.isHidden = !buttonState.isRecenterVisible
        recenterButton.accessibilityLabel = strings.followLocation
        isHidden = !buttonState.isOverviewVisible && !buttonState.isRecenterVisible
    }

    @objc private func handleOverviewTap() {
        onOverviewTap?()
    }

    @objc private func handleRecenterTap() {
        onRecenterTap?()
    }
}

