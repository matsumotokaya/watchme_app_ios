//
//  SupabaseAuthManager.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/07/04.
//

import SwiftUI
import Foundation
import Supabase

// Supabaseクライアントをグローバルに定義
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://qvtlwotzuzbavrzqhyvt.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2dGx3b3R6dXpiYXZyenFoeXZ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEzODAzMzAsImV4cCI6MjA2Njk1NjMzMH0.g5rqrbxHPw1dKlaGqJ8miIl9gCXyamPajinGCauEI3k"
)

// Supabase認証管理クラス
class SupabaseAuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: SupabaseUser? = nil
    @Published var authError: String? = nil
    @Published var isLoading: Bool = false
    @Published var isCheckingAuthStatus: Bool = true  // 認証状態確認中フラグ
    
    // DeviceManagerへの参照
    private let deviceManager: DeviceManager
    
    // Supabase設定
    private let supabaseURL = "https://qvtlwotzuzbavrzqhyvt.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2dGx3b3R6dXpiYXZyenFoeXZ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEzODAzMzAsImV4cCI6MjA2Njk1NjMzMH0.g5rqrbxHPw1dKlaGqJ8miIl9gCXyamPajinGCauEI3k"
    
    init(deviceManager: DeviceManager) {
        self.deviceManager = deviceManager
        // 保存された認証状態を確認
        checkAuthStatus()
    }
    
    // MARK: - 認証状態確認
    private func checkAuthStatus() {
        if let savedUser = loadUserFromDefaults() {
            // 保存されたトークンでセッションを復元
            Task { @MainActor in
                do {
                    // リフレッシュトークンがある場合のみセッションを復元
                    if let refreshToken = savedUser.refreshToken {
                        // アクセストークンとリフレッシュトークンを使ってセッションを設定
                        _ = try await supabase.auth.setSession(
                            accessToken: savedUser.accessToken,
                            refreshToken: refreshToken
                        )
                    } else {
                        // リフレッシュトークンがない場合は再ログインが必要
                        throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "リフレッシュトークンがありません"])
                    }
                    
                    self.currentUser = savedUser
                    self.isAuthenticated = true
                    print("✅ 保存された認証状態を復元: \(savedUser.email)")
                    print("🔄 認証状態復元: isAuthenticated = true")
                    print("🔑 セッショントークンも復元しました")
                    
                    self.isCheckingAuthStatus = false  // 認証確認完了
                    
                    // プロファイルを取得
                    fetchUserProfile(userId: savedUser.id)
                    
                    // デバイス情報を取得（登録はせず、既存のデバイス一覧のみ取得）
                    await deviceManager.fetchUserDevices(for: savedUser.id)
                    
                } catch {
                    print("❌ セッション復元エラー: \(error)")
                    print("⚠️ 再ログインが必要です")
                    // セッション復元に失敗した場合はクリア
                    clearLocalAuthData()
                    self.isCheckingAuthStatus = false  // 認証確認完了
                }
            }
        } else {
            print("⚠️ 保存された認証状態なし: isAuthenticated = false")
            self.isCheckingAuthStatus = false  // 認証確認完了
        }
    }
    
    // MARK: - ログイン機能
    func signIn(email: String, password: String) {
        isLoading = true
        authError = nil
        
        print("🔐 ログイン試行: \(email)")
        
        Task { @MainActor in
            do {
                // Supabaseクライアントの組み込みメソッドを使用
                let session = try await supabase.auth.signIn(
                    email: email,
                    password: password
                )
                
                print("✅ ログイン成功: \(email)")
                print("📡 認証レスポンス取得完了")
                
                // 認証情報を保存
                let user = SupabaseUser(
                    id: session.user.id.uuidString,
                    email: session.user.email ?? email,
                    accessToken: session.accessToken,
                    refreshToken: session.refreshToken
                )
                
                self.currentUser = user
                self.isAuthenticated = true
                self.saveUserToDefaults(user)
                
                print("🔄 認証状態を更新: isAuthenticated = true")
                
                // ユーザープロファイルを取得
                self.fetchUserProfile(userId: user.id)
                
                // ユーザーのデバイス一覧を取得（新規登録はしない）
                await self.deviceManager.fetchUserDevices(for: user.id)
                
                self.isLoading = false
                
            } catch {
                self.isLoading = false
                
                // エラーハンドリング
                self.authError = "ログインに失敗しました: \(error.localizedDescription)"
                
                print("❌ ログインエラー: \(error)")
            }
        }
    }
    
    // MARK: - サインアップ機能
    func signUp(email: String, password: String) {
        isLoading = true
        authError = nil
        
        print("📝 サインアップ試行: \(email)")
        
        Task { @MainActor in
            do {
                // Supabase SDKの標準メソッドを使用
                let authResponse = try await supabase.auth.signUp(
                    email: email,
                    password: password
                )
                
                print("✅ サインアップ成功")
                print("📧 メール確認状態: \(authResponse.user.confirmedAt != nil ? "確認済み" : "未確認")")
                
                // サインアップ成功後の処理
                if authResponse.user.confirmedAt != nil {
                    // メール確認済みの場合は自動的にログイン
                    print("📧 メール確認済み - 自動ログイン実行")
                    self.signIn(email: email, password: password)
                } else {
                    // メール確認が必要な場合
                    self.authError = "サインアップ成功！確認メールをご確認ください。"
                    print("📧 確認メールを送信しました")
                }
                
                self.isLoading = false
                
            } catch {
                self.isLoading = false
                
                // エラーハンドリング
                self.authError = "サインアップに失敗しました: \(error.localizedDescription)"
                
                print("❌ サインアップエラー: \(error)")
            }
        }
    }
    
    // MARK: - ユーザー情報取得（確認状態チェック用）
    func fetchUserInfo() {
        isLoading = true
        
        Task { @MainActor in
            do {
                // Supabase SDKの標準メソッドを使用して現在のユーザー情報を取得
                let user = try await supabase.auth.session.user
                
                print("📡 ユーザー情報取得成功")
                print("📧 メール: \(user.email ?? "なし")")
                print("📧 メール確認状態: \(user.confirmedAt != nil ? "確認済み" : "未確認")")
                
                if user.confirmedAt == nil {
                    self.authError = "メール確認が完了していません"
                }
                
                self.isLoading = false
                
            } catch {
                print("❌ ユーザー情報取得エラー: \(error)")
                self.isLoading = false
                
                // セッションエラーの場合は再ログインを促す
                if case AuthError.sessionMissing = error {
                    self.authError = "セッションの有効期限が切れました。再度ログインしてください。"
                    self.clearLocalAuthData()
                }
            }
        }
    }
    
    // MARK: - ログアウト機能
    func signOut() {
        print("🚪 ログアウト開始")
        
        // 即座にローカル状態をクリア（UIの即時更新のため）
        self.clearLocalAuthData()
        
        // その後、バックグラウンドでサーバー側のログアウトを実行
        Task {
            do {
                // Supabase SDKの標準メソッドを使用
                try await supabase.auth.signOut()
                print("✅ サーバー側ログアウト成功")
            } catch {
                print("❌ サーバー側ログアウトエラー: \(error)")
                // エラーが発生してもローカルは既にクリア済み
            }
        }
    }
    
    // クライアント側認証データクリア
    private func clearLocalAuthData() {
        print("🧹 ローカル認証データクリア開始")
        currentUser = nil
        isAuthenticated = false
        authError = nil
        
        // 保存された認証情報を削除
        UserDefaults.standard.removeObject(forKey: "supabase_user")
        
        print("👋 ログアウト完了: isAuthenticated = false")
    }
    
    // MARK: - ユーザープロファイル取得
    func fetchUserProfile(userId: String) {
        print("👤 ユーザープロファイル取得開始: \(userId)")
        
        Task { @MainActor in
            do {
                // Supabase SDKの標準メソッドを使用
                let profiles: [UserProfile] = try await supabase
                    .from("users")
                    .select()
                    .eq("user_id", value: userId)
                    .limit(1)
                    .execute()
                    .value
                
                if let profile = profiles.first {
                    // currentUserにプロファイルを設定
                    if var updatedUser = self.currentUser {
                        updatedUser.profile = profile
                        self.currentUser = updatedUser
                        self.saveUserToDefaults(updatedUser)
                    }
                    
                    print("✅ プロファイル取得成功")
                    print("   - 名前: \(profile.name ?? "未設定")")
                    print("   - ステータス: \(profile.status ?? "未設定")")
                    print("   - ニュースレター: \(String(describing: profile.newsletter))")
                } else {
                    print("⚠️ プロファイルが見つかりません")
                }
                
            } catch {
                print("❌ プロファイル取得エラー: \(error)")
                // データベースエラーの詳細を表示
                if let dbError = error as? PostgrestError {
                    print("   - コード: \(dbError.code ?? "不明")")
                    print("   - メッセージ: \(dbError.message)")
                }
            }
        }
    }
    
    // MARK: - 確認メール再送機能
    func resendConfirmationEmail(email: String) {
        isLoading = true
        authError = nil
        
        print("📧 確認メール再送: \(email)")
        
        Task { @MainActor in
            do {
                // Supabase SDKの標準メソッドを使用
                try await supabase.auth.resend(
                    email: email,
                    type: .signup
                )
                
                self.authError = "確認メールを再送しました。メールボックスをご確認ください。"
                print("✅ 確認メール再送成功")
                
                self.isLoading = false
                
            } catch {
                self.isLoading = false
                self.authError = "確認メール再送に失敗しました: \(error.localizedDescription)"
                print("❌ 確認メール再送エラー: \(error)")
            }
        }
    }
    
    // MARK: - UserDefaults保存・読み込み
    private func saveUserToDefaults(_ user: SupabaseUser) {
        do {
            let data = try JSONEncoder().encode(user)
            UserDefaults.standard.set(data, forKey: "supabase_user")
            print("💾 ユーザー情報を保存")
        } catch {
            print("❌ ユーザー情報保存エラー: \(error)")
        }
    }
    
    private func loadUserFromDefaults() -> SupabaseUser? {
        guard let data = UserDefaults.standard.data(forKey: "supabase_user") else {
            return nil
        }
        
        do {
            let user = try JSONDecoder().decode(SupabaseUser.self, from: data)
            return user
        } catch {
            print("❌ ユーザー情報読み込みエラー: \(error)")
            return nil
        }
    }
    
    // MARK: - ユーザープロファイル更新
    func updateUserProfile(newsletterSubscription: Bool? = nil) {
        guard let currentUser = currentUser else {
            print("❌ ログインしていません")
            return
        }
        
        print("📝 ユーザープロファイル更新開始: \(currentUser.id)")
        
        Task { @MainActor in
            do {
                struct ProfileUpdate: Codable {
                    let newsletter_subscription: Bool?
                    let updated_at: String
                }
                
                let now = ISO8601DateFormatter().string(from: Date())
                let profileUpdate = ProfileUpdate(
                    newsletter_subscription: newsletterSubscription,
                    updated_at: now
                )
                
                // Supabase SDKの標準メソッドを使用
                try await supabase
                    .from("users")
                    .update(profileUpdate)
                    .eq("user_id", value: currentUser.id)
                    .execute()
                
                print("✅ プロファイル更新成功")
                
                // 更新後のプロファイルを再取得
                self.fetchUserProfile(userId: currentUser.id)
                
            } catch {
                print("❌ プロファイル更新エラー: \(error)")
                self.authError = "プロファイルの更新に失敗しました: \(error.localizedDescription)"
                
                // PostgrestErrorの詳細を表示
                if let dbError = error as? PostgrestError {
                    print("   - コード: \(dbError.code ?? "不明")")
                    print("   - メッセージ: \(dbError.message)")
                }
            }
        }
    }
}

// MARK: - データモデル

struct SupabaseUser: Codable {
    let id: String
    let email: String
    let accessToken: String
    let refreshToken: String?
    var profile: UserProfile?
}

struct UserProfile: Codable {
    let userId: String
    let name: String?
    let email: String?
    let avatarUrl: String?
    let status: String?
    let subscriptionPlan: String?
    let createdAt: String?
    let updatedAt: String?
    let newsletter: Bool?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case email
        case avatarUrl = "avatar_url"
        case status
        case subscriptionPlan = "subscription_plan"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case newsletter = "newsletter_subscription"  // DBカラム名に合わせて修正
    }
}

struct SupabaseAuthResponse: Codable {
    let access_token: String
    let refresh_token: String?
    let user: SupabaseAuthUser
}

struct SupabaseAuthUser: Codable {
    let id: String
    let email: String
}

struct SupabaseErrorResponse: Codable {
    let error: String?
    let error_description: String?
}