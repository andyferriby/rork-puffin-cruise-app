import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

/// Generates QR codes on-device so passes work without a network round trip.
enum QRCode {
    private static let context = CIContext()

    static func image(from string: String, scale: CGFloat = 10) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let transformed = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// Displays a QR code for any payload, matching the app's navy-on-white pass style.
struct QRCodeView: View {
    let value: String
    var size: CGFloat = 160

    var body: some View {
        Group {
            if let image = QRCode.image(from: value) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .frame(width: size, height: size)
        .padding(10)
        .background(.white)
        .clipShape(.rect(cornerRadius: 16))
    }
}
