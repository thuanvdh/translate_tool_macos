import Foundation

enum AppError: Error, Equatable, LocalizedError {
    case emptyInput
    case inputTooLong(limit: Int)
    case missingAPIKey
    case accessibilityPermissionMissing
    case selectionUnavailable
    case unauthorized
    case rateLimited
    case network(String)
    case timeout
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "No text was provided."
        case .inputTooLong(let limit):
            return "Selected text is too long. Please select up to \(limit) characters."
        case .missingAPIKey:
            return "OpenAI API key is missing."
        case .accessibilityPermissionMissing:
            return "Accessibility permission is required to read selected text."
        case .selectionUnavailable:
            return "Selected text could not be read from the current app."
        case .unauthorized:
            return "OpenAI rejected the API key."
        case .rateLimited:
            return "OpenAI rate limit reached. Please try again later."
        case .network(let message):
            return "Network error: \(message)"
        case .timeout:
            return "The translation request timed out."
        case .invalidResponse:
            return "The translation response could not be read."
        }
    }
}
