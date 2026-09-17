import Foundation
import AuthenticationServices

// MARK: - CognitoAuthManager
// Authenticates against the deployed Cognito User Pool using SRP (via AWS Cognito's InitiateAuth API).
// No Amplify dependency needed — we call the Cognito Identity Provider REST API directly.
//
// Pool: us-east-1_YHRnrKH23
// Client: 6apsklu7pu39ommup3dq415ibh

@Observable
@MainActor
final class CognitoAuthManager {
    static let shared = CognitoAuthManager()

    private let region = "us-east-1"
    private let clientId = "6apsklu7pu39ommup3dq415ibh"
    private let cognitoEndpoint = URL(string: "https://cognito-idp.us-east-1.amazonaws.com/")!

    var isAuthenticated = false
    var currentUserId: String = ""
    var errorMessage: String?

    // MARK: - Sign In

    func signIn(username: String, password: String) async {
        do {
            let body: [String: Any] = [
                "AuthFlow": "USER_PASSWORD_AUTH",
                "ClientId": clientId,
                "AuthParameters": [
                    "USERNAME": username,
                    "PASSWORD": password
                ]
            ]
            var request = URLRequest(url: cognitoEndpoint)
            request.httpMethod = "POST"
            request.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
            request.setValue("AWSCognitoIdentityProviderService.InitiateAuth", forHTTPHeaderField: "X-Amz-Target")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let errBody = String(data: data, encoding: .utf8) ?? "unknown"
                errorMessage = "Auth failed: \(errBody)"
                return
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let authResult = json?["AuthenticationResult"] as? [String: Any],
                  let idToken = authResult["IdToken"] as? String,
                  let accessToken = authResult["AccessToken"] as? String else {
                errorMessage = "Unexpected auth response"
                return
            }

            // Store tokens
            APIClient.idToken = idToken
            UserDefaults.standard.set(idToken, forKey: "equalize_id_token")
            UserDefaults.standard.set(accessToken, forKey: "equalize_access_token")

            // Extract sub (user ID) from the ID token payload
            currentUserId = extractSub(from: idToken) ?? username
            isAuthenticated = true
            errorMessage = nil

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Restore Session

    func restoreSession() {
        guard let savedToken = UserDefaults.standard.string(forKey: "equalize_id_token") else { return }
        // Basic JWT expiry check (exp claim)
        if !isTokenExpired(savedToken) {
            APIClient.idToken = savedToken
            currentUserId = extractSub(from: savedToken) ?? "user"
            isAuthenticated = true
        }
    }

    func signOut() {
        APIClient.idToken = nil
        UserDefaults.standard.removeObject(forKey: "equalize_id_token")
        UserDefaults.standard.removeObject(forKey: "equalize_access_token")
        isAuthenticated = false
        currentUserId = ""
    }

    // MARK: - JWT helpers

    private func extractSub(from jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1])
        // Pad base64 to multiple of 4
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String else { return nil }
        return sub
    }

    private func isTokenExpired(_ jwt: String) -> Bool {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else { return true }
        var base64 = String(parts[1])
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else { return true }
        return Date().timeIntervalSince1970 > exp
    }
}
