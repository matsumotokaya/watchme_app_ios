//
//  AlertModifier.swift
//  ios_watchme_v9
//
//  Created by Assistant on 2025/08/02.
//

import SwiftUI

struct AlertModifier: ViewModifier {
    // アラート関連のバインディング
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    @Binding var showUserIDChangeAlert: Bool
    @Binding var newUserID: String
    @Binding var showLogoutConfirmation: Bool
    
    // 必要なマネージャー
    let networkManager: NetworkManager
    let authManager: SupabaseAuthManager
    let deviceManager: DeviceManager
    let dataManager: SupabaseDataManager
    
    func body(content: Content) -> some View {
        content
            .alert("通知", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .alert("ユーザーID変更", isPresented: $showUserIDChangeAlert) {
                TextField("新しいユーザーID", text: $newUserID)
                Button("変更") {
                    if !newUserID.isEmpty {
                        networkManager.setUserID(newUserID)
                        alertMessage = "ユーザーIDを変更しました: \(newUserID)"
                        showAlert = true
                    }
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("新しいユーザーIDを入力してください")
            }
            .confirmationDialog("ログアウト確認", isPresented: $showLogoutConfirmation) {
                Button("ログアウト", role: .destructive) {
                    Task {
                        authManager.signOut()
                        networkManager.resetToFallbackUserID()
                        dataManager.clearData()
                        deviceManager.userDevices = []
                        deviceManager.selectedDeviceID = nil
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        await MainActor.run {
                            alertMessage = "ログアウトしました"
                            showAlert = true
                        }
                    }
                }
            } message: {
                Text("本当にログアウトしますか？")
            }
    }
}