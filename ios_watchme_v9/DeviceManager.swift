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
    @Published var currentDeviceID: String? = nil
    @Published var actualDeviceID: String? = nil  // ユーザーに紐付く実際のデバイスID
    @Published var userDevices: [Device] = []  // ユーザーの全デバイス
    @Published var selectedDeviceID: String? = nil  // 選択中のデバイスID
    @Published var registrationError: String? = nil
    @Published var isLoading: Bool = false
    
    // Supabase設定
    private let supabaseURL = "https://qvtlwotzuzbavrzqhyvt.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF2dGx3b3R6dXpiYXZyenFoeXZ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEzODAzMzAsImV4cCI6MjA2Njk1NjMzMH0.g5rqrbxHPw1dKlaGqJ8miIl9gCXyamPajinGCauEI3k"
    
    // Supabaseクライアント
    private let supabase: SupabaseClient
    
    // UserDefaults キー
    private let deviceIDKey = "watchme_device_id"
    private let isRegisteredKey = "watchme_device_registered"
    private let platformIdentifierKey = "watchme_platform_identifier"
    
    init() {
        // Supabaseクライアント初期化
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: supabaseURL)!,
            supabaseKey: supabaseAnonKey
        )
        
        checkDeviceRegistrationStatus()
    }
    
    // MARK: - デバイス登録状態確認
    private func checkDeviceRegistrationStatus() {
        let savedDeviceID = UserDefaults.standard.string(forKey: deviceIDKey)
        let isSupabaseRegistered = UserDefaults.standard.bool(forKey: "watchme_supabase_registered")
        
        if let deviceID = savedDeviceID, isSupabaseRegistered {
            self.currentDeviceID = deviceID
            self.isDeviceRegistered = true
            print("📱 Supabaseデバイス登録確認: \(deviceID)")
        } else {
            self.isDeviceRegistered = false
            print("📱 デバイス未登録 - Supabase登録が必要")
            
            // 古いローカル登録データがあれば削除
            if UserDefaults.standard.string(forKey: deviceIDKey) != nil {
                print("🗑️ 古いローカル登録データを削除")
                UserDefaults.standard.removeObject(forKey: deviceIDKey)
                UserDefaults.standard.removeObject(forKey: isRegisteredKey)
                UserDefaults.standard.removeObject(forKey: platformIdentifierKey)
            }
        }
    }
    
    
    // MARK: - プラットフォーム識別子取得
    private func getPlatformIdentifier() -> String? {
        return UIDevice.current.identifierForVendor?.uuidString
    }
    
    // MARK: - デバイス登録処理（Supabase直接Insert版）
    func registerDevice(ownerUserID: String? = nil) {
        guard let platformIdentifier = getPlatformIdentifier() else {
            registrationError = "デバイス識別子の取得に失敗しました"
            print("❌ identifierForVendor取得失敗")
            return
        }
        
        isLoading = true
        registrationError = nil
        
        print("📱 Supabaseデバイス登録開始")
        print("   - Platform Identifier: \(platformIdentifier)")
        print("   - Owner User ID: \(ownerUserID ?? "ゲストユーザー")")
        
        // Supabaseライブラリが利用できない場合はエラー
        if !isSupabaseLibraryAvailable() {
            self.isLoading = false
            self.registrationError = "Supabaseライブラリが利用できません。デバイス登録に失敗しました。"
            print("❌ Supabaseライブラリ未利用 - デバイス登録失敗")
            return
        }
        
        // Supabase直接Insert実装
        registerDeviceToSupabase(platformIdentifier: platformIdentifier, ownerUserID: ownerUserID)
    }
    
    // MARK: - Supabaseライブラリ利用可能判定
    private func isSupabaseLibraryAvailable() -> Bool {
        // Supabaseライブラリが追加されているかチェック
        return true
    }
    
    
    // MARK: - Supabase UPSERT登録（改善版）
    private func registerDeviceToSupabase(platformIdentifier: String, ownerUserID: String?) {
        Task { @MainActor in
            do {
                let deviceData = DeviceInsert(
                    platform_identifier: platformIdentifier,
                    device_type: "ios",
                    platform_type: "iOS",
                    owner_user_id: ownerUserID
                )
                
                // UPSERT: INSERT ON CONFLICT DO UPDATE を使用
                let response: [Device] = try await supabase
                    .from("devices")
                    .upsert(deviceData)
                    .select()
                    .execute()
                    .value
                
                if let device = response.first {
                    self.saveSupabaseDeviceRegistration(
                        deviceID: device.device_id,
                        platformIdentifier: platformIdentifier
                    )
                    self.isLoading = false
                    print("✅ デバイス情報を取得/登録完了: \(device.device_id)")
                } else {
                    throw DeviceRegistrationError.noDeviceReturned
                }
                
            } catch {
                print("❌ デバイス情報取得エラー: \(error)")
                self.registrationError = "デバイス情報の取得に失敗しました: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Supabaseデバイス登録情報保存
    private func saveSupabaseDeviceRegistration(deviceID: String, platformIdentifier: String) {
        UserDefaults.standard.set(deviceID, forKey: deviceIDKey)
        UserDefaults.standard.set(platformIdentifier, forKey: platformIdentifierKey)
        UserDefaults.standard.set(true, forKey: "watchme_supabase_registered")
        
        self.currentDeviceID = deviceID
        self.isDeviceRegistered = true
        
        print("💾 Supabaseデバイス登録完了")
        print("   - Device ID: \(deviceID)")
        print("   - Platform Identifier: \(platformIdentifier)")
    }
    
    // MARK: - デバイス登録状態リセット（デバッグ用）
    func resetDeviceRegistration() {
        UserDefaults.standard.removeObject(forKey: deviceIDKey)
        UserDefaults.standard.removeObject(forKey: platformIdentifierKey)
        UserDefaults.standard.removeObject(forKey: "watchme_supabase_registered")
        
        self.currentDeviceID = nil
        self.isDeviceRegistered = false
        self.registrationError = nil
        
        print("🔄 デバイス登録状態リセット完了")
    }
    
    // MARK: - ユーザーのデバイスを取得
    func fetchUserDevices(for userId: String) async {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/devices") else {
            print("❌ 無効なURL")
            return
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "owner_user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "select", value: "*")
        ]
        
        guard let requestURL = components?.url else {
            print("❌ URLの構築に失敗しました")
            return
        }
        
        print("📡 Fetching devices from: \(requestURL.absoluteString)")
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ 無効なレスポンス")
                return
            }
            
            print("📡 Response status: \(httpResponse.statusCode)")
            
            // エラーレスポンスの詳細を表示
            if httpResponse.statusCode != 200 {
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error response: \(errorData)")
                }
            }
            
            if httpResponse.statusCode == 200 {
                if let rawResponse = String(data: data, encoding: .utf8) {
                    print("📄 Device query response: \(rawResponse)")
                }
                
                let decoder = JSONDecoder()
                let devices = try decoder.decode([Device].self, from: data)
                
                await MainActor.run {
                    self.userDevices = devices
                    print("✅ Found \(devices.count) devices for user: \(userId)")
                    
                    // デバイスが1つの場合は自動選択
                    if devices.count == 1, let device = devices.first {
                        self.selectedDeviceID = device.device_id
                        self.actualDeviceID = device.device_id
                        print("🔍 Auto-selected device: \(device.device_id)")
                    } else if devices.count > 1 {
                        // 複数デバイスの場合は最初のものを選択
                        if let firstDevice = devices.first {
                            self.selectedDeviceID = firstDevice.device_id
                            self.actualDeviceID = firstDevice.device_id
                            print("🔍 Selected first device: \(firstDevice.device_id)")
                        }
                    } else {
                        print("⚠️ No devices found for user: \(userId)")
                    }
                }
            }
        } catch {
            print("❌ Device fetch error: \(error)")
        }
    }
    
    // MARK: - デバイス選択
    func selectDevice(_ deviceId: String) {
        if userDevices.contains(where: { $0.device_id == deviceId }) {
            selectedDeviceID = deviceId
            actualDeviceID = deviceId
            print("📱 Selected device: \(deviceId)")
        }
    }
    
    // MARK: - デバイス情報取得
    func getDeviceInfo() -> DeviceInfo? {
        // 実際のデバイスIDを優先
        let deviceID = actualDeviceID ?? currentDeviceID
        
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
    let owner_user_id: String?
}

// Supabase Response用データモデル
struct Device: Codable {
    let device_id: String
    let platform_identifier: String
    let device_type: String
    let platform_type: String
    let owner_user_id: String?
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