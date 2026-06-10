import Foundation

struct AIProviderClient: Sendable {
    private let proto: AIProviderProtocol

    init(proto: AIProviderProtocol) {
        self.proto = proto
    }

    func executeQuery(
        prompt: String,
        images: [String],
        telemetryCallback: ((String) -> Void)?
    ) async throws -> String {
        telemetryCallback?("📡 Preparing API request …")

        var urlRequest: URLRequest = try proto.buildRequest(
            prompt: prompt,
            images: images,
            telemetryCallback: telemetryCallback
        )

        urlRequest.timeoutInterval = proto.timeoutsConfig.requestTimeoutInterval

        telemetryCallback?("🌐 Sending request …")
        do {
            telemetryCallback?("⏳ Waiting for response from AI …")

            #if DEBUG
                if let promptData = prompt.data(using: .utf8) {
                    saveDebugDataToTempFile(description: "AI prompt", fileName: "ai-prompt.txt", data: promptData)
                }
            #endif

            let (data, httpResponse): (Data, HTTPURLResponse) = try await performRequestWithRetry(
                request: urlRequest,
                telemetryCallback: telemetryCallback
            )

            guard !data.isEmpty else {
                print("AI response body is empty (HTTP \(httpResponse.statusCode))")
                throw AIFoodAnalysisError.invalidResponse
            }

            telemetryCallback?("🔍 Parsing AI response …")

            let content = try proto.extractResponse(data: data, telemetryCallback: telemetryCallback)

            telemetryCallback?("⚡ Processing AI analysis results …")

            return content
        } catch let error as AIFoodAnalysisError {
            throw error
        } catch {
            throw AIFoodAnalysisError.networkError(error)
        }
    }

    private func createSession() -> URLSession {
        let timeouts = proto.timeoutsConfig
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeouts.timeoutIntervalForRequest
        config.timeoutIntervalForResource = timeouts.timeoutIntervalForResource
        return URLSession(configuration: config)
    }

    private func performRequest(
        request: URLRequest,
        attempt: Int,
        maxRetries: Int,
        telemetryCallback: ((String) -> Void)?
    ) async throws -> (Data, URLResponse) {
        if attempt != 1 {
            telemetryCallback?("🔄 Attempt \(attempt)/\(maxRetries) …")
        }

        let session = createSession()
        do {
            let (data, response) = try await session.data(for: request)
            return (data, response)
        } catch {
            if let urlError = error as? URLError, urlError.code == .timedOut {
                throw AIFoodAnalysisError.timeout
            }
            print("Request failed (attempt \(attempt)/\(maxRetries)): \(error)")
            throw error
        }
    }

    /// Führt den Request aus und validiert die Antwort über das Provider-
    /// Protokoll. Die Status-Auswertung passiert bewusst INNERHALB der
    /// Retry-Schleife: Überlastung (503/529 → `serviceUnavailable`) ist
    /// transient und wird mit Backoff wiederholt, ebenso Timeouts (gemäß
    /// `numberOfRetries` des Providers). Alle anderen Fehler brechen ab.
    private func performRequestWithRetry(
        request: URLRequest,
        telemetryCallback: ((String) -> Void)?
    ) async throws -> (Data, HTTPURLResponse) {
        let maxTimeoutAttempts = proto.numberOfRetries
        let maxOverloadAttempts = 3
        var timeoutAttempts = 0
        var overloadAttempts = 0

        while true {
            do {
                let (data, response) = try await performRequest(
                    request: request,
                    attempt: timeoutAttempts + overloadAttempts + 1,
                    maxRetries: maxTimeoutAttempts,
                    telemetryCallback: telemetryCallback
                )

                saveDebugDataToTempFile(description: "AI response", fileName: "ai-response.txt", data: data)

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Expected HTTPURLResponse but got \(type(of: response))")
                    throw AIFoodAnalysisError.invalidResponse
                }

                try proto.handleErrorResponse(httpResponse: httpResponse, data: data, telemetryCallback: telemetryCallback)

                return (data, httpResponse)

            } catch AIFoodAnalysisError.timeout {
                timeoutAttempts += 1
                print("Request timed out (attempt \(timeoutAttempts)/\(maxTimeoutAttempts))")
                guard timeoutAttempts < maxTimeoutAttempts else {
                    throw AIFoodAnalysisError.timeout
                }
                let backoffDelay = Double(timeoutAttempts) * 2.0
                telemetryCallback?("⏳ retry in \(Int(backoffDelay))s …")
                try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))

            } catch let error as AIFoodAnalysisError {
                guard case .serviceUnavailable = error else { throw error }
                overloadAttempts += 1
                print("Service overloaded (attempt \(overloadAttempts)/\(maxOverloadAttempts))")
                guard overloadAttempts < maxOverloadAttempts else { throw error }
                let backoffDelay = Double(overloadAttempts) * 3.0
                telemetryCallback?("⏳ Service overloaded — retrying in \(Int(backoffDelay))s …")
                try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
            }
        }
    }
}

protocol AIProviderProtocol: Sendable {
    var numberOfRetries: Int { get }

    var timeoutsConfig: ModelTimeoutsConfig { get }

    func buildRequest(
        prompt: String,
        images: [String],
        telemetryCallback: ((String) -> Void)?
    ) throws -> URLRequest

    func handleErrorResponse(
        httpResponse: HTTPURLResponse,
        data: Data,
        telemetryCallback: ((String) -> Void)?
    ) throws

    func extractResponse(
        data: Data,
        telemetryCallback: ((String) -> Void)?
    ) throws -> String
}
