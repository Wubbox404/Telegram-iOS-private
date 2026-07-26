import Foundation
import UIKit

enum DemoModeUI {
    static let telegramBlue = UIColor(red: 0.20, green: 0.56, blue: 0.93, alpha: 1.0)
    static let outgoingBlue = UIColor(red: 0.20, green: 0.43, blue: 1.00, alpha: 1.0)
    static let incomingDark = UIColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 0.96)
    static let groupedDark = UIColor(red: 0.105, green: 0.105, blue: 0.115, alpha: 1.0)
    static let cyan = UIColor(red: 0.20, green: 0.78, blue: 0.96, alpha: 1.0)

    static func image(assetName: String, fallbackSystemName: String) -> UIImage? {
        return UIImage(named: assetName) ?? UIImage(systemName: fallbackSystemName)
    }

    static func avatarImage(profile: DemoProfile, size: CGSize) -> UIImage {
        if let data = profile.avatarData, let image = UIImage(data: data) {
            return image
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor(hex: profile.accentHex).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let initials = profile.name
                .split(separator: " ")
                .prefix(2)
                .compactMap(\.first)
                .map(String.init)
                .joined()
                .uppercased()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size.width * 0.38, weight: .semibold),
                .foregroundColor: UIColor.white
            ]
            let textSize = initials.size(withAttributes: attributes)
            let point = CGPoint(
                x: (size.width - textSize.width) * 0.5,
                y: (size.height - textSize.height) * 0.5
            )
            initials.draw(at: point, withAttributes: attributes)
        }
    }

    static func makeGlassEffectView(interactive: Bool = false) -> UIVisualEffectView {
        if #available(iOS 26.0, *) {
            let glassEffect = UIGlassEffect()
            glassEffect.isInteractive = interactive
            return UIVisualEffectView(effect: glassEffect)
        } else {
            return UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
        }
    }

    static func configureTable(_ tableView: UITableView) {
        tableView.backgroundColor = .black
        tableView.separatorColor = UIColor(white: 1.0, alpha: 0.10)
        tableView.keyboardDismissMode = .interactive
        tableView.indicatorStyle = .white
    }
}

extension UIColor {
    convenience init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: UInt64
        let green: UInt64
        let blue: UInt64
        let alpha: UInt64
        switch cleaned.count {
        case 8:
            red = (value >> 24) & 0xff
            green = (value >> 16) & 0xff
            blue = (value >> 8) & 0xff
            alpha = value & 0xff
        default:
            red = (value >> 16) & 0xff
            green = (value >> 8) & 0xff
            blue = value & 0xff
            alpha = 0xff
        }
        self.init(
            red: CGFloat(red) / 255.0,
            green: CGFloat(green) / 255.0,
            blue: CGFloat(blue) / 255.0,
            alpha: CGFloat(alpha) / 255.0
        )
    }
}

final class DemoModeAvatarView: UIImageView {
    init(profile: DemoProfile, size: CGFloat) {
        super.init(frame: CGRect(origin: .zero, size: CGSize(width: size, height: size)))
        self.image = DemoModeUI.avatarImage(profile: profile, size: CGSize(width: size * 2.0, height: size * 2.0))
        self.contentMode = .scaleAspectFill
        self.layer.cornerRadius = size * 0.5
        self.layer.masksToBounds = true
        self.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.widthAnchor.constraint(equalToConstant: size),
            self.heightAnchor.constraint(equalToConstant: size)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class DemoModeWatermarkView: UILabel {
    init() {
        super.init(frame: .zero)
        self.text = "ДЕМО"
        self.font = UIFont.systemFont(ofSize: 11.0, weight: .bold)
        self.textColor = UIColor.white.withAlphaComponent(0.26)
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = 0.8
        self.layer.shadowRadius = 4.0
        self.layer.shadowOffset = CGSize(width: 0.0, height: 1.0)
        self.isUserInteractionEnabled = false
        self.translatesAutoresizingMaskIntoConstraints = false
        self.accessibilityLabel = "Демонстрационный режим"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
