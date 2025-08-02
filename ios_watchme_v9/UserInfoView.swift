//
//  UserInfoView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/08/02.
//

import SwiftUI

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
                            // 名前（profile.nameから取得）
                            if let profile = user.profile, let name = profile.name {
                                InfoRowTwoLine(label: "名前", value: name, icon: "person.fill")
                            }
                            
                            InfoRowTwoLine(label: "メールアドレス", value: user.email, icon: "envelope.fill")
                            
                            // ニュースレター配信設定（会員登録日より上に配置）
                            if let profile = user.profile {
                                let newsletterStatus = profile.newsletter == true ? "ON" : "OFF"
                                InfoRow(label: "ニュースレター配信", value: newsletterStatus, icon: "envelope.badge", valueColor: profile.newsletter == true ? .green : .secondary)
                                
                                // 会員登録日
                                if let createdAt = profile.createdAt {
                                    let formattedDate = formatDate(createdAt)
                                    InfoRow(label: "会員登録日", value: formattedDate, icon: "calendar.badge.plus")
                                }
                            }
                            
                            InfoRowTwoLine(label: "ユーザーID", value: user.id, icon: "person.text.rectangle.fill")
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
                            // DeviceSectionViewを使用
                            DeviceSectionView(
                                devices: deviceManager.userDevices,
                                selectedDeviceID: deviceManager.selectedDeviceID,
                                subjectsByDevice: subjectsByDevice,
                                showSelectionUI: false,
                                isCompact: false,
                                onEditSubject: { deviceId, subject in
                                    selectedDeviceForSubject = deviceId
                                    editingSubject = subject
                                    showSubjectEdit = true
                                },
                                onAddSubject: { deviceId in
                                    selectedDeviceForSubject = deviceId
                                    editingSubject = nil
                                    showSubjectRegistration = true
                                }
                            )
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