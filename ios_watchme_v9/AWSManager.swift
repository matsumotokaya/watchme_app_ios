//
//  AWSManager.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/31.
//

import Foundation
import UIKit
import CryptoKit

// MARK: - Avatar Upload Manager
/// アバター画像のアップロードを管理するクラス
/// 
/// ✅ Avatar Uploader APIを使用した実装
/// - エンドポイント: https://api.hey-watch.me/avatar/
/// - S3への直接アップロードではなく、サーバー経由での安全なアップロード
///
@MainActor
class AWSManager: ObservableObject {
    
    // MARK: - Properties
    static let shared = AWSManager()
    
    // 現在使用するAPIベースURL
    private var currentAPIBaseURL: String {
        return APIConfiguration.AvatarUploader.currentURL
    }
    
    // MARK: - Initialization
    private init() {
        // 初期化処理（必要に応じて）
    }
    
    // MARK: - Public Methods
    
    /// アバター画像をアップロード
    /// - Parameters:
    ///   - image: アップロードする画像
    ///   - type: アバターのタイプ（"users" または "subjects"）
    ///   - id: ユーザーIDまたはサブジェクトID（UUID形式必須）
    /// - Returns: アップロードされた画像のURL
    func uploadAvatar(image: UIImage, type: String, id: String) async throws -> URL {
        print("📤 Starting avatar upload for \(type)/\(id)")
        
        // UUIDの形式チェック
        guard UUID(uuidString: id) != nil else {
            throw AWSError.invalidID("IDはUUID形式である必要があります: \(id)")
        }
        
        // 画像をJPEGに変換（品質80%）
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw AWSError.imageConversionFailed
        }
        
        // APIエンドポイントURL
        let endpoint = "\(currentAPIBaseURL)/v1/\(type)/\(id)/avatar"
        guard let url = URL(string: endpoint) else {
            throw AWSError.invalidURL
        }
        
        // multipart/form-dataのboundary
        let boundary = UUID().uuidString
        
        // リクエスト作成
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // 認証トークンがある場合は追加（Supabaseトークンなど）
        // TODO: AuthManagerからトークンを取得して設定
        // if let token = await AuthManager.shared.getAccessToken() {
        //     request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // }
        
        // multipart/form-dataのボディを構築
        var body = Data()
        
        // avatar_typeパラメータ（"main"または"sub"）
        let avatarType = "main"  // デフォルトは"main"
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"avatar_type\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(avatarType)\r\n".data(using: .utf8)!)
        
        // 画像ファイル
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // 終端
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // リクエスト実行
        do {
            let (data, response) = try await URLSession.shared.upload(for: request, from: body)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AWSError.invalidResponse
            }
            
            print("📡 Response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                // レスポンスJSONをパース
                struct AvatarUploadResponse: Codable {
                    let avatarUrl: String
                }
                
                let decoder = JSONDecoder()
                let result = try decoder.decode(AvatarUploadResponse.self, from: data)
                
                guard let avatarURL = URL(string: result.avatarUrl) else {
                    throw AWSError.invalidURL
                }
                
                print("✅ Avatar uploaded successfully: \(avatarURL)")
                return avatarURL
                
            } else if httpResponse.statusCode == 422 {
                // バリデーションエラー
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ Validation error: \(errorString)")
                    throw AWSError.validationError(errorString)
                }
                throw AWSError.uploadFailed(statusCode: httpResponse.statusCode)
            } else {
                // その他のエラー
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ Upload error: \(errorString)")
                }
                throw AWSError.uploadFailed(statusCode: httpResponse.statusCode)
            }
        } catch {
            print("❌ Network error: \(error)")
            throw AWSError.networkError(error)
        }
    }
    
    /// アバター画像のURLを取得
    /// - Parameters:
    ///   - type: アバターのタイプ（"users" または "subjects"）
    ///   - id: ユーザーIDまたはサブジェクトID
    /// - Returns: アバター画像のURL
    func getAvatarURL(type: String, id: String) -> URL {
        // S3の実際のURL形式
        // 注意: us-east-1形式のURLが返される（APIレスポンスと同じ形式）
        // 実際はap-southeast-2にリダイレクトされる
        let s3URL = "https://watchme-vault.s3.us-east-1.amazonaws.com/\(type)/\(id)/avatar.jpg"
        print("🔗 Avatar URL: \(s3URL)")
        return URL(string: s3URL)!
    }
    
}

// MARK: - Error Types
enum AWSError: Error, LocalizedError {
    case imageConversionFailed
    case invalidResponse
    case invalidURL
    case invalidID(String)
    case uploadFailed(statusCode: Int)
    case validationError(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "画像の変換に失敗しました"
        case .invalidResponse:
            return "無効なレスポンスです"
        case .invalidURL:
            return "無効なURLです"
        case .invalidID(let message):
            return message
        case .uploadFailed(let statusCode):
            return "アップロードに失敗しました (ステータス: \(statusCode))"
        case .validationError(let message):
            return "検証エラー: \(message)"
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        }
    }
}

// MARK: - Avatar Uploader API実装の注意事項
/*
 ✅ このAWSManagerは、Avatar Uploader APIを使用した実装です。
 
 実装の特徴：
 
 1. サーバー経由の安全なアップロード
    - AWSの認証情報はクライアントに保持しない
    - サーバー側でS3へのアップロードを処理
 
 2. UUID形式のID必須
    - user_idおよびsubject_idはUUID形式である必要がある
    - 形式チェックを実装済み
 
 3. multipart/form-dataでのアップロード
    - fileとavatar_typeをパラメータとして送信
    - 画像はJPEG形式（品質80%）に変換
 
 4. 開発/本番環境の切り替え
    - currentAPIBaseURLプロパティで管理
    - 本番Nginx設定完了後は切り替えが必要
 
 今後の改善点：
 - Supabase認証トークンの追加
 - リトライロジックの実装
 - 画像のリサイズ・最適化処理
 - アバタータイプ（main/sub）の選択機能
 */