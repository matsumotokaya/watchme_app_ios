//
//  ContentViewState.swift
//  ios_watchme_v9
//
//  Created by Assistant on 2025/08/02.
//

import SwiftUI
import Combine

// MARK: - ContentViewState
class ContentViewState: ObservableObject {
    // MARK: - Alert States
    @Published var alerts = AlertState()
    
    // MARK: - Sheet States
    @Published var sheets = SheetState()
    
    // MARK: - Navigation States
    @Published var navigation = NavigationState()
    
    // MARK: - Data States
    @Published var data = DataState()
    
    // MARK: - Other States
    @Published var networkManager: NetworkManager?
    @Published var dashboardViewModel: DashboardViewModel?
    
    // MARK: - Methods
    func resetAlerts() {
        alerts = AlertState()
    }
    
    func resetSheets() {
        sheets = SheetState()
    }
    
    func resetAll() {
        alerts = AlertState()
        sheets = SheetState()
        navigation = NavigationState()
        data = DataState()
    }
}

// MARK: - Alert State
struct AlertState {
    var showAlert = false
    var alertMessage = ""
    var showUserIDChangeAlert = false
    var newUserID = ""
    var showLogoutConfirmation = false
}

// MARK: - Sheet State
struct SheetState {
    var showRecordingSheet = false
    var showSubjectRegistration = false
    var showSubjectEdit = false
    var showDeviceSelection = false
    var showDatePicker = false
    var selectedDeviceForSubject: String? = nil
}

// MARK: - Navigation State
struct NavigationState {
    var selectedDate = Date()
    var selectedTab = 0
}

// MARK: - Data State
struct DataState {
    var editingSubject: Subject? = nil
    var subjectsByDevice: [String: Subject] = [:]
}