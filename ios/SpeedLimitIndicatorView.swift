import UIKit

final class SpeedLimitIndicatorView: UIView {
    private let label = UILabel()

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .white
        layer.cornerRadius = 32
        layer.borderWidth = 3
        isAccessibilityElement = true
        label.numberOfLines = 2
        label.textAlignment = .center
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 64),
            heightAnchor.constraint(equalToConstant: 64),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        render(.from(speed: nil, unit: "km/h"))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func render(_ presentation: SpeedLimitPresentation) {
        label.text = presentation.text
        label.font = .systemFont(ofSize: presentation.available ? 16 : 14, weight: .bold)
        layer.borderColor = (presentation.available ? UIColor.red : UIColor.darkGray).cgColor
        accessibilityLabel = presentation.description
    }
}
