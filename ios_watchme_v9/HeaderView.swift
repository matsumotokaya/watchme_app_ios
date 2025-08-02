//
//  HeaderView.swift
//  ios_watchme_v9
//
//  Created by Assistant on 2025/08/02.
//

import SwiftUI

struct HeaderView: View {
    @EnvironmentObject var authManager: SupabaseAuthManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    @Binding var showDeviceSelection: Bool
    @Binding var showLogoutConfirmation: Bool
    
    var body: some View {
        HStack {
            // デバイス選択ボタン
            Button(action: {
                showDeviceSelection = true
            }) {
                HStack {
                    Image(systemName: deviceManager.userDevices.isEmpty ? "iphone.slash" : "iphone")
                    Text(deviceManager.userDevices.isEmpty ? "デバイス連携: なし" : deviceManager.selectedDeviceID?.prefix(8) ?? "デバイス未選択")
                }
                .font(.subheadline)
                .foregroundColor(deviceManager.userDevices.isEmpty ? .orange : .blue)
            }
            
            Spacer()
            
            // ユーザー情報/通知 (仮)
            NavigationLink(destination: 
                UserInfoView(
                    authManager: authManager,
                    deviceManager: deviceManager,
                    showLogoutConfirmation: $showLogoutConfirmation
                )
                .environmentObject(dataManager)
                .environmentObject(deviceManager)
                .environmentObject(authManager)
            ) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground).shadow(radius: 1))
    }
}