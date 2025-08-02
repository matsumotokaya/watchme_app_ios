//
//  ContentView.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/06/11.
//

import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var authManager: SupabaseAuthManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var viewState = ContentViewState()
    
    private func initializeNetworkManager() {
        viewState.networkManager = NetworkManager(authManager: authManager, deviceManager: deviceManager)
        
        if let authUser = authManager.currentUser {
            viewState.networkManager?.updateToAuthenticatedUserID(authUser.id)
        }
        print("🔧 NetworkManager初期化完了")
    }
    
    var body: some View {
        if let networkManager = viewState.networkManager {
            NavigationStack {
                VStack(spacing: 0) { // ヘッダー、日付ナビゲーション、TabViewを縦に並べる
                // 固定ヘッダー (デバイス選択、ユーザー情報、通知など)
                HeaderView(
                    showDeviceSelection: $viewState.sheets.showDeviceSelection,
                    showLogoutConfirmation: $viewState.alerts.showLogoutConfirmation
                )
                
                // 日付ナビゲーション
                DateNavigationView(
                    selectedDate: $viewState.navigation.selectedDate,
                    showDatePicker: $viewState.sheets.showDatePicker
                )
                
                TabView(selection: $viewState.navigation.selectedTab) {
                    // ダッシュボードタブ
                    Group {
                        if let viewModel = viewState.dashboardViewModel {
                            DashboardView(viewModel: viewModel, selectedTab: $viewState.navigation.selectedTab)
                        } else {
                            ProgressView("初期化中...")
                        }
                    }
                    .tabItem {
                        Label("ダッシュボード", systemImage: "square.grid.2x2")
                    }
                    .tag(0)
                    
                    // 心理グラフタブ (Vibe Graph)
                    HomeView() // 引数を削除
                    .tabItem {
                        Label("心理グラフ", systemImage: "brain")
                    }
                    .tag(1)
                    
                    // 行動グラフタブ (Behavior Graph)
                    BehaviorGraphView()
                    .tabItem {
                        Label("行動グラフ", systemImage: "figure.walk.motion")
                    }
                    .tag(2)
                    
                    // 感情グラフタブ (Emotion Graph)
                    EmotionGraphView()
                    .tabItem {
                        Label("感情グラフ", systemImage: "heart.text.square")
                    }
                    .tag(3)
                    
                    // 録音タブ（タップでモーダル表示）
                    Text("")
                        .tabItem {
                            Label("録音", systemImage: "mic.circle.fill")
                        }
                        .tag(4)
                        .onAppear {
                            if viewState.navigation.selectedTab == 4 {
                                viewState.sheets.showRecordingSheet = true
                                // タブを前の位置に戻す
                                viewState.navigation.selectedTab = 0
                            }
                        }
                }
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        if value.translation.width > threshold {
                            // 右スワイプ = 前日
                            withAnimation {
                                viewState.navigation.selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: viewState.navigation.selectedDate) ?? viewState.navigation.selectedDate
                            }
                        } else if value.translation.width < -threshold && canGoToNextDay {
                            // 左スワイプ = 翌日
                            withAnimation {
                                viewState.navigation.selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: viewState.navigation.selectedDate) ?? viewState.navigation.selectedDate
                            }
                        }
                    }
            )
            .modifier(AlertModifier(
                showAlert: $viewState.alerts.showAlert,
                alertMessage: $viewState.alerts.alertMessage,
                showUserIDChangeAlert: $viewState.alerts.showUserIDChangeAlert,
                newUserID: $viewState.alerts.newUserID,
                showLogoutConfirmation: $viewState.alerts.showLogoutConfirmation,
                networkManager: networkManager,
                authManager: authManager,
                deviceManager: deviceManager,
                dataManager: dataManager
            ))
            .modifier(SheetModifier(
                showDeviceSelection: $viewState.sheets.showDeviceSelection,
                showSubjectRegistration: $viewState.sheets.showSubjectRegistration,
                showSubjectEdit: $viewState.sheets.showSubjectEdit,
                showRecordingSheet: $viewState.sheets.showRecordingSheet,
                showDatePicker: $viewState.sheets.showDatePicker,
                selectedDate: $viewState.navigation.selectedDate,
                subjectsByDevice: $viewState.data.subjectsByDevice,
                selectedDeviceForSubject: $viewState.sheets.selectedDeviceForSubject,
                editingSubject: $viewState.data.editingSubject,
                selectedTab: $viewState.navigation.selectedTab,
                networkManager: networkManager,
                audioRecorder: audioRecorder,
                authManager: authManager,
                deviceManager: deviceManager,
                dataManager: dataManager,
                loadSubjectsForAllDevices: loadSubjectsForAllDevices
            ))
            .modifier(ChangeHandlerModifier(
                showAlert: $viewState.alerts.showAlert,
                alertMessage: $viewState.alerts.alertMessage,
                selectedDate: $viewState.navigation.selectedDate,
                selectedTab: $viewState.navigation.selectedTab,
                showRecordingSheet: $viewState.sheets.showRecordingSheet,
                networkManager: networkManager,
                deviceManager: deviceManager,
                dashboardViewModel: viewState.dashboardViewModel
            ))
            .onAppear {
                initializeNetworkManager()
                // DashboardViewModelを初期化
                if viewState.dashboardViewModel == nil {
                    viewState.dashboardViewModel = DashboardViewModel(
                        dataManager: dataManager,
                        deviceManager: deviceManager,
                        initialDate: viewState.navigation.selectedDate
                    )
                }
                // ViewModelのonAppearを呼び出す
                viewState.dashboardViewModel?.onAppear()
            }
            }
        } else {
            ProgressView("初期化中...")
                .onAppear {
                    initializeNetworkManager()
                }
        }
    }
    
    // MARK: - Private Methods
    
    private var canGoToNextDay: Bool {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: viewState.navigation.selectedDate) ?? viewState.navigation.selectedDate
        return tomorrow <= Date()
    }
    
    private func loadSubjectsForAllDevices() {
        Task {
            var newSubjects: [String: Subject] = [:]
            
            for device in deviceManager.userDevices {
                // 各デバイスの観測対象を取得
                await dataManager.fetchSubjectForDevice(deviceId: device.device_id)
                if let subject = dataManager.subject {
                    newSubjects[device.device_id] = subject
                }
            }
            
            await MainActor.run {
                self.viewState.data.subjectsByDevice = newSubjects
            }
        }
    }
}


#Preview {
    ContentView()
}
