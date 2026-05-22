//
//  WatchHTTPIngestClient.swift
//  SauronWatch
//
//  Mirrors iOS Connection HTTP headers for OwnTracks HTTP mode.
//

import Foundation

struct WatchHTTPConfig: Codable, Equatable {
    var httpURL: String
    var authBasic: Bool
    var user: String
    var pass: String
    var limitU: String
    var limitD: String
    /// Same format as iOS: newline-separated "Key: Value" lines (see Connection.connectHTTP:).
    var httpHeaderLines: String
    var trackerId: String?
    /// Same as iOS device id (`theDeviceIdInMOC`); echoed in JSON as `deviceId`.
    var deviceId: String?
    /// MQTT publish topic (`theGeneralTopicInMOC`); echoed in JSON as `topic`.
    var publishTopic: String?
    var includeExtendedData: Bool
    /// Optional OAuth refresh endpoint for `WatchOAuthRefresher` (future).
    var oauthRefreshURL: String?
    var oauthClientId: String?
    /// Watch-specific ingest URL synced from iPhone `watch_webhook_url_preference`.
    var watchWebhookURL: String?

    /// Matches default in iOS `HTTP.plist` until phone sync delivers an override.
    static let bundledWatchWebhookURL = "https://homeassistant.tlaska.com/api/webhook/applewatch"

    static var empty: WatchHTTPConfig {
        WatchHTTPConfig(httpURL: "", authBasic: false, user: "user", pass: "", limitU: "user", limitD: "device", httpHeaderLines: "", trackerId: nil, deviceId: nil, publishTopic: nil, includeExtendedData: true, oauthRefreshURL: nil, oauthClientId: nil, watchWebhookURL: nil)
    }

    /// URL used for POSTs: phone-synced watch webhook, else phone `httpURL`, else bundled default.
    var effectiveIngestURL: String {
        if let w = watchWebhookURL?.trimmingCharacters(in: .whitespacesAndNewlines), !w.isEmpty {
            return w
        }
        let http = httpURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !http.isEmpty {
            return http
        }
        return Self.bundledWatchWebhookURL
    }
}

final class WatchHTTPIngestClient {
    private let session: URLSession

    init() {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 60
        cfg.timeoutIntervalForResource = 120
        session = URLSession(configuration: cfg)
    }

    func upload(point: QueuedLocationPoint, config: WatchHTTPConfig, bearerToken: String?) async throws {
        let urlString = config.effectiveIngestURL
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            throw URLError(.badURL)
        }
        let data = try LocationPayloadBuilder.jsonData(for: point, config: config)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(point.idempotencyKey, forHTTPHeaderField: "X-Idempotency-Key")
        Self.applyAuthAndCustomHeaders(to: &request, config: config, bearerToken: bearerToken)

        let (_, response) = try await session.data(for: request)
        try Self.validate(response: response)
    }

    /// One POST for up to `points.count` locations; `X-Idempotency-Key` matches `batchId` for safe retries.
    func uploadBatch(points: [QueuedLocationPoint], batchId: UUID, config: WatchHTTPConfig, bearerToken: String?) async throws {
        guard !points.isEmpty else { return }
        let urlString = config.effectiveIngestURL
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            throw URLError(.badURL)
        }
        let data = try LocationPayloadBuilder.batchJsonData(batchId: batchId, points: points, config: config)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(batchId.uuidString, forHTTPHeaderField: "X-Idempotency-Key")
        Self.applyAuthAndCustomHeaders(to: &request, config: config, bearerToken: bearerToken)

        let (_, response) = try await session.data(for: request)
        try Self.validate(response: response)
    }

    private static func applyAuthAndCustomHeaders(to request: inout URLRequest, config: WatchHTTPConfig, bearerToken: String?) {
        if config.authBasic {
            let authString = "\(config.user):\(config.pass)"
            if let authData = authString.data(using: .ascii) {
                let encoded = authData.base64EncodedString()
                request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
            }
        } else if let bearer = bearerToken, !bearer.isEmpty {
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }

        request.setValue(config.limitU, forHTTPHeaderField: "X-Limit-U")
        request.setValue(config.limitD, forHTTPHeaderField: "X-Limit-D")

        let lines = config.httpHeaderLines.split(separator: "\n", omittingEmptySubsequences: false)
        for line in lines {
            if let r = line.range(of: ":") {
                let key = line[..<r.lowerBound].trimmingCharacters(in: .whitespaces)
                let value = line[r.upperBound...].trimmingCharacters(in: .whitespaces)
                if !key.isEmpty {
                    request.setValue(String(value), forHTTPHeaderField: String(key))
                }
            }
        }
    }

    private static func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.statusCode == 401 {
            throw URLError(.userAuthenticationRequired)
        }
        guard (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
