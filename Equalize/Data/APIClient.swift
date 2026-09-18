import Foundation

// MARK: - APIClient
// Live AWS backend: https://6oor074vn8.execute-api.us-east-1.amazonaws.com

enum APIError: LocalizedError {
    case badResponse(Int)
    case decodingFailed
    case noToken

    var errorDescription: String? {
        switch self {
        case .badResponse(let code): return "Server returned HTTP \(code)"
        case .decodingFailed: return "Could not parse server response"
        case .noToken: return "Not authenticated"
        }
    }
}

enum APIClient {
    static let apiBaseURL = URL(string: "https://5mkuu6q9kg.execute-api.us-east-1.amazonaws.com")!

    // MARK: - Auth token
    // Provided by CognitoAuthManager once the user is signed in.
    static var idToken: String? = nil

    // MARK: - Helpers

    private static func authorizedRequest(method: String, path: String, body: [String: Any]? = nil) throws -> URLRequest {
        guard let token = idToken else { throw APIError.noToken }
        var request = URLRequest(url: apiBaseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    // MARK: - POST /lectures

    struct InitLectureResponse: Decodable {
        let lessonId: String
        let uploadUrl: String
        let rawS3Key: String
    }

    static func initLecture(userId: String, courseId: String, lessonId: String,
                             title: String, sourceType: String, fileExtension: String) async throws
        -> (lessonId: String, uploadUrl: URL, rawS3Key: String) {
        let req = try authorizedRequest(method: "POST", path: "lectures", body: [
            "userId": userId,
            "courseId": courseId,
            "lessonId": lessonId,
            "title": title,
            "sourceType": sourceType,
            "fileExtension": fileExtension
        ])
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.badResponse((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let decoded = try JSONDecoder().decode(InitLectureResponse.self, from: data)
        guard let url = URL(string: decoded.uploadUrl) else { throw APIError.decodingFailed }
        return (decoded.lessonId, url, decoded.rawS3Key)
    }

    // MARK: - PUT presigned URL (no auth header — presigned URL handles it)

    static func uploadRawFile(to presignedURL: URL, fileURL: URL) async throws {
        let fileData = try Data(contentsOf: fileURL)
        var request = URLRequest(url: presignedURL)
        request.httpMethod = "PUT"
        // S3 Presigned URL expects no Content-Type if it wasn't specified during URL generation
        let (_, response) = try await URLSession.shared.upload(for: request, from: fileData)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.badResponse((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }

    // MARK: - POST /lectures/{id}/complete-upload

    static func completeUpload(lessonId: String, coursePK: String,
                                sourceType: String, rawS3Key: String,
                                rawTranscript: String,
                                slidePhotoKeys: [String] = []) async throws {
        let req = try authorizedRequest(method: "POST", path: "lectures/\(lessonId)/complete-upload", body: [
            "coursePK": coursePK,
            "sourceType": sourceType,
            "rawS3Key": rawS3Key,
            "rawTranscript": rawTranscript,
            "slidePhotoKeys": slidePhotoKeys
        ])
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.badResponse((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }

    // MARK: - GET /lectures/{id}/status

    struct LessonStatusResponse: Decodable {
        let lessonId: String
        let status: String
        let progress: Int?
        let notesS3Key: String?
        let narrationS3Key: String?
        let notesText: String?
        let errorMessage: String?
    }

    static func pollStatus(lessonId: String, coursePK: String) async throws -> LessonStatusResponse {
        var components = URLComponents(url: apiBaseURL.appendingPathComponent("lectures/\(lessonId)/status"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "coursePK", value: coursePK)]
        guard let token = idToken else { throw APIError.noToken }
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.badResponse((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return try JSONDecoder().decode(LessonStatusResponse.self, from: data)
    }
    // MARK: - POST /ask (RAG retrieval)

    struct RetrievedCitation: Decodable {
        let lessonId: String
        let startTimeSec: Double
        let text: String
        let textPreview: String
    }

    struct RetrieveResponse: Decodable {
        let citations: [RetrievedCitation]
        let matchCount: Int
        let error: String?
    }

    static func retrieveContext(question: String, scope: String, lessonId: String? = nil, courseId: String? = nil) async throws -> RetrieveResponse {
        var body: [String: Any] = ["question": question, "scope": scope]
        if let lessonId { body["lessonId"] = lessonId }
        if let courseId { body["courseId"] = courseId }
        let request = try authorizedRequest(method: "POST", path: "ask", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.badResponse((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return try JSONDecoder().decode(RetrieveResponse.self, from: data)
    }

    struct TranslateResponse: Decodable {
        let translatedNotesText: String
        let translatedAudioUrl: String?
        let targetLanguage: String
    }

    static func translateLesson(lessonId: String, courseId: String, targetLanguage: String, pollyVoice: String) async throws -> TranslateResponse {
        let body: [String: Any] = [
            "coursePK": "COURSE#\(courseId)",
            "lessonSK": "LESSON#\(lessonId)",
            "targetLanguage": targetLanguage,
            "pollyVoiceId": pollyVoice
        ]
        let request = try authorizedRequest(method: "POST", path: "lectures/\(lessonId)/translate", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.badResponse((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return try JSONDecoder().decode(TranslateResponse.self, from: data)
    }
}
