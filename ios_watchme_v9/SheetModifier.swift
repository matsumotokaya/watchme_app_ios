//
//  SheetModifier.swift
//  ios_watchme_v9
//
//  Created by Assistant on 2025/08/02.
//

import SwiftUI

struct SheetModifier: ViewModifier {
    // シート関連のバインディング
    @Binding var showDeviceSelection: Bool
    @Binding var showSubjectRegistration: Bool
    @Binding var showSubjectEdit: Bool
    @Binding var showRecordingSheet: Bool
    @Binding var showDatePicker: Bool
    @Binding var selectedDate: Date
    @Binding var subjectsByDevice: [String: Subject]
    @Binding var selectedDeviceForSubject: String?
    @Binding var editingSubject: Subject?
    @Binding var selectedTab: Int
    
    // 必要なオブジェクト
    let networkManager: NetworkManager
    let audioRecorder: AudioRecorder
    let authManager: SupabaseAuthManager
    let deviceManager: DeviceManager
    let dataManager: SupabaseDataManager
    let loadSubjectsForAllDevices: () -> Void
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showDeviceSelection, onDismiss: {
                loadSubjectsForAllDevices()
            }) {
                DeviceSelectionView(isPresented: $showDeviceSelection, subjectsByDevice: $subjectsByDevice)
                    .environmentObject(deviceManager)
                    .environmentObject(dataManager)
                    .environmentObject(authManager)
                    .onAppear {
                        loadSubjectsForAllDevices()
                    }
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
                NavigationStack {
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
            .sheet(isPresented: $showDatePicker) {
                NavigationStack {
                    VStack {
                        DatePicker(
                            "日付を選択",
                            selection: $selectedDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .padding()
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                        
                        Spacer()
                    }
                    .navigationTitle("日付を選択")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("キャンセル") {
                                showDatePicker = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("完了") {
                                showDatePicker = false
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
            }
    }
}