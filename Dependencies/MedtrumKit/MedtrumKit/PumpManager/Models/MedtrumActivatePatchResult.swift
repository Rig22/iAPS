public enum MedtrumActivatePatchResult {
    case success
    case failure(error: MedtrumActivatePatchError)
}

public enum MedtrumActivatePatchError: LocalizedError {
    case connectionFailure(reason: String)
    case unknownError(reason: String)
    
    public var errorDescription: String? {
        switch self {
            case let .connectionFailure(reason: reason):
            return "Connection failure: \(reason)"
        case let .unknownError(reason: reason):
            return "Unknown error: \(reason)"
        }
    }
}
