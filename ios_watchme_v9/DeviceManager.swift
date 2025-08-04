//
//  DeviceManager.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/07/04.
//

import SwiftUI
import Foundation
import UIKit
import Supabase

// デバイス登録管理クラス
class DeviceManager: ObservableObject {
    @Published var isDeviceRegistered: Bool = false
    @Published var localDeviceIdentifier: String? = nil  // この物理デバイス自身のID
    @Published var userDevices: [Device] = []  // ユーザーの全デバイス
    @Published var selectedDeviceID: String? = nil  // 選択中のデバイスID
    @Published var registrationError: String? = nil
    @Published var isLoading: Bool = false
    
    // Supabase設定（URLとキーは参照用に残しておく）
    private let supabaseURL = "https://qvtlwotzuzbavrzqhyvt.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2dGx3b3R6dXpiYXZyenFoeXZ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEzODAzMzAsImV4cCI6MjA2Njk1NjMzMH0.g5rqrbxHPw1dKlaGqJ8miIl9gCXyamPajinGCauEI3k"
    
    // UserDefaults キー
    private let localDeviceIdentifierKey = "watchme_device_id"  // UserDefaultsのキーは互換性のため維持
    private let isRegisteredKey = "watchme_device_registered"
    private let platformIdentifierKey = "watchme_platform_identifier"
    private let selectedDeviceIDKey = "watchme_selected_device_id"  // 選択中のデバイスID永続化用
    
    init() {
        checkDeviceRegistrationStatus()
        restoreSelectedDevice()
    }
    
    // MARK: - デバイス登録状態確認
    private func checkDeviceRegistrationStatus() {
        let savedDeviceID = UserDefaults.standard.string(forKey: localDeviceIdentifierKey)
        let isSupabaseRegistered = UserDefaults.standard.bool(forKey: "watchme_supabase_registered")
        
        if let deviceID = savedDeviceID, isSupabaseRegistered {
            self.localDeviceIdentifier = deviceID
            self.isDeviceRegistered = true
            print("📱 Supabaseデバイス登録確認: \(deviceID)")
        } else {
            self.isDeviceRegistered = false
            print("📱 デバイス未登録 - Supabase登録が必要")
            
            // 古いローカル登録データがあれば削除
            if UserDefaults.standard.string(forKey: localDeviceIdentifierKey) != nil {
                print("🗑️ 古いローカル登録データを削除")
                UserDefaults.standard.removeObject(forKey: localDeviceIdentifierKey)
                UserDefaults.standard.removeObject(forKey: isRegisteredKey)
                UserDefaults.standard.removeObject(forKey: platformIdentifierKey)
            }
        }
    }
    
    
    // MARK: - プラットフォーム識別子取得
    private func getPlatformIdentifier() -> String? {
        return UIDevice.current.identifierForVendor?.uuidString
    }
    
    // MARK: - デバイス登録処理（ユーザーが明示的に登録する場合のみ使用）
    func registerDevice(userId: String) {
        guard let platformIdentifier = getPlatformIdentifier() else {
            registrationError = "デバイス識別子の取得に失敗しました"
            print("❌ identifierForVendor取得失敗")
            return
        }
        
        isLoading = true
        registrationError = nil
        
        print("📱 Supabaseデバイス登録開始（ユーザーの明示的な操作による）")
        print("   - Platform Identifier: \(platformIdentifier)")
        print("   - User ID: \(userId)")
        
        // Supabase直接Insert実装
        registerDeviceToSupabase(platformIdentifier: platformIdentifier, userId: userId)
    }
    
    // MARK: - Supabase UPSERT登録（改善版）
    private func registerDeviceToSupabase(platformIdentifier: String, userId: String) {
        Task { @MainActor in
            do {
                // --- ステップ1: devicesテーブルにデバイスを登録 ---
                // iOSのIANAタイムゾーン識別子を取得
                let timezone = TimeZone.current.identifier // 例: "Asia/Tokyo"
                print("🌍 デバイスタイムゾーン: \(timezone)")
                
                let deviceData = DeviceInsert(
                    platform_identifier: platformIdentifier,
                    device_type: "ios",
                    platform_type: "iOS",
                    timezone: timezone
                )
                
                // UPSERT: INSERT ON CONFLICT DO UPDATE を使用
                let response: [Device] = try await supabase
                    .from("devices")
                    .upsert(deviceData)
                    .select()
                    .execute()
                    .value
                
                guard let device = response.first else {
                    throw DeviceRegistrationError.noDeviceReturned
                }
                
                let newDeviceId = device.device_id
                print("✅ Step 1: Device registered/fetched: \(newDeviceId)")
                
                // --- ステップ2: user_devicesテーブルに所有関係を登録 ---
                let userDeviceRelation = UserDeviceInsert(
                    user_id: userId,
                    device_id: newDeviceId,
                    role: "owner"
                )
                
                // 競合した場合は何もしない (ON CONFLICT DO NOTHING相当)
                do {
                    try await supabase
                        .from("user_devices")
                        .insert(userDeviceRelation, returning: .minimal)
                        .execute()
                    
                    print("✅ Step 2: User-Device ownership registered for user: \(userId)")
                } catch {
                    // エラーの詳細を確認
                    print("❌ User-Device relation insert failed: \(error)")
                    
                    if let postgrestError = error as? PostgrestError {
                        print("   - Code: \(postgrestError.code ?? "unknown")")
                        print("   - Message: \(postgrestError.message)")
                        print("   - Detail: \(postgrestError.detail ?? "none")")
                        print("   - Hint: \(postgrestError.hint ?? "none")")
                        
                        // RLSエラーの場合の対処法を提案
                        if postgrestError.code == "42501" {
                            print("   ⚠️ RLS Policy Error: user_devicesテーブルのRLSポリシーを確認してください")
                            print("   💡 解決方法: Supabaseダッシュボードで以下のSQLを実行してください:")
                            print("      CREATE POLICY \"Users can insert their own device associations\"")
                            print("      ON user_devices FOR INSERT")
                            print("      WITH CHECK (auth.uid() = user_id);")
                        }
                    }
                }
                
                // 最後にローカルのデバイス情報を保存
                self.saveSupabaseDeviceRegistration(
                    deviceID: newDeviceId,
                    platformIdentifier: platformIdentifier
                )
                self.isLoading = false
                self.registrationError = nil  // エラーをクリア
                
                // 登録成功後、ユーザーのデバイス一覧を再取得
                await self.fetchUserDevices(for: userId)
                
            } catch {
                print("❌ デバイス登録処理全体でエラー: \(error)")
                self.registrationError = "デバイス登録に失敗しました: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    // MARK: - ユーザーIDを指定したSupabase登録（内部用）
    private func registerDeviceToSupabase(userId: String) async {
        guard let platformIdentifier = getPlatformIdentifier() else {
            print("❌ デバイス識別子の取得に失敗しました")
            return
        }
        
        do {
            // --- ステップ1: devicesテーブルにデバイスを登録 ---
            // iOSのIANAタイムゾーン識別子を取得
            let timezone = TimeZone.current.identifier // 例: "Asia/Tokyo"
            print("🌍 デバイスタイムゾーン: \(timezone)")
            
            let deviceData = DeviceInsert(
                platform_identifier: platformIdentifier,
                device_type: "ios",
                platform_type: "iOS",
                timezone: timezone
            )
            
            // UPSERT: INSERT ON CONFLICT DO UPDATE を使用
            let response: [Device] = try await supabase
                .from("devices")
                .upsert(deviceData)
                .select()
                .execute()
                .value
            
            guard let device = response.first else {
                throw DeviceRegistrationError.noDeviceReturned
            }
            
            let newDeviceId = device.device_id
            print("✅ Step 1: Device registered/fetched: \(newDeviceId)")
            
            // --- ステップ2: user_devicesテーブルに所有関係を登録 ---
            
            // 現在の認証セッションを確認
            let currentSession = try? await supabase.auth.session
            let currentAuthUserId = currentSession?.user.id.uuidString
            
            print("🔐 認証セッション確認:")
            print("   - 渡されたuserId: \(userId)")
            print("   - auth.session.user.id: \(currentAuthUserId ?? "nil")")
            print("   - 一致: \(userId == currentAuthUserId ? "✅" : "❌")")
            
            let userDeviceRelation = UserDeviceInsert(
                user_id: userId,
                device_id: newDeviceId,
                role: "owner"
            )
            
            // 競合した場合は何もしない (ON CONFLICT DO NOTHING相当)
            do {
                try await supabase
                    .from("user_devices")
                    .insert(userDeviceRelation, returning: .minimal)
                    .execute()
                
                print("✅ Step 2: User-Device ownership registered for user: \(userId)")
            } catch {
                // エラーの詳細を確認
                print("❌ User-Device relation insert failed: \(error)")
                
                if let postgrestError = error as? PostgrestError {
                    print("   - Code: \(postgrestError.code ?? "unknown")")
                    print("   - Message: \(postgrestError.message)")
                    print("   - Detail: \(postgrestError.detail ?? "none")")
                    print("   - Hint: \(postgrestError.hint ?? "none")")
                    
                    // RLSエラーの場合の対処法を提案
                    if postgrestError.code == "42501" {
                        print("   ⚠️ RLS Policy Error: user_devicesテーブルのRLSポリシーを確認してください")
                        print("   💡 解決方法: Supabaseダッシュボードで以下のSQLを実行してください:")
                        print("      CREATE POLICY \"Users can insert their own device associations\"")
                        print("      ON user_devices FOR INSERT")
                        print("      WITH CHECK (auth.uid() = user_id);")
                    }
                }
            }
            
            // 最後にローカルのデバイス情報を保存
            await MainActor.run {
                self.saveSupabaseDeviceRegistration(
                    deviceID: newDeviceId,
                    platformIdentifier: platformIdentifier
                )
            }
            
        } catch {
            print("❌ デバイス登録処理全体でエラー: \(error)")
        }
    }
    
    // MARK: - Supabaseデバイス登録情報保存
    private func saveSupabaseDeviceRegistration(deviceID: String, platformIdentifier: String) {
        UserDefaults.standard.set(deviceID, forKey: localDeviceIdentifierKey)
        UserDefaults.standard.set(platformIdentifier, forKey: platformIdentifierKey)
        UserDefaults.standard.set(true, forKey: "watchme_supabase_registered")
        
        self.localDeviceIdentifier = deviceID
        self.isDeviceRegistered = true
        
        print("💾 Supabaseデバイス登録完了")
        print("   - Device ID: \(deviceID)")
        print("   - Platform Identifier: \(platformIdentifier)")
    }
    
    // MARK: - デバイス登録状態リセット（デバッグ用）
    func resetDeviceRegistration() {
        UserDefaults.standard.removeObject(forKey: localDeviceIdentifierKey)
        UserDefaults.standard.removeObject(forKey: platformIdentifierKey)
        UserDefaults.standard.removeObject(forKey: "watchme_supabase_registered")
        
        self.localDeviceIdentifier = nil
        self.isDeviceRegistered = false
        self.registrationError = nil
        
        print("🔄 デバイス登録状態リセット完了")
    }
    
    // MARK: - ユーザーのデバイスを取得
    func fetchUserDevices(for userId: String) async {
        // ローディング状態を設定
        await MainActor.run {
            self.isLoading = true
        }
        
        // Supabaseクライアントを使用してuser_devicesを取得
        do {
            print("📡 Fetching user devices for userId: \(userId)")
            
            // デバッグ: 現在の認証状態を確認
            if let currentUser = try? await supabase.auth.session.user {
                print("✅ 認証済みユーザー: \(currentUser.id)")
            } else {
                print("❌ 認証されていません - supabase.auth.session.userがnil")
            }
            
            // Step 1: user_devicesテーブルからデータを取得
            let userDevices: [UserDevice] = try await supabase
                .from("user_devices")
                .select("*")
                .eq("user_id", value: userId)
                .execute()
                .value
            
            print("📊 Decoded user_devices count: \(userDevices.count)")
            for userDevice in userDevices {
                print("   - Device: \(userDevice.device_id), Role: \(userDevice.role)")
            }
            
            if userDevices.isEmpty {
                print("⚠️ No devices found for user: \(userId)")
                await MainActor.run {
                    self.userDevices = []
                    self.isLoading = false  // ローディング状態を解除
                    // ユーザーに紐付くデバイスがない場合、このデバイス自身のIDを使用
                    if let localId = self.localDeviceIdentifier {
                        self.selectedDeviceID = localId
                        print("⚠️ Using local device: \(localId)")
                    }
                }
                return
            }
            
            print("📄 Found \(userDevices.count) user-device relationships")
            
            // Step 2: device_idのリストを作成してdevicesテーブルから詳細を取得
            let deviceIds = userDevices.map { $0.device_id }
            
            // Step 3: devicesテーブルから詳細情報を取得
            var devices: [Device] = try await supabase
                .from("devices")
                .select("*")
                .in("device_id", values: deviceIds)
                .execute()
                .value
            
            print("📊 Fetched \(devices.count) device details")
            
            // Step 4: roleの情報をデバイスに付与
            for i in devices.indices {
                if let userDevice = userDevices.first(where: { $0.device_id == devices[i].device_id }) {
                    devices[i].role = userDevice.role
                }
            }
            
            await MainActor.run { [devices] in
                self.userDevices = devices
                print("✅ Found \(devices.count) devices for user: \(userId)")
                
                // ownerロールのデバイスを優先的に選択
                let ownerDevices = devices.filter { $0.role == "owner" }
                let viewerDevices = devices.filter { $0.role == "viewer" }
                
                // 保存された選択デバイスがある場合はそれを優先
                if let savedDeviceId = UserDefaults.standard.string(forKey: self.selectedDeviceIDKey),
                   devices.contains(where: { $0.device_id == savedDeviceId }) {
                    self.selectedDeviceID = savedDeviceId
                    print("🔍 Restored previously selected device: \(savedDeviceId)")
                } else if let firstOwnerDevice = ownerDevices.first {
                    self.selectedDeviceID = firstOwnerDevice.device_id
                    print("🔍 Auto-selected owner device: \(firstOwnerDevice.device_id)")
                } else if let firstViewerDevice = viewerDevices.first {
                    self.selectedDeviceID = firstViewerDevice.device_id
                    print("🔍 Auto-selected viewer device: \(firstViewerDevice.device_id)")
                } else if let firstDevice = devices.first {
                    self.selectedDeviceID = firstDevice.device_id
                    print("🔍 Selected first device: \(firstDevice.device_id)")
                }
            }
            
        } catch {
            print("❌ Device fetch error: \(error)")
        }
        
        // ローディング状態を解除
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    // MARK: - デバイス選択
    func selectDevice(_ deviceId: String) {
        if userDevices.contains(where: { $0.device_id == deviceId }) {
            selectedDeviceID = deviceId
            // 選択したデバイスIDを永続化
            UserDefaults.standard.set(deviceId, forKey: selectedDeviceIDKey)
            print("📱 Selected device saved: \(deviceId)")
        }
    }
    
    // MARK: - 選択中デバイスの復元
    private func restoreSelectedDevice() {
        if let savedDeviceId = UserDefaults.standard.string(forKey: selectedDeviceIDKey) {
            selectedDeviceID = savedDeviceId
            print("📱 Restored selected device: \(savedDeviceId)")
        }
    }
    
    // MARK: - デバイス情報取得
    func getDeviceInfo() -> DeviceInfo? {
        // 選択されたデバイスIDがあればそれを使用、なければこの物理デバイスのIDを使用
        let deviceID = selectedDeviceID ?? localDeviceIdentifier
        
        guard let deviceID = deviceID,
              let platformIdentifier = UserDefaults.standard.string(forKey: platformIdentifierKey) else {
            return nil
        }
        
        return DeviceInfo(
            deviceID: deviceID,
            platformIdentifier: platformIdentifier,
            deviceType: "ios",
            platformType: "iOS"
        )
    }
    
    // MARK: - タイムゾーン関連
    /// 選択中のデバイスのタイムゾーンを取得
    var selectedDeviceTimezone: TimeZone {
        // 選択されたデバイスIDがあればそのタイムゾーンを返す
        if let deviceId = selectedDeviceID,
           let device = userDevices.first(where: { $0.device_id == deviceId }),
           let timezoneString = device.timezone,
           let timezone = TimeZone(identifier: timezoneString) {
            return timezone
        }
        
        // フォールバック：現在のデバイスのタイムゾーン
        return TimeZone.current
    }
    
    /// デバイスのタイムゾーンを考慮したCalendarを取得
    var deviceCalendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = selectedDeviceTimezone
        return calendar
    }
    
    /// 指定したデバイスIDのタイムゾーンを取得
    func getTimezone(for deviceId: String) -> TimeZone {
        if let device = userDevices.first(where: { $0.device_id == deviceId }),
           let timezoneString = device.timezone,
           let timezone = TimeZone(identifier: timezoneString) {
            return timezone
        }
        return TimeZone.current
    }
    
    // MARK: - QRコードによるデバイス追加
    // TODO: 将来的にQRコードにはデバイスIDとタイムゾーンの両方を含める必要があります
    // 現在はデバイスIDのみですが、後日以下の対応が必要です：
    // 1. QRコード生成時にタイムゾーン情報も含める
    // 2. スキャン時にデバイスIDとタイムゾーンの両方を取得
    // 3. デバイス追加時にタイムゾーンもDBに保存
    func addDeviceByQRCode(_ deviceId: String, for userId: String) async throws {
        // UUIDの妥当性チェック
        guard UUID(uuidString: deviceId) != nil else {
            throw DeviceAddError.invalidDeviceId
        }
        
        // 既に追加済みかチェック
        if userDevices.contains(where: { $0.device_id == deviceId }) {
            throw DeviceAddError.alreadyAdded
        }
        
        // まずdevicesテーブルにデバイスが存在するか確認
        do {
            let existingDevices: [Device] = try await supabase
                .from("devices")
                .select("*")
                .eq("device_id", value: deviceId)
                .execute()
                .value
            
            if existingDevices.isEmpty {
                throw DeviceAddError.deviceNotFound
            }
            
            // user_devicesテーブルに追加（ownerロールで）
            let userDevice = UserDeviceInsert(
                user_id: userId,
                device_id: deviceId,
                role: "owner"  // デフォルトでownerロールに変更
            )
            
            try await supabase
                .from("user_devices")
                .insert(userDevice)
                .execute()
            
            print("✅ Device added via QR code: \(deviceId)")
            
            // デバイス一覧を再取得
            await fetchUserDevices(for: userId)
            
        } catch {
            print("❌ Failed to add device via QR code: \(error)")
            throw error
        }
    }
    
}

// MARK: - データモデル

// デバイス情報
struct DeviceInfo {
    let deviceID: String
    let platformIdentifier: String
    let deviceType: String
    let platformType: String
}

// Supabase Insert用データモデル
struct DeviceInsert: Codable {
    let platform_identifier: String
    let device_type: String
    let platform_type: String
    let timezone: String // IANAタイムゾーン識別子（例: "Asia/Tokyo"）
}

// Supabase Response用データモデル
struct Device: Codable {
    let device_id: String
    let platform_identifier: String
    let device_type: String
    let platform_type: String
    let timezone: String? // IANAタイムゾーン識別子（例: "Asia/Tokyo"）
    let owner_user_id: String?
    let subject_id: String?
    // user_devicesテーブルから取得した場合のrole情報を保持
    var role: String?
}

// user_devicesテーブル用のモデル
struct UserDevice: Codable {
    let user_id: String
    let device_id: String
    let role: String
    let created_at: String?
}

// user_devicesテーブルへのInsert用モデル
struct UserDeviceInsert: Codable {
    let user_id: String
    let device_id: String
    let role: String
}

// エラータイプ
enum DeviceRegistrationError: Error {
    case noDeviceReturned
    case supabaseNotAvailable
    case registrationFailed
    
    var localizedDescription: String {
        switch self {
        case .noDeviceReturned:
            return "デバイス情報の取得に失敗しました"
        case .supabaseNotAvailable:
            return "Supabaseライブラリが利用できません"
        case .registrationFailed:
            return "デバイス登録処理に失敗しました"
        }
    }
}

// デバイス追加エラー
enum DeviceAddError: Error, LocalizedError {
    case invalidDeviceId
    case deviceNotFound
    case alreadyAdded
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidDeviceId:
            return "無効なデバイスIDです"
        case .deviceNotFound:
            return "デバイスが見つかりません"
        case .alreadyAdded:
            return "このデバイスは既に追加されています"
        case .unauthorized:
            return "デバイスの追加権限がありません"
        }
    }
}