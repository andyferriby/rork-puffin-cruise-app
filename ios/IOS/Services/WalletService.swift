import Foundation
import PassKit
import UIKit

enum WalletError: LocalizedError {
    case notSupported
    case notAvailable
    case invalidPass

    var errorDescription: String? {
        switch self {
        case .notSupported: return "Apple Wallet isn't available on this device."
        case .notAvailable: return "Wallet passes are not yet configured for this app. Please contact the operator."
        case .invalidPass: return "The pass file returned by the server was invalid."
        }
    }
}

@MainActor
enum WalletService {
    /// Fetches a signed .pkpass from the backend for a given booking and presents the
    /// system PKAddPassesViewController. Returns true on success, throws otherwise.
    static func addToWallet(bookingId: String, presenter: UIViewController?) async throws {
        guard PKPassLibrary.isPassLibraryAvailable() else {
            throw WalletError.notSupported
        }

        let base = Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL
        guard let url = URL(string: "\(base)/wallet/pass?bookingId=\(bookingId)") else {
            throw WalletError.notAvailable
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.apple.pkpass", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw WalletError.notAvailable
        }

        let pass: PKPass
        do {
            pass = try PKPass(data: data)
        } catch {
            throw WalletError.invalidPass
        }

        guard let addVC = PKAddPassesViewController(pass: pass) else {
            throw WalletError.invalidPass
        }
        presenter?.present(addVC, animated: true)
    }
}
