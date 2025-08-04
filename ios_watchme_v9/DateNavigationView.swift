//
//  DateNavigationView.swift
//  ios_watchme_v9
//
//  Created by Assistant on 2025/08/02.
//

import SwiftUI

struct DateNavigationView: View {
    @Binding var selectedDate: Date
    @Binding var showDatePicker: Bool
    @EnvironmentObject var deviceManager: DeviceManager
    
    /// デバイスのタイムゾーンを考慮したCalendar
    private var calendar: Calendar {
        deviceManager.deviceCalendar
    }
    
    /// デバイスのタイムゾーンを考慮したDateFormatter
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = deviceManager.selectedDeviceTimezone
        return formatter
    }
    
    private var canGoToNextDay: Bool {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        // デバイスのタイムゾーンでの「今日」を基準に判定
        let deviceNow = Date()
        let deviceToday = calendar.startOfDay(for: deviceNow)
        let deviceTomorrow = calendar.date(byAdding: .day, value: 1, to: deviceToday) ?? deviceToday
        return tomorrow <= deviceTomorrow
    }
    
    var body: some View {
        HStack {
            Button(action: {
                withAnimation {
                    selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            Button(action: {
                showDatePicker = true
            }) {
                VStack(spacing: 4) {
                    Text(dateFormatter.string(from: selectedDate))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if calendar.isDateInToday(selectedDate) {
                        Text("今日")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    let tomorrow = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    // デバイスのタイムゾーンでの判定
                    let deviceToday = calendar.startOfDay(for: Date())
                    let deviceTomorrow = calendar.date(byAdding: .day, value: 1, to: deviceToday) ?? deviceToday
                    if tomorrow <= deviceTomorrow {
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
    }
}