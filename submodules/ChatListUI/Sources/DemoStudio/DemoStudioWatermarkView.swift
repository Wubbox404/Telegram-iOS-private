import Foundation
import UIKit

/// Persistent disclosure for every screen rendered by the modified client.
/// Keep this class separate and attach it only from TelegramRootController.
public final class DemoStudioWatermarkView: UILabel {
    public override init(frame: CGRect) {
        super.init(frame: frame)

        self.text = "ДЕМО"
        self.textColor = UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor.white.withAlphaComponent(0.23)
            } else {
                return UIColor.black.withAlphaComponent(0.18)
            }
        }
        self.font = UIFont.systemFont(ofSize: 13.0, weight: .semibold)
        self.textAlignment = .right
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = 0.35
        self.layer.shadowRadius = 2.0
        self.layer.shadowOffset = CGSize(width: 0.0, height: 1.0)
        self.isUserInteractionEnabled = false
        self.accessibilityLabel = "Демонстрационная версия"
        self.translatesAutoresizingMaskIntoConstraints = false
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
