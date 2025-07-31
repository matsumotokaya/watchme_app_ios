//
//  DashboardViewModel.swift
//  ios_watchme_v9
//
//  Created by Claude on 2025/07/31.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class DashboardViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedDate: Date = Date()
    @Published var selectedDeviceID: String? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // MARK: - Dependencies
    private(set) var dataManager: SupabaseDataManager
    private(set) var deviceManager: DeviceManager
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var fetchTask: Task<Void, Never>?
    
    // MARK: - Initialization
    init(dataManager: SupabaseDataManager, deviceManager: DeviceManager, initialDate: Date) {
        self.dataManager = dataManager
        self.deviceManager = deviceManager
        self.selectedDate = initialDate
    }
    
    // ViewのonAppearで呼ばれ、本物の依存関係を接続するメソッド
    func connect(dataManager: SupabaseDataManager, deviceManager: DeviceManager) {
        // すでに接続済みの場合は何もしない
        guard self.cancellables.isEmpty else { return }
        
        self.dataManager = dataManager
        self.deviceManager = deviceManager
        self.selectedDeviceID = deviceManager.selectedDeviceID
        
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // 日付とデバイスIDの変更を監視
        Publishers.CombineLatest($selectedDate, $selectedDeviceID)
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .sink { [weak self] date, deviceID in
                Task { [weak self] in
                    await self?.fetchAllReports()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func onAppear() {
        // 初回データ取得
        Task {
            await fetchAllReports()
        }
    }
    
    // MARK: - Private Methods
    private func fetchAllReports() async {
        // 既存のタスクをキャンセル
        fetchTask?.cancel()
        
        fetchTask = Task {
            guard !Task.isCancelled else { return }
            
            // デバイスIDの確認
            guard let deviceId = selectedDeviceID ?? deviceManager.localDeviceIdentifier else {
                await MainActor.run {
                    self.errorMessage = "デバイスが選択されていません"
                }
                return
            }
            
            // データ取得を実行
            await dataManager.fetchAllReports(deviceId: deviceId, date: selectedDate)
        }
    }
}