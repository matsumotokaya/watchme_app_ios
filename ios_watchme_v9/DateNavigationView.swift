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
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    private var canGoToNextDay: Bool {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        return tomorrow <= Date()
    }
    
    var body: some View {
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
            
            Button(action: {
                showDatePicker = true
            }) {
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
    }
}