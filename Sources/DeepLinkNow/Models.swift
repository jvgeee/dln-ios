import Foundation
import UIKit
import CoreTelephony
import AdSupport

// Configuration
public struct DLNConfig {
    let apiKey: String
    let enableLogs: Bool
    
    public init(apiKey: String, enableLogs: Bool = false) {
        self.apiKey = apiKey
        self.enableLogs = enableLogs
    }
}

// Error types
public enum DLNError: Error {
    case invalidURL
    case serverError
    case notInitialized
}

// Attribution data
public struct DLNAttribution: Codable {
    public let campaign: String?
    public let source: String?
    public let medium: String?
}

// Custom parameters
public struct DLNCustomParameters {
    let dictionary: [String: Any]
    
    public init(_ parameters: [String: Any]) {
        self.dictionary = parameters
    }
}

// DeferredDeepLinkResponse for checkDeferredDeepLink method
public struct DeferredDeepLinkResponse: Codable {
    let deepLink: String?
    let attribution: DLNAttribution?
    
    enum CodingKeys: String, CodingKey {
        case deepLink = "deep_link"
        case attribution
    }
}

// DLNDeviceFingerprint for checkDeferredDeepLink method
public struct DLNDeviceFingerprint {
    let deviceModel: String
    let systemVersion: String
    let screenResolution: String
    let timezone: String
    let language: String
    let carrier: String?
    let ipAddress: String?
    let advertisingIdentifier: String?
    
    public static func generate() -> DLNDeviceFingerprint {
        let device = UIDevice.current
        let screen = UIScreen.main
        let screenSize = screen.bounds.size
        let scale = screen.scale
        let resolution = "\(Int(screenSize.width * scale))x\(Int(screenSize.height * scale))"
        
        var carrierName: String? = nil
        if #available(iOS 12.0, *) {
            let networkInfo = CTTelephonyNetworkInfo()
            let carrier = networkInfo.serviceSubscriberCellularProviders?.values.first
            carrierName = carrier?.carrierName
        }
        
        return DLNDeviceFingerprint(
            deviceModel: device.model,
            systemVersion: device.systemVersion,
            screenResolution: resolution,
            timezone: TimeZone.current.identifier,
            language: Locale.current.languageCode ?? "en",
            carrier: carrierName,
            ipAddress: nil,
            advertisingIdentifier: ASIdentifierManager.shared().isAdvertisingTrackingEnabled ? 
                ASIdentifierManager.shared().advertisingIdentifier.uuidString : nil
        )
    }
}

// Fingerprint model for device information
public struct Fingerprint: Codable {
    let userAgent: String
    let platform: String
    let osVersion: String
    let deviceModel: String
    let language: String
    let timezone: String
    let installedAt: String
    let lastOpenedAt: String
    let deviceId: String?
    let advertisingId: String?
    let vendorId: String?
    let hardwareFingerprint: String?
    
    enum CodingKeys: String, CodingKey {
        case userAgent = "user_agent"
        case platform
        case osVersion = "os_version"
        case deviceModel = "device_model"
        case language
        case timezone
        case installedAt = "installed_at"
        case lastOpenedAt = "last_opened_at"
        case deviceId = "device_id"
        case advertisingId = "advertising_id"
        case vendorId = "vendor_id"
        case hardwareFingerprint = "hardware_fingerprint"
    }
}

public struct DeeplinkMatch: Codable {
    let id: String
    let targetUrl: String
    let metadata: [String: AnyCodable]
    let campaignId: String?
    let matchedAt: String
    let expiresAt: String
    let attribution: DLNAttribution?
    
    enum CodingKeys: String, CodingKey {
        case id
        case targetUrl = "target_url"
        case metadata
        case campaignId = "campaign_id"
        case matchedAt = "matched_at"
        case expiresAt = "expires_at"
        case attribution
    }
}

public struct MatchResponse: Codable {
    public let match: Match
    public let deepLink: String?
    public let attribution: DLNAttribution?
    
    private enum CodingKeys: String, CodingKey {
        case match
        case deepLink = "deep_link"
        case attribution
    }
    
    public struct Match: Codable {
        public let deeplink: DeeplinkMatch?
        public let confidenceScore: Double
        public let ttlSeconds: Int
        public let fingerprint: Fingerprint?
        
        private enum CodingKeys: String, CodingKey {
            case deeplink
            case confidenceScore = "confidence_score"
            case ttlSeconds = "ttl_seconds"
            case fingerprint
        }
    }
}

public struct InitResponse: Codable {
    let app: App
    let account: Account
    
    public struct App: Codable {
        let id: String
        let name: String
        let timezone: String
        let androidPackageName: String?
        let androidSha256Cert: String?
        let iosBundleId: String?
        let iosAppStoreId: String?
        let iosAppPrefix: String?
        let customDomains: [CustomDomain]
        
        enum CodingKeys: String, CodingKey {
            case id, name, timezone
            case androidPackageName = "android_package_name"
            case androidSha256Cert = "android_sha256_cert"
            case iosBundleId = "ios_bundle_id"
            case iosAppStoreId = "ios_app_store_id"
            case iosAppPrefix = "ios_app_prefix"
            case customDomains = "custom_domains"
        }
        
        public struct CustomDomain: Codable {
            let domain: String?
            let verified: Bool?
        }
    }
    
    public struct Account: Codable {
        let status: String
        let creditsRemaining: Int
        let rateLimits: RateLimits
        
        enum CodingKeys: String, CodingKey {
            case status
            case creditsRemaining = "credits_remaining"
            case rateLimits = "rate_limits"
        }
        
        public struct RateLimits: Codable {
            let matchesPerSecond: Int
            let matchesPerDay: Int
            
            enum CodingKeys: String, CodingKey {
                case matchesPerSecond = "matches_per_second"
                case matchesPerDay = "matches_per_day"
            }
        }
    }
}

// Helper for handling dynamic JSON values
public struct AnyCodable: Codable {
    let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self.value = value
        } else if let value = try? container.decode(Int.self) {
            self.value = value
        } else if let value = try? container.decode(Double.self) {
            self.value = value
        } else if let value = try? container.decode(Bool.self) {
            self.value = value
        } else if let value = try? container.decode([String: AnyCodable].self) {
            self.value = value
        } else if let value = try? container.decode([AnyCodable].self) {
            self.value = value
        } else {
            self.value = NSNull()
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let value as String:
            try container.encode(value)
        case let value as Int:
            try container.encode(value)
        case let value as Double:
            try container.encode(value)
        case let value as Bool:
            try container.encode(value)
        case let value as [String: AnyCodable]:
            try container.encode(value)
        case let value as [AnyCodable]:
            try container.encode(value)
        default:
            try container.encodeNil()
        }
    }
}

// Protocol for testable networking
public protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

// Make URLSession conform to the protocol
extension URLSession: URLSessionProtocol {}

// Helper extensions
public extension URLComponents {
    init(_ configure: (inout URLComponents) -> Void) {
        self.init()
        configure(&self)
    }
} 