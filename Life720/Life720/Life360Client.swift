//
//  Life360Client.swift
//  Life720
//
//  Created by Sol Kim on 10/21/25.
//

import Foundation
import UIKit

final class Life360Client {
    private let baseURL = URL(string: "https://api-cloudfront.life360.com")!
    private let deviceId: String = UIDevice.current.identifierForVendor?.uuidString.uppercased() ?? UUID().uuidString.uppercased()
    private let userAgent: String
    private let authBasic = ConfigLoader.life360BasicAuth
    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()
    private let cookieStorage: HTTPCookieStorage

    init() {
        let id = UIDevice.current.identifierForVendor?.uuidString.uppercased() ?? UUID().uuidString.uppercased()
        userAgent = "SafetyMapKoko/25.41.0.1674/\(id)"
        cookieStorage = HTTPCookieStorage.shared
    }

    func makeStdHeaders(includeAuth: Bool = true, bearer: String? = nil) -> [String: String] {
        var h: [String: String] = [
            "accept": "application/json",
            "accept-language": "en-US",
            "accept-encoding": "gzip",
            "content-type": "application/json",
            "user-agent": userAgent,
            "x-device-id": deviceId,
            "x-request-id": UUID().uuidString.uppercased()
        ]
        if includeAuth {
            if let b = bearer {
                h["authorization"] = "Bearer \(b)"
            } else {
                h["authorization"] = authBasic
            }
        }
        return h
    }

    func makeCloudEventHeaders(type: String) -> [String: String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let time = formatter.string(from: Date())
        return [
            "ce-specversion": "1.0",
            "ce-id": UUID().uuidString.uppercased(),
            "ce-time": time,
            "ce-type": type,
            "ce-source": "/iOS/25.41.0.1674/iPhone16,1/\(deviceId)"
        ]
    }

    func sendOTP(phone: String, country: String, logger: @escaping (String) -> Void) async throws -> String {
        let endpoint = "/v5/users/signin/otp/send"
        let url = baseURL.appendingPathComponent(endpoint)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"

        var headers = makeStdHeaders()
        makeCloudEventHeaders(type: "com.life360.device.signin-otp.v2").forEach { headers[$0] = $1 }
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }

        let payload = ["countryCode": country, "nationalNumber": phone]
        req.httpBody = try jsonEncoder.encode(payload)

        logger("→ REQUEST: POST \(url.absoluteString)")
        logger("Headers: \(headers)")
        if let bodyStr = String(data: req.httpBody ?? Data(), encoding: .utf8) {
            logger("Body: \(bodyStr)")
        }

        let (data, response) = try await urlSession().data(for: req)
        try await inspectResponse(data: data, response: response, label: "Send OTP", logger: logger)
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        if let dataObj = json?["data"] as? [String: Any], let tx = dataObj["transactionId"] as? String {
            return tx
        }
        throw URLError(.badServerResponse)
    }

    func verifyOTP(transactionId: String, code: String, logger: @escaping (String) -> Void) async throws -> String {
        let endpoint = "/v5/users/signin/otp/token"
        let url = baseURL.appendingPathComponent(endpoint)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"

        var headers = makeStdHeaders()
        makeCloudEventHeaders(type: "com.life360.device.signin-token-otp.v1").forEach { headers[$0] = $1 }
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }

        let payload = ["transactionId": transactionId, "code": code]
        req.httpBody = try jsonEncoder.encode(payload)

        logger("→ REQUEST: POST \(url.absoluteString)")
        logger("Headers: \(headers)")
        if let bodyStr = String(data: req.httpBody ?? Data(), encoding: .utf8) {
            logger("Body: \(bodyStr)")
        }

        let (data, response) = try await urlSession().data(for: req)
        try await inspectResponse(data: data, response: response, label: "Verify OTP", logger: logger)
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        if let token = json?["access_token"] as? String {
            return token
        }
        throw URLError(.badServerResponse)
    }

    func getUserProfile(bearer: String, logger: @escaping (String) -> Void) async throws -> String {
        let endpoint = "/v3/users/me"
        let url = baseURL.appendingPathComponent(endpoint)
        var req = URLRequest(url: url)
        req.httpMethod = "GET"

        let headers = makeStdHeaders(includeAuth: true, bearer: bearer)
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }

        logger("→ REQUEST: GET \(url.absoluteString)")
        logger("Headers: \(headers)")

        let (data, response) = try await urlSession().data(for: req)
        try await inspectResponse(data: data, response: response, label: "Get Profile", logger: logger)
        return String(data: data, encoding: .utf8) ?? "<binary>"
    }

    func getCircles(bearer: String, logger: @escaping (String) -> Void) async throws -> String {
        let endpoint = "/v4/circles"
        let url = baseURL.appendingPathComponent(endpoint)
        var req = URLRequest(url: url)
        req.httpMethod = "GET"

        let headers = makeStdHeaders(includeAuth: true, bearer: bearer)
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }

        logger("→ REQUEST: GET \(url.absoluteString)")
        logger("Headers: \(headers)")

        let (data, response) = try await urlSession().data(for: req)
        try await inspectResponse(data: data, response: response, label: "Get Circles", logger: logger)
        return String(data: data, encoding: .utf8) ?? "<binary>"
    }

    func getCircleMembers(circleId: String, bearer: String, logger: @escaping (String) -> Void) async throws -> String {
        let endpoint = "/v4/circles/\(circleId)/members"
        let url = baseURL.appendingPathComponent(endpoint)
        var req = URLRequest(url: url)
        req.httpMethod = "GET"

        let headers = makeStdHeaders(includeAuth: true, bearer: bearer)
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }

        logger("→ REQUEST: GET \(url.absoluteString)")
        logger("Headers: \(headers)")

        let (data, response) = try await urlSession().data(for: req)
        try await inspectResponse(data: data, response: response, label: "Get Members", logger: logger)
        return String(data: data, encoding: .utf8) ?? "<binary>"
    }
    
    func getCircleDeviceLocations(circleId: String, bearer: String, logger: @escaping (String) -> Void) async throws -> String {
        let endpoint = "/v5/circles/devices/locations"
        guard var components = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "providers[]", value: "jiobit"),
            URLQueryItem(name: "providers[]", value: "life360"),
            URLQueryItem(name: "providers[]", value: "tile")
        ]
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"

        var headers = makeStdHeaders(includeAuth: true, bearer: bearer)
        makeCloudEventHeaders(type: "com.life360.cloud.platform.devices.locations.v1").forEach { headers[$0] = $1 }
        headers["circleid"] = circleId
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }

        logger("→ REQUEST: GET \(url.absoluteString)")
        logger("Headers: \(headers)")

        let (data, response) = try await urlSession().data(for: req)
        try await inspectResponse(data: data, response: response, label: "Get Circle Device Locations", logger: logger)
        return String(data: data, encoding: .utf8) ?? "<binary>"
    }

    private func inspectResponse(data: Data, response: URLResponse, label: String, logger: @escaping (String) -> Void) async throws {
        guard let http = response as? HTTPURLResponse else {
            logger("✗ Non-HTTP response during \(label)")
            throw URLError(.badServerResponse)
        }

        let headers = http.allHeaderFields.reduce(into: [String: String]()) { $0["\($1.key)"] = "\($1.value)" }
        let bodyString = String(data: data, encoding: .utf8) ?? "<non-text body>"

        if !(200...299).contains(http.statusCode) {
            logger("✗ Request failed during \(label)")
            logger("Status code: \(http.statusCode)")
            logger("Response headers: \(headers)")
            logger("Response body: \(bodyString)")
            throw URLError(.badServerResponse)
        } else {
            logger("✓ \(label) succeeded (\(http.statusCode))")
            logger("Response headers: \(headers)")
            logger("Body: \(bodyString)")
        }
    }

    private func urlSession() -> URLSession {
        let cfg = URLSessionConfiguration.default
        cfg.httpCookieStorage = cookieStorage
        cfg.httpShouldSetCookies = true
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 60
        cfg.httpAdditionalHeaders = ["User-Agent": userAgent]
        return URLSession(configuration: cfg)
    }
}

