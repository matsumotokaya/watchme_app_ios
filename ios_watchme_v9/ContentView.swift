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
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showUserIDChangeAlert = false
    @State private var newUserID = ""
    @State private var showLogoutConfirmation = false
    @State private var networkManager: NetworkManager?
    @State private var showRecordingSheet = false
    @State private var showSubjectRegistration = false
    @State private var showSubjectEdit = false
    @State private var selectedDeviceForSubject: String? = nil
    @State private var editingSubject: Subject? = nil
    @State private var subjectsByDevice: [String: Subject] = [:]
    @State private var showDeviceSelection = false
    
    // 日付の選択状態を一元管理
    @State private var selectedDate = Date()
    // TabViewの選択状態を管理（ダッシュボードから開始）
    @State private var selectedTab = 0
    
    // DashboardViewModelを生成・管理
    @State private var dashboardViewModel: DashboardViewModel?
    @State private var isInitialized = false
    
    // 日付フォーマッター
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    private func initializeNetworkManager() {
        networkManager = NetworkManager(authManager: authManager, deviceManager: deviceManager)
        
        if let authUser = authManager.currentUser {
            networkManager?.updateToAuthenticatedUserID(authUser.id)
        }
        print("🔧 NetworkManager初期化完了")
    }
    
    var body: some View {
        if let networkManager = networkManager {
            NavigationStack {
                VStack(spacing: 0) { // ヘッダー、日付ナビゲーション、TabViewを縦に並べる
                // 固定ヘッダー (デバイス選択、ユーザー情報、通知など)
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
                
                // 日付ナビゲーション
                HStack {
                    Button(action: {
                        withAnimation {
                            selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text(dateFormatter.string(from: selectedDate))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if Calendar.current.isDateInToday(selectedDate) {
                            Text("今日")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                            if tomorrow <= Date() {
                                selectedDate = tomorrow
                            }
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .foregroundColor(canGoToNextDay ? .blue : .gray.opacity(0.3))
                            .frame(width: 44, height: 44)
                    }
                    .disabled(!canGoToNextDay)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground).shadow(radius: 1))
                
                TabView(selection: $selectedTab) {
                    // ダッシュボードタブ
                    NavigationView {
                        if let viewModel = dashboardViewModel {
                            DashboardView(viewModel: viewModel, selectedTab: $selectedTab)
                        } else {
                            ProgressView("初期化中...")
                        }
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                    .tabItem {
                        Label("ダッシュボード", systemImage: "square.grid.2x2")
                    }
                    .tag(0)
                    
                    // 心理グラフタブ (Vibe Graph)
                    NavigationView {
                        HomeView() // 引数を削除
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                    .tabItem {
                        Label("心理グラフ", systemImage: "brain")
                    }
                    .tag(1)
                    
                    // 行動グラフタブ (Behavior Graph)
                    NavigationView {
                        BehaviorGraphView()
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                    .tabItem {
                        Label("行動グラフ", systemImage: "figure.walk.motion")
                    }
                    .tag(2)
                    
                    // 感情グラフタブ (Emotion Graph)
                    NavigationView {
                        EmotionGraphView()
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
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
                            if selectedTab == 4 {
                                showRecordingSheet = true
                                // タブを前の位置に戻す
                                selectedTab = 0
                            }
                        }
                }
            }
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
                    // ログアウト処理を非同期で実行
                    Task {
                        // まずログアウト処理を実行
                        authManager.signOut()
                        
                        // ネットワークマネージャーのリセット
                        networkManager.resetToFallbackUserID()
                        
                        // データマネージャーのクリア
                        dataManager.clearData()
                        
                        // デバイスマネージャーのクリア
                        deviceManager.userDevices = []
                        deviceManager.selectedDeviceID = nil
                        
                        // 少し待ってから通知を表示（UIの更新を確実にするため）
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒待機
                        
                        await MainActor.run {
                            alertMessage = "ログアウトしました"
                            showAlert = true
                        }
                    }
                }
            } message: {
                Text("本当にログアウトしますか？")
            }
            .sheet(isPresented: $showDeviceSelection) {
                DeviceSelectionView(isPresented: $showDeviceSelection)
                    .environmentObject(deviceManager)
                    .environmentObject(dataManager)
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showSubjectRegistration, onDismiss: {
                loadSubjectsForAllDevices()
            }) {
                if let deviceID = selectedDeviceForSubject {
                    SubjectRegistrationView(
                        deviceID: deviceID,
                        isPresented: $showSubjectRegistration,
                        editingSubject: nil
                    )
                    .environmentObject(dataManager)
                    .environmentObject(deviceManager)
                    .environmentObject(authManager)
                }
            }
            .sheet(isPresented: $showSubjectEdit, onDismiss: {
                loadSubjectsForAllDevices()
            }) {
                if let deviceID = selectedDeviceForSubject,
                   let subject = editingSubject {
                    SubjectRegistrationView(
                        deviceID: deviceID,
                        isPresented: $showSubjectEdit,
                        editingSubject: subject
                    )
                    .environmentObject(dataManager)
                    .environmentObject(deviceManager)
                    .environmentObject(authManager)
                }
            }
            .sheet(isPresented: $showRecordingSheet) {
                NavigationView {
                    RecordingView(audioRecorder: audioRecorder, networkManager: networkManager)
                        .navigationTitle("録音")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button(action: {
                                    showRecordingSheet = false
                                }) {
                                    Text("閉じる")
                                }
                            }
                        }
                }
            }
            .onChange(of: networkManager.connectionStatus) { oldValue, newValue in
                // アップロード完了時の通知
                if newValue == .connected && networkManager.currentUploadingFile != nil {
                    alertMessage = "アップロードが完了しました！"
                    showAlert = true
                } else if newValue == .failed && networkManager.currentUploadingFile != nil {
                    alertMessage = "アップロードに失敗しました。手動でリトライしてください。"
                    showAlert = true
                }
            }
            // selectedDate または selectedDeviceID が変更されたときにデータをフェッチ
            .onChange(of: selectedDate) { oldValue, newValue in
                // DashboardViewModelに日付変更を通知（DashboardViewModelが独自にデータ取得）
                dashboardViewModel?.updateSelectedDate(newValue)
                // 他のグラフビュー用にデータをフェッチ
                fetchReports()
            }
            .onChange(of: deviceManager.selectedDeviceID) { oldValue, newValue in
                // 他のグラフビュー用にデータをフェッチ
                fetchReports()
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                if newValue == 4 {
                    showRecordingSheet = true
                    // すぐに前のタブに戻す
                    selectedTab = oldValue
                }
            }
            .onAppear {
                // 初期化は一度だけ行う
                if !isInitialized {
                    isInitialized = true
                    initializeNetworkManager()
                    
                    // DashboardViewModelを初期化
                    dashboardViewModel = DashboardViewModel(
                        dataManager: dataManager,
                        deviceManager: deviceManager,
                        initialDate: selectedDate
                    )
                    
                    // 初回のデータフェッチ
                    fetchReports()
                }
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
    
    private func fetchReports() {
        guard authManager.isAuthenticated else {
            dataManager.errorMessage = "ログインが必要です"
            return
        }
        
        guard let deviceId = deviceManager.selectedDeviceID ?? deviceManager.localDeviceIdentifier else {
            dataManager.errorMessage = "デバイスが登録されていません"
            return
        }
        
        // dataManagerのisLoadingとerrorMessageはfetchAllReports内で管理される
        
        Task {
            await dataManager.fetchAllReports(deviceId: deviceId, date: selectedDate)
        }
    }
    
    private var canGoToNextDay: Bool {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        return tomorrow <= Date()
    }
    
    // MARK: - Observation Target Methods
    
    @ViewBuilder
    private func observationTargetSection(
        for deviceId: String,
        subjectsByDevice: [String: Subject],
        onShowRegistration: @escaping (String) -> Void,
        onShowEdit: @escaping (String, Subject) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                Text("観測対象")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }
            
            if let subject = subjectsByDevice[deviceId] {
                // 観測対象が登録されている場合
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        InfoRowTwoLine(
                            label: "名前",
                            value: subject.name ?? "未設定",
                            icon: "person.crop.circle",
                            valueColor: .primary
                        )
                    }
                    
                    if let ageGender = subject.ageGenderDisplay {
                        InfoRow(label: "年齢・性別", value: ageGender, icon: "info.circle")
                    }
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            onShowEdit(deviceId, subject)
                        }) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("編集")
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                        }
                    }
                }
                .padding(.leading, 20)
            } else {
                // 観測対象が登録されていない場合
                VStack(alignment: .leading, spacing: 6) {
                    InfoRow(label: "状態", value: "未登録", icon: "person.crop.circle.badge.questionmark", valueColor: .secondary)
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            onShowRegistration(deviceId)
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("観測対象を追加")
                            }
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                        }
                    }
                }
                .padding(.leading, 20)
            }
        }
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
                self.subjectsByDevice = newSubjects
            }
        }
    }
}

// MARK: - ユーザー情報ビュー
struct UserInfoView: View {
    let authManager: SupabaseAuthManager
    let deviceManager: DeviceManager
    @Binding var showLogoutConfirmation: Bool
    @State private var subjectsByDevice: [String: Subject] = [:]
    @State private var showSubjectRegistration = false
    @State private var showSubjectEdit = false
    @State private var selectedDeviceForSubject: String? = nil
    @State private var editingSubject: Subject? = nil
    @State private var showAvatarPicker = false
    @State private var isUploadingAvatar = false
    @State private var avatarUploadError: String? = nil
    @EnvironmentObject var dataManager: SupabaseDataManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // ユーザーアバター編集可能なセクション
                VStack(spacing: 12) {
                    AvatarView(userId: authManager.currentUser?.id)
                        .padding(.top, 20)
                    
                    Button(action: {
                        showAvatarPicker = true
                    }) {
                        Label("アバターを編集", systemImage: "pencil.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .disabled(isUploadingAvatar)
                    
                    if isUploadingAvatar {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    }
                    
                    if let error = avatarUploadError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                
                // ユーザー情報セクション
                VStack(spacing: 16) {
                    // ユーザーアカウント情報
                    InfoSection(title: "ユーザーアカウント情報") {
                        if let user = authManager.currentUser {
                            InfoRowTwoLine(label: "メールアドレス", value: user.email, icon: "envelope.fill")
                            InfoRowTwoLine(label: "ユーザーID", value: user.id, icon: "person.text.rectangle.fill")
                            
                            // プロファイル情報がある場合の追加項目
                            if let profile = user.profile {
                                // 会員登録日
                                if let createdAt = profile.createdAt {
                                    let formattedDate = formatDate(createdAt)
                                    InfoRow(label: "会員登録日", value: formattedDate, icon: "calendar.badge.plus")
                                }
                                
                                // ニュースレター配信設定
                                if let newsletter = profile.newsletter {
                                    let newsletterStatus = newsletter ? "受信希望" : "不要"
                                    InfoRow(label: "ニュースレター配信", value: newsletterStatus, icon: "envelope.badge", valueColor: newsletter ? .green : .secondary)
                                }
                            }
                        } else {
                            InfoRow(label: "状態", value: "ログインしていません", icon: "exclamationmark.triangle.fill", valueColor: .red)
                        }
                    }
                    
                    // デバイス情報
                    InfoSection(title: "デバイス情報") {
                        // ユーザーのデバイス一覧
                        if deviceManager.isLoading {
                            InfoRow(label: "状態", value: "デバイス情報を取得中...", icon: "arrow.clockwise", valueColor: .orange)
                        } else if !deviceManager.userDevices.isEmpty {
                            ForEach(Array(deviceManager.userDevices.enumerated()), id: \.element.device_id) { index, device in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("デバイス \(index + 1)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    InfoRow(label: "デバイスID", value: device.device_id, icon: "iphone")
                                    if device.device_id == deviceManager.selectedDeviceID {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                            Text("現在選択中")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                        .padding(.leading, 20)
                                    }
                                    
                                    // 観測対象情報
                                    observationTargetInfo(for: device.device_id)
                                }
                                if index < deviceManager.userDevices.count - 1 {
                                    Divider()
                                        .padding(.vertical, 4)
                                }
                            }
                        } else {
                            VStack(spacing: 12) {
                                InfoRow(label: "状態", value: "デバイスが連携されていません", icon: "iphone.slash", valueColor: .orange)
                                
                                Button(action: {
                                    // デバイス連携処理を実行
                                    if let userId = authManager.currentUser?.id {
                                        deviceManager.registerDevice(userId: userId)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "link.circle.fill")
                                        Text("このデバイスを連携")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                .disabled(deviceManager.isLoading)
                            }
                        }
                        
                        // デバイス登録エラー表示
                        if let error = deviceManager.registrationError {
                            InfoRow(label: "エラー", value: error, icon: "exclamationmark.triangle.fill", valueColor: .red)
                        }
                    }
                    
                    // 認証状態
                    InfoSection(title: "認証状態") {
                        InfoRow(label: "認証状態", value: authManager.isAuthenticated ? "認証済み" : "未認証", 
                               icon: authManager.isAuthenticated ? "checkmark.shield.fill" : "xmark.shield.fill",
                               valueColor: authManager.isAuthenticated ? .green : .red)
                    }
                }
                
                Spacer()
                
                // ログアウトボタン
                if authManager.isAuthenticated {
                    Button(action: {
                        dismiss()
                        // シートが完全に閉じてからダイアログを表示
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showLogoutConfirmation = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                            Text("ログアウト")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("マイページ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
                // デバイス情報を再取得
                if deviceManager.userDevices.isEmpty, let userId = authManager.currentUser?.id {
                    print("📱 UserInfoSheet: デバイス情報を取得")
                    Task {
                        await deviceManager.fetchUserDevices(for: userId)
                    }
                }
                // 観測対象情報を読み込み
                loadSubjectsForAllDevices()
            }
        .sheet(isPresented: $showSubjectRegistration, onDismiss: {
            loadSubjectsForAllDevices()
        }) {
            if let deviceID = selectedDeviceForSubject {
                SubjectRegistrationView(
                    deviceID: deviceID,
                    isPresented: $showSubjectRegistration,
                    editingSubject: nil
                )
                .environmentObject(dataManager)
                .environmentObject(deviceManager)
                .environmentObject(authManager)
            }
        }
        .sheet(isPresented: $showSubjectEdit, onDismiss: {
            loadSubjectsForAllDevices()
        }) {
            if let deviceID = selectedDeviceForSubject,
               let subject = editingSubject {
                SubjectRegistrationView(
                    deviceID: deviceID,
                    isPresented: $showSubjectEdit,
                    editingSubject: subject
                )
                .environmentObject(dataManager)
                .environmentObject(deviceManager)
                .environmentObject(authManager)
            }
        }
        .sheet(isPresented: $showAvatarPicker) {
            NavigationView {
                VStack {
                    AvatarPickerView(
                        currentAvatarURL: getAvatarURL(),
                        onImageSelected: { image in
                            uploadAvatar(image: image)
                        },
                        onDelete: nil // ユーザーアバターの削除は現時点では実装しない
                    )
                    .padding()
                    
                    Spacer()
                }
                .navigationTitle("アバターを選択")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            showAvatarPicker = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Observation Target Info Methods
    
    @ViewBuilder
    private func observationTargetInfo(for deviceId: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                Text("観測対象")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }
            
            if let subject = subjectsByDevice[deviceId] {
                // 観測対象が登録されている場合
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        InfoRowTwoLine(
                            label: "名前",
                            value: subject.name ?? "未設定",
                            icon: "person.crop.circle",
                            valueColor: .primary
                        )
                    }
                    
                    if let ageGender = subject.ageGenderDisplay {
                        InfoRow(label: "年齢・性別", value: ageGender, icon: "info.circle")
                    }
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            selectedDeviceForSubject = deviceId
                            editingSubject = subject
                            showSubjectEdit = true
                        }) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("編集")
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                        }
                    }
                }
                .padding(.leading, 20)
            } else {
                // 観測対象が登録されていない場合
                VStack(alignment: .leading, spacing: 6) {
                    InfoRow(label: "状態", value: "未登録", icon: "person.crop.circle.badge.questionmark", valueColor: .secondary)
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            selectedDeviceForSubject = deviceId
                            editingSubject = nil
                            showSubjectRegistration = true
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("観測対象を追加")
                            }
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                        }
                    }
                }
                .padding(.leading, 20)
            }
        }
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
                self.subjectsByDevice = newSubjects
            }
        }
    }
    
    // MARK: - Avatar Helper Methods
    
    private func getAvatarURL() -> URL? {
        guard let userId = authManager.currentUser?.id else { return nil }
        return AWSManager.shared.getAvatarURL(type: "users", id: userId)
    }
    
    private func uploadAvatar(image: UIImage) {
        guard let userId = authManager.currentUser?.id else { 
            print("❌ User ID not found")
            return 
        }
        
        print("🚀 Starting avatar upload for user: \(userId)")
        print("📐 Image size: \(image.size), Scale: \(image.scale)")
        
        isUploadingAvatar = true
        avatarUploadError = nil
        showAvatarPicker = false
        
        Task {
            do {
                // ✅ Avatar Uploader APIを使用してS3にアップロード
                let url = try await AWSManager.shared.uploadAvatar(
                    image: image,
                    type: "users",
                    id: userId
                )
                
                await MainActor.run {
                    isUploadingAvatar = false
                    // AvatarViewを強制的に更新
                    NotificationCenter.default.post(name: NSNotification.Name("AvatarUpdated"), object: nil)
                    print("✅ アバターアップロード成功: \(url)")
                    
                    // 成功メッセージを表示（オプション）
                    // TODO: アラートやトーストで成功を通知
                }
            } catch {
                await MainActor.run {
                    isUploadingAvatar = false
                    avatarUploadError = error.localizedDescription
                    print("❌ アバターアップロードエラー: \(error)")
                    print("📝 Error details: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - 情報セクション
struct InfoSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                content
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
}

// MARK: - 情報行
struct InfoRow: View {
    let label: String
    let value: String
    let icon: String
    let valueColor: Color
    
    init(label: String, value: String, icon: String, valueColor: Color = .primary) {
        self.label = label
        self.value = value
        self.icon = icon
        self.valueColor = valueColor
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

// MARK: - 2行表示情報行
struct InfoRowTwoLine: View {
    let label: String
    let value: String
    let icon: String
    let valueColor: Color
    
    init(label: String, value: String, icon: String, valueColor: Color = .primary) {
        self.label = label
        self.value = value
        self.icon = icon
        self.valueColor = valueColor
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(valueColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
    }
}

// MARK: - アバタービュー
struct AvatarView: View {
    let userId: String?
    let size: CGFloat = 80
    let useS3: Bool = true // ✅ Avatar Uploader APIを使用してS3に保存
    @EnvironmentObject var dataManager: SupabaseDataManager
    @State private var avatarUrl: URL?
    @State private var isLoadingAvatar = true
    @State private var lastUpdateTime = Date()
    
    var body: some View {
        Group {
            if isLoadingAvatar {
                // 読み込み中
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: size, height: size)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
            } else if let url = avatarUrl {
                // アバター画像を表示
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    case .failure(_):
                        // エラー時のデフォルトアイコン
                        defaultAvatarView
                    case .empty:
                        // 読み込み中
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: size, height: size)
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                    @unknown default:
                        defaultAvatarView
                    }
                }
            } else {
                // アバター未設定時のデフォルトアイコン
                defaultAvatarView
            }
        }
        .onAppear {
            loadAvatar()
        }
        .onChange(of: userId) { oldValue, newValue in
            loadAvatar()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AvatarUpdated"))) { _ in
            // アバターが更新されたら再読み込み
            lastUpdateTime = Date()
            loadAvatar()
        }
    }
    
    private func loadAvatar() {
        Task {
            guard let userId = userId else {
                print("⚠️ ユーザーIDが指定されていません")
                isLoadingAvatar = false
                return
            }
            
            isLoadingAvatar = true
            
            if useS3 {
                // S3のURLを設定（Avatar Uploader API経由でアップロード済み）
                let baseURL = AWSManager.shared.getAvatarURL(type: "users", id: userId)
                let timestamp = Int(lastUpdateTime.timeIntervalSince1970)
                self.avatarUrl = URL(string: "\(baseURL.absoluteString)?t=\(timestamp)")
                print("🌐 Loading avatar from S3: \(self.avatarUrl?.absoluteString ?? "nil")")
            } else {
                // Supabaseから取得（既存の実装）
                self.avatarUrl = await dataManager.fetchAvatarUrl(for: userId)
            }
            
            self.isLoadingAvatar = false
        }
    }
    
    private var defaultAvatarView: some View {
        Image(systemName: "person.crop.circle.fill")
            .font(.system(size: size))
            .foregroundColor(.blue)
    }
}

// MARK: - ヘルパー関数
private func formatDate(_ dateString: String) -> String {
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    // ISO8601形式でパースを試行
    if let date = isoFormatter.date(from: dateString) {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    // フォールバック: 別の形式を試行
    let fallbackFormatter = DateFormatter()
    fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
    if let date = fallbackFormatter.date(from: dateString) {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    // 最終的にフォーマットできない場合は元の文字列を返す
    return dateString
}

#Preview {
    ContentView()
}
