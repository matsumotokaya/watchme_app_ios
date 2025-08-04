//
//  RecordingView.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/25.
//

import SwiftUI
import Combine

struct RecordingView: View {
    @ObservedObject var audioRecorder: AudioRecorder
    @ObservedObject var networkManager: NetworkManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var authManager: SupabaseAuthManager
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedRecording: RecordingModel?
    @State private var uploadingTotalCount = 0
    @State private var uploadingCurrentIndex = 0
    @State private var showDeviceLinkAlert = false
    @State private var isLinkingDevice = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // WatchMe Pro プロモーションセクション
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        Image(systemName: "applewatch.radiowaves.left.and.right")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("ウェアラブルデバイス「WatchMe」を使って簡単に24時間ノータッチでこころの分析が可能です。WatchMe Pro プランに切り替えて、始めてみましょう。")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                    }
                    
                    // サブスクリプションボタン
                    Button(action: {
                        if let url = URL(string: "https://hey-watch.me/") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        VStack(spacing: 4) {
                            Text("WatchMe Pro プラン")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("月額980円")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                
                Divider()
                    .padding(.vertical, 8)
                
                // 統計情報（アップロード済み・アップロード待ち）
                HStack(spacing: 20) {
                // アップロード済み
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                    
                    Text("アップロード済み")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    let uploadedCount = audioRecorder.recordings.filter { $0.isUploaded }.count
                    Text("\(uploadedCount)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.green.opacity(0.1))
                .cornerRadius(16)
                
                // アップロード待ち
                VStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                    
                    Text("アップロード待ち")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    let pendingCount = audioRecorder.recordings.filter { !$0.isUploaded }.count
                    Text("\(pendingCount)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(16)
            }
            .padding(.horizontal)
            
            // アップロード進捗表示
            if networkManager.connectionStatus == .uploading {
                VStack(spacing: 8) {
                    HStack {
                        if uploadingTotalCount > 0 {
                            Text("📤 アップロード中 (\(uploadingCurrentIndex)/\(uploadingTotalCount)件)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        } else {
                            Text("📤 アップロード中...")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        Text("\(Int(networkManager.uploadProgress * 100))%")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    
                    ProgressView(value: networkManager.uploadProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    
                    if let fileName = networkManager.currentUploadingFile {
                        Text("ファイル: \(fileName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            
            // 録音コントロール
            VStack(spacing: 16) {
                if audioRecorder.isRecording {
                    // 録音中の表示
                    VStack(spacing: 8) {
                        Text("🔴 録音中...")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text(audioRecorder.formatTime(audioRecorder.recordingTime))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        
                        Text(audioRecorder.getCurrentSlotInfo())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                    
                    // 録音停止ボタン
                    Button(action: {
                        audioRecorder.stopRecording()
                        print("💾 録音停止完了 - 手動でアップロードしてください")
                    }) {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("録音停止")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                } else {
                    // 録音開始ボタン
                    VStack(spacing: 8) {
                        Button(action: {
                            // デバイス連携チェック
                            if deviceManager.userDevices.isEmpty {
                                showDeviceLinkAlert = true
                            } else {
                                audioRecorder.startRecording()
                            }
                        }) {
                            HStack {
                                Image(systemName: "mic.fill")
                                Text("録音開始")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isLinkingDevice)
                    }
                }
            }
            
            // 録音一覧
            if !audioRecorder.recordings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("録音ファイル")
                            .font(.headline)
                        
                        Spacer()
                        
                        // 一括アップロードボタン
                        if audioRecorder.recordings.filter({ !$0.isUploaded && $0.canUpload }).count > 0 {
                            Button(action: {
                                manualBatchUpload()
                            }) {
                                HStack {
                                    Image(systemName: "icloud.and.arrow.up")
                                    Text("すべてアップロード")
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .disabled(networkManager.connectionStatus == .uploading)
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        // 古いファイルクリーンアップボタン
                        if audioRecorder.recordings.contains(where: { $0.fileName.hasPrefix("recording_") }) {
                            Button(action: {
                                audioRecorder.cleanupOldFiles()
                                alertMessage = "古い形式のファイルを削除しました"
                                showAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                    Text("古いファイルを一括削除")
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(audioRecorder.recordings, id: \.fileName) { recording in
                                    RecordingRowView(
                                        recording: recording,
                                        isSelected: selectedRecording?.fileName == recording.fileName,
                                        onSelect: { selectedRecording = recording },
                                        onDelete: { recording in
                                            audioRecorder.deleteRecording(recording)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .frame(maxHeight: 300)
                }
            } else {
                Text("録音ファイルがありません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            }
            }
            .padding()
        }
        .alert("通知", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert("デバイス連携が必要です", isPresented: $showDeviceLinkAlert) {
            Button("はい") {
                // デバイス連携を実行
                linkDeviceAndStartRecording()
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("デバイスが連携されていないため録音できません。\nこのデバイスを連携しますか？")
        }
        .overlay(
            // デバイス連携中の表示
            Group {
                if isLinkingDevice {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("デバイスを連携しています...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(40)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(20)
                    }
                }
            }
        )
    }
    
    // デバイス連携後に録音を開始する
    private func linkDeviceAndStartRecording() {
        guard let userId = authManager.currentUser?.id else {
            alertMessage = "ユーザー情報が取得できません"
            showAlert = true
            return
        }
        
        isLinkingDevice = true
        
        // デバイス連携を実行
        deviceManager.registerDevice(userId: userId)
        
        // デバイス連携の完了を監視
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            checkDeviceLinkingStatus()
        }
    }
    
    // デバイス連携の状態を定期的にチェック
    private func checkDeviceLinkingStatus() {
        if deviceManager.isLoading {
            // まだ連携中なので、再度チェック
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                checkDeviceLinkingStatus()
            }
        } else {
            // 連携完了
            isLinkingDevice = false
            
            if let error = deviceManager.registrationError {
                // エラーが発生した場合
                alertMessage = "デバイス連携に失敗しました: \(error)"
                showAlert = true
            } else if deviceManager.isDeviceRegistered {
                // 連携成功
                alertMessage = "デバイス連携が完了しました"
                showAlert = true
                
                // ユーザーのデバイス一覧を再取得
                Task {
                    if let userId = authManager.currentUser?.id {
                        await deviceManager.fetchUserDevices(for: userId)
                    }
                    
                    // 少し待ってから録音を開始
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        audioRecorder.startRecording()
                    }
                }
            } else {
                // 予期しない状態
                alertMessage = "デバイス連携の状態が不明です"
                showAlert = true
            }
        }
    }
    
    // シンプルな一括アップロード（NetworkManagerを直接使用）- 逐次実行版
    private func manualBatchUpload() {
        // アップロード対象のリストを取得
        let recordingsToUpload = audioRecorder.recordings.filter { $0.canUpload }
        
        guard !recordingsToUpload.isEmpty else {
            alertMessage = "アップロード対象のファイルがありません。"
            showAlert = true
            return
        }
        
        print("📤 一括アップロード開始: \(recordingsToUpload.count)件")
        
        // アップロード件数を設定
        uploadingTotalCount = recordingsToUpload.count
        uploadingCurrentIndex = 0
        
        // 最初のファイルからアップロードを開始する
        uploadSequentially(recordings: recordingsToUpload)
    }
    
    // 再帰的にファイルを1つずつアップロードする関数
    private func uploadSequentially(recordings: [RecordingModel]) {
        // アップロードするリストが空になったら処理を終了
        guard let recording = recordings.first else {
            print("✅ 全ての一括アップロードが完了しました。")
            DispatchQueue.main.async {
                self.alertMessage = "すべての一括アップロードが完了しました。"
                self.showAlert = true
                // カウンターをリセット
                self.uploadingTotalCount = 0
                self.uploadingCurrentIndex = 0
            }
            return
        }
        
        // リストの残りを次の処理のために準備
        var remainingRecordings = recordings
        remainingRecordings.removeFirst()
        
        // 現在のアップロード番号を更新
        uploadingCurrentIndex = uploadingTotalCount - recordings.count + 1
        
        print("📤 アップロード中: \(recording.fileName) (\(uploadingCurrentIndex)/\(uploadingTotalCount))")
        
        // 1つのファイルをアップロード
        networkManager.uploadRecording(recording) { success in
            if success {
                print("✅ 一括アップロード成功: \(recording.fileName)")
                
                // アップロードが成功したので、このファイルを削除する
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("🗑️ 送信済みファイルを削除します:\(recording.fileName)")
                    self.audioRecorder.deleteRecording(recording)
                }
            } else {
                print("❌ 一括アップロード失敗: \(recording.fileName)")
            }
            
            // 成功・失敗にかかわらず、次のファイルのアップロードを再帰的に呼び出す
            self.uploadSequentially(recordings: remainingRecordings)
        }
    }
}

// MARK: - 録音ファイル行のビュー
struct RecordingRowView: View {
    @ObservedObject var recording: RecordingModel
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: (RecordingModel) -> Void
    @EnvironmentObject var deviceManager: DeviceManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(recording.fileName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(recording.fileSizeFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(DateFormatter.display(for: deviceManager).string(from: recording.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    // アップロード状態
                    Text("アップロード: \(recording.isUploaded ? "✅" : "❌")")
                        .font(.caption)
                        .foregroundColor(recording.isUploaded ? .green : .red)
                        .onChange(of: recording.isUploaded) { oldValue, newValue in
                            print("🔍 [RecordingRowView] isUploaded変更検知: \(recording.fileName) - \(oldValue) → \(newValue)")
                        }
                    
                    if !recording.isUploaded {
                        // 試行回数表示
                        if recording.uploadAttempts > 0 {
                            Text("試行: \(recording.uploadAttempts)/3")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        // アップロード可能チェック
                        if !recording.canUpload {
                            Text("アップロード不可")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Spacer()
                }
                
                // エラー情報表示
                if let error = recording.lastUploadError {
                    Text("エラー: \(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                // 最大試行回数に達した場合はリセットボタンを表示
                if recording.uploadAttempts >= 3 {
                    Button(action: {
                        recording.resetUploadStatus()
                        print("🔄 アップロード状態リセット: \(recording.fileName)")
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.orange)
                    }
                }
                
                // 削除ボタン
                Button(action: { onDelete(recording) }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(8)
        .onTapGesture {
            onSelect()
        }
    }
}

// 日付フォーマッター
extension DateFormatter {
    static func display(for deviceManager: DeviceManager) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.locale = Locale.current
        // デバイスのタイムゾーンを使用
        formatter.timeZone = deviceManager.selectedDeviceTimezone
        return formatter
    }
}

#Preview {
    let deviceManager = DeviceManager()
    let authManager = SupabaseAuthManager(deviceManager: deviceManager)
    return RecordingView(
        audioRecorder: AudioRecorder(),
        networkManager: NetworkManager(
            authManager: authManager,
            deviceManager: deviceManager
        )
    )
}