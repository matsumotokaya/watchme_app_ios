//
//  NetworkConfiguration.swift
//  ios_watchme_v9
//
//  ネットワーク設定とS3アクセス対応
//

import Foundation

// MARK: - Network Configuration
extension URLSession {
    /// S3リダイレクトに対応したカスタムURLSession
    static let s3Compatible: URLSession = {
        let configuration = URLSessionConfiguration.default
        
        // リダイレクトを自動的に処理
        configuration.httpMaximumConnectionsPerHost = 5
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        
        // キャッシュ設定
        configuration.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024, // 50MB
            diskCapacity: 200 * 1024 * 1024,  // 200MB
            diskPath: "avatar_cache"
        )
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        
        return URLSession(configuration: configuration)
    }()
}

// MARK: - S3 URL Helper
struct S3URLHelper {
    /// S3 URLをリダイレクト対応形式に変換
    static func normalizeS3URL(_ urlString: String) -> String {
        // us-east-1形式のURLをap-southeast-2形式に変換
        if urlString.contains("s3.us-east-1.amazonaws.com") {
            return urlString.replacingOccurrences(
                of: "s3.us-east-1.amazonaws.com",
                with: "s3.ap-southeast-2.amazonaws.com"
            )
        }
        return urlString
    }
    
    /// URLSessionを使用してS3画像を読み込む
    static func loadS3Image(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.s3Compatible.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // リダイレクトも成功として扱う
        guard (200...399).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return data
    }
}