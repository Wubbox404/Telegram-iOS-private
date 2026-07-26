import UIKit

final class DemoModeImagePicker: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private var completion: ((UIImage) -> Void)?

    func present(from controller: UIViewController, completion: @escaping (UIImage) -> Void) {
        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
            return
        }
        self.completion = completion
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.image"]
        picker.allowsEditing = true
        picker.delegate = self
        controller.present(picker, animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.completion = nil
        picker.dismiss(animated: true)
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        let completion = self.completion
        self.completion = nil
        picker.dismiss(animated: true) {
            if let image {
                completion?(image)
            }
        }
    }
}
