//
//  Configuration.swift
//  ios_watchme_v9
//
//  Avatar Uploader API設定
//

import Foundation

// MARK: - API Configuration
struct APIConfiguration {
    
    // MARK: - Avatar Uploader API
    struct AvatarUploader {
        // 本番環境（Nginx経由）
        static let productionURL = "https://api.hey-watch.me/avatar"
        
        // 開発環境（EC2直接アクセス）
        static let developmentURL = "http://3.24.16.82:8014"
        
        // 現在の環境
        static var currentURL: String {
            #if DEBUG
            // 開発時はEC2に直接アクセス
            // TODO: Nginx設定が完了したら本番URLに切り替え
            return developmentURL
            #else
            // リリースビルドでは本番URL
            return productionURL
            #endif
        }
        
        // APIの注意事項
        static let notes = """
        Avatar Uploader API仕様:
        
        1. UUID形式のIDが必須
           - user_idおよびsubject_idはUUID形式である必要があります
           - 例: "71958203-e43a-4510-bdfd-a9459388e830"
        
        2. エンドポイント形式
           - POST /v1/users/{user_id}/avatar
           - POST /v1/subjects/{subject_id}/avatar
        
        3. リクエスト形式
           - Content-Type: multipart/form-data
           - パラメータ:
             - file: 画像ファイル（必須）
             - avatar_type: "main" または "sub"（必須）
        
        4. レスポンス形式
           - 成功時: { "avatarUrl": "https://..." }
           - エラー時: HTTPステータスコードとエラーメッセージ
        
        5. S3バケット情報
           - バケット名: watchme-vault
           - リージョン: ap-southeast-2
        """
    }
    
    // MARK: - Environment
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Logging
    static func log(_ message: String) {
        if isDebug {
            print("🔧 [\(Date())] \(message)")
        }
    }
}

// MARK: - API Endpoint Helper
extension APIConfiguration.AvatarUploader {
    /// ユーザーアバターのアップロードURL
    static func userAvatarURL(userId: String) -> URL? {
        return URL(string: "\(currentURL)/v1/users/\(userId)/avatar")
    }
    
    /// サブジェクトアバターのアップロードURL
    static func subjectAvatarURL(subjectId: String) -> URL? {
        return URL(string: "\(currentURL)/v1/subjects/\(subjectId)/avatar")
    }
}