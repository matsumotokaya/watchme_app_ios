//
//  ChangeHandlerModifier.swift
//  ios_watchme_v9
//
//  Created by Assistant on 2025/08/02.
//

import SwiftUI

struct ChangeHandlerModifier: ViewModifier {
    // 変更監視に必要なバインディング
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    @Binding var selectedDate: Date
    @Binding var selectedTab: Int
    @Binding var showRecordingSheet: Bool
    
    // 必要なオブジェクト
    let networkManager: NetworkManager
    let deviceManager: DeviceManager
    let dashboardViewModel: DashboardViewModel?
    
    func body(content: Content) -> some View {
        content
            .onChange(of: networkManager.connectionStatus) { oldValue, newValue in
                guard networkManager.currentUploadingFile != nil else { return }
                if newValue == .connected {
                    alertMessage = "アップロードが完了しました！"
                    showAlert = true
                } else if newValue == .failed {
                    alertMessage = "アップロードに失敗しました。手動でリトライしてください。"
                    showAlert = true
                }
            }
            .onChange(of: selectedDate) { oldValue, newValue in
                dashboardViewModel?.updateSelectedDate(newValue)
            }
            .onChange(of: deviceManager.selectedDeviceID) { oldValue, newValue in
                // ViewModelが自身のPublisherで検知するため、ここでの処理は不要
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                if newValue == 4 {
                    showRecordingSheet = true
                    selectedTab = oldValue
                }
            }
    }
}