//
//  DeviceSelectionView.swift
//  ios_watchme_v9
//
//  Created by Kaya Matsumoto on 2025/07/30.
//

import SwiftUI

struct DeviceSelectionView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var dataManager: SupabaseDataManager
    @EnvironmentObject var authManager: SupabaseAuthManager
    @Binding var isPresented: Bool
    @Binding var subjectsByDevice: [String: Subject]
    @State private var showQRScanner = false
    @State private var showAddDeviceAlert = false
    @State private var addDeviceError: String?
    @State private var showSuccessAlert = false
    @State private var addedDeviceId: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if deviceManager.isLoading {
                    ProgressView("デバイス一覧を読み込み中...")
                        .padding()
                } else if deviceManager.userDevices.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "iphone.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("連携されたデバイスがありません")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Text("他のデバイスから測定データを\n共有することができます")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        Section(header: Text("利用可能なデバイス")) {
                            DeviceSectionView(
                                devices: deviceManager.userDevices,
                                selectedDeviceID: deviceManager.selectedDeviceID,
                                subjectsByDevice: subjectsByDevice,
                                showSelectionUI: true,
                                onDeviceSelected: { deviceId in
                                    deviceManager.selectDevice(deviceId)
                                    // 少し遅延を入れてからシートを閉じる（アニメーション用）
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        isPresented = false
                                    }
                                }
                            )
                        }
                        
                        Section {
                            Button(action: {
                                showQRScanner = true
                            }) {
                                HStack {
                                    Image(systemName: "qrcode.viewfinder")
                                        .font(.title3)
                                    Text("デバイスを追加")
                                        .font(.body)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                            .foregroundColor(.white)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("デバイス選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showQRScanner) {
                QRCodeScannerView(isPresented: $showQRScanner) { scannedCode in
                    Task {
                        await handleQRCodeScanned(scannedCode)
                    }
                }
            }
            .alert("デバイス追加エラー", isPresented: $showAddDeviceAlert, presenting: addDeviceError) { _ in
                Button("OK", role: .cancel) { }
            } message: { error in
                Text(error)
            }
            .alert("デバイスを追加しました", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                if let deviceId = addedDeviceId {
                    Text("device_id: \(deviceId.prefix(8))... が閲覧可能になりました！")
                }
            }
        }
    }
    
    private func handleQRCodeScanned(_ code: String) async {
        // UUIDの妥当性チェック
        guard UUID(uuidString: code) != nil else {
            addDeviceError = "無効なQRコードです。デバイスIDが正しくありません。"
            showAddDeviceAlert = true
            return
        }
        
        // 既に追加済みかチェック
        if deviceManager.userDevices.contains(where: { $0.device_id == code }) {
            addDeviceError = "このデバイスは既に追加されています。"
            showAddDeviceAlert = true
            return
        }
        
        // デバイスを追加
        do {
            if let userId = authManager.currentUser?.id {
                try await deviceManager.addDeviceByQRCode(code, for: userId)
                // 成功時のフィードバック
                addedDeviceId = code
                showSuccessAlert = true
            } else {
                addDeviceError = "ユーザー情報の取得に失敗しました。"
                showAddDeviceAlert = true
            }
        } catch {
            addDeviceError = "デバイスの追加に失敗しました: \(error.localizedDescription)"
            showAddDeviceAlert = true
        }
    }
}

// プレビュー用
struct DeviceSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceSelectionView(isPresented: .constant(true), subjectsByDevice: .constant([:]))
            .environmentObject(DeviceManager())
            .environmentObject(SupabaseDataManager())
            .environmentObject(SupabaseAuthManager(deviceManager: DeviceManager()))
    }
}