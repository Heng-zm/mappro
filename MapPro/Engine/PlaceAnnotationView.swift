import UIKit

final class PlaceAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "PlaceAnnotationView"

    private let bubble = UIView()
    private let iconView = UIImageView()
    private let tailLayer = CAShapeLayer()
    private let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 17, weight: .bold)

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setup()
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var annotation: MKAnnotation? {
        didSet { configure() }
    }

    private func setup() {
        frame = CGRect(x: 0, y: 0, width: 44, height: 52)
        backgroundColor = .clear
        clipsToBounds = false
        canShowCallout = false
        centerOffset = CGPoint(x: 0, y: -26)
        displayPriority = .defaultHigh
        collisionMode = .circle

        let path = UIBezierPath()
        path.move(to: CGPoint(x: 14, y: 33))
        path.addLine(to: CGPoint(x: 22, y: 51))
        path.addLine(to: CGPoint(x: 30, y: 33))
        path.close()

        tailLayer.path = path.cgPath
        tailLayer.lineWidth = 1
        tailLayer.strokeColor = UIColor.white.withAlphaComponent(0.9).cgColor
        layer.addSublayer(tailLayer)

        bubble.frame = CGRect(x: 4, y: 2, width: 36, height: 36)
        bubble.layer.cornerRadius = 18
        bubble.layer.borderWidth = 2.5
        bubble.layer.borderColor = UIColor.white.cgColor
        bubble.layer.shadowColor = UIColor.black.cgColor
        bubble.layer.shadowOffset = CGSize(width: 0, height: 3)
        bubble.layer.shadowRadius = 5
        bubble.layer.shadowOpacity = 0.22
        bubble.isUserInteractionEnabled = false
        addSubview(bubble)

        iconView.frame = bubble.bounds
        iconView.contentMode = .center
        iconView.tintColor = .white
        bubble.addSubview(iconView)
    }

    private func configure() {
        guard let placeAnnotation = annotation as? PlaceAnnotation else { return }
        let color = UIColor(placeAnnotation.place.tint)
        bubble.backgroundColor = color
        tailLayer.fillColor = color.cgColor
        iconView.image = UIImage(
            systemName: placeAnnotation.place.symbolName,
            withConfiguration: symbolConfiguration
        )
    }

    func setChosen(_ chosen: Bool, animated: Bool) {
        let changes = {
            self.transform = chosen ? CGAffineTransform(scaleX: 1.18, y: 1.18) : .identity
            self.bubble.layer.shadowOpacity = chosen ? 0.36 : 0.22
            self.bubble.layer.shadowRadius = chosen ? 9 : 5
        }
        layer.zPosition = chosen ? 100 : 0

        if animated {
            UIView.animate(
                withDuration: 0.24,
                delay: 0,
                usingSpringWithDamping: 0.72,
                initialSpringVelocity: 0.4,
                options: [.beginFromCurrentState, .allowUserInteraction, .allowAnimatedContent],
                animations: changes
            )
        } else {
            changes()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        transform = .identity
        layer.zPosition = 0
    }
}
