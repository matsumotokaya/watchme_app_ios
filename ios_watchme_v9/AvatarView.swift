//
//  AvatarView.swift
//  ios_watchme_v9
//

import SwiftUI

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