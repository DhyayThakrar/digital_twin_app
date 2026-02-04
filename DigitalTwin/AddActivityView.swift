import SwiftUI

// MARK: - Add Activity View
struct AddActivityView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var activityManager = ActivityManager.shared
    
    @State private var selectedType: ActivityType = .aerobic
    @State private var activityName: String = ""
    @State private var stressLevel: Int = 5
    @State private var startTime: Date = Date().addingTimeInterval(-3600) // Default to 1 hour ago
    @State private var endTime: Date = Date()
    @State private var showingSuccessAlert = false
    
    // Calculate the start of today for date picker bounds
    private var startOfToday: Date {
        Calendar.current.startOfDay(for: Date())
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Activity Type Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Activity Type")
                            .font(.headline)
                        
                        ForEach(ActivityType.allCases) { type in
                            ActivityTypeRow(
                                type: type,
                                isSelected: selectedType == type,
                                onTap: { selectedType = type }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Activity Name Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Activity Name")
                            .font(.headline)
                        
                        TextField("e.g., Morning Run, Work Meeting", text: $activityName)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.vertical, 8)
                } footer: {
                    Text("Describe what you were doing")
                }
                
                // Time Section
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("When did you do this activity?")
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start Time")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                DatePicker("", selection: $startTime, in: startOfToday...Date(), displayedComponents: [.hourAndMinute])
                                    .labelsHidden()
                                    .onChange(of: startTime) { oldValue, newValue in
                                        // Ensure end time is not before start time
                                        if endTime < newValue {
                                            endTime = newValue.addingTimeInterval(1800) // Add 30 min
                                        }
                                    }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right")
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("End Time")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                DatePicker("", selection: $endTime, in: startTime...Date(), displayedComponents: [.hourAndMinute])
                                    .labelsHidden()
                            }
                        }
                        
                        // Duration display
                        let duration = Int(endTime.timeIntervalSince(startTime) / 60)
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                            Text("Duration: \(formatDuration(duration))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                } footer: {
                    Text("Select the time range when you performed this activity today")
                }
                
                // Stress Level Section
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Stress Level During Activity")
                                .font(.headline)
                            Spacer()
                            Text("\(stressLevel)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(stressLevelColor)
                        }
                        
                        StressLevelSlider(value: $stressLevel)
                        
                        HStack {
                            Text("Relaxed")
                                .font(.caption)
                                .foregroundColor(.green)
                            Spacer()
                            Text("Moderate")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Spacer()
                            Text("Very Stressed")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 8)
                } footer: {
                    Text("Rate how stressed you felt during this activity (1 = very relaxed, 10 = extremely stressed)")
                }
                
                // Save Button
                Section {
                    Button(action: saveActivity) {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                            Text("Save Activity")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .disabled(activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Add Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Activity Saved!", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your \(selectedType.rawValue.lowercased()) activity has been recorded.")
            }
        }
    }
    
    private var stressLevelColor: Color {
        switch stressLevel {
        case 1...3: return .green
        case 4...6: return .yellow
        case 7...10: return .red
        default: return .gray
        }
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) hr"
            }
            return "\(hours) hr \(remainingMinutes) min"
        }
    }
    
    private func saveActivity() {
        let trimmedName = activityName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let activity = ActivityEntry(
            activityType: selectedType,
            activityName: trimmedName,
            stressLevel: stressLevel,
            startTime: startTime,
            endTime: endTime
        )
        
        activityManager.addActivity(activity)
        showingSuccessAlert = true
    }
}

// MARK: - Edit Activity View
struct EditActivityView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var activityManager = ActivityManager.shared
    
    let activity: ActivityEntry
    
    @State private var selectedType: ActivityType
    @State private var activityName: String
    @State private var stressLevel: Int
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var showingSuccessAlert = false
    @State private var showingDeleteConfirmation = false
    
    init(activity: ActivityEntry) {
        self.activity = activity
        _selectedType = State(initialValue: activity.activityType)
        _activityName = State(initialValue: activity.activityName)
        _stressLevel = State(initialValue: activity.stressLevel)
        _startTime = State(initialValue: activity.startTime)
        _endTime = State(initialValue: activity.endTime)
    }
    
    // Calculate the start of the activity's day for date picker bounds
    private var startOfActivityDay: Date {
        Calendar.current.startOfDay(for: activity.startTime)
    }
    
    private var endOfActivityDay: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfActivityDay)!
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Activity Type Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Activity Type")
                            .font(.headline)
                        
                        ForEach(ActivityType.allCases) { type in
                            ActivityTypeRow(
                                type: type,
                                isSelected: selectedType == type,
                                onTap: { selectedType = type }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Activity Name Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Activity Name")
                            .font(.headline)
                        
                        TextField("e.g., Morning Run, Work Meeting", text: $activityName)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.vertical, 8)
                } footer: {
                    Text("Describe what you were doing")
                }
                
                // Time Section
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("When did you do this activity?")
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start Time")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                DatePicker("", selection: $startTime, in: startOfActivityDay...min(endOfActivityDay, Date()), displayedComponents: [.hourAndMinute])
                                    .labelsHidden()
                                    .onChange(of: startTime) { oldValue, newValue in
                                        // Ensure end time is not before start time
                                        if endTime < newValue {
                                            endTime = newValue.addingTimeInterval(1800) // Add 30 min
                                        }
                                    }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.right")
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("End Time")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                DatePicker("", selection: $endTime, in: startTime...min(endOfActivityDay, Date()), displayedComponents: [.hourAndMinute])
                                    .labelsHidden()
                            }
                        }
                        
                        // Duration display
                        let duration = Int(endTime.timeIntervalSince(startTime) / 60)
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                            Text("Duration: \(formatDuration(duration))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                } footer: {
                    Text("Select the time range when you performed this activity")
                }
                
                // Stress Level Section
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Stress Level During Activity")
                                .font(.headline)
                            Spacer()
                            Text("\(stressLevel)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(stressLevelColor)
                        }
                        
                        StressLevelSlider(value: $stressLevel)
                        
                        HStack {
                            Text("Relaxed")
                                .font(.caption)
                                .foregroundColor(.green)
                            Spacer()
                            Text("Moderate")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Spacer()
                            Text("Very Stressed")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 8)
                } footer: {
                    Text("Rate how stressed you felt during this activity (1 = very relaxed, 10 = extremely stressed)")
                }
                
                // Save Button
                Section {
                    Button(action: saveChanges) {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                            Text("Save Changes")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .disabled(activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                // Delete Button
                Section {
                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        HStack {
                            Spacer()
                            Image(systemName: "trash.fill")
                            Text("Delete Activity")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Edit Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Activity Updated!", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your activity has been updated.")
            }
            .alert("Delete Activity?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    activityManager.removeActivity(id: activity.id)
                    dismiss()
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
    
    private var stressLevelColor: Color {
        switch stressLevel {
        case 1...3: return .green
        case 4...6: return .yellow
        case 7...10: return .red
        default: return .gray
        }
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) hr"
            }
            return "\(hours) hr \(remainingMinutes) min"
        }
    }
    
    private func saveChanges() {
        let trimmedName = activityName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let updatedActivity = ActivityEntry(
            id: activity.id,
            activityType: selectedType,
            activityName: trimmedName,
            stressLevel: stressLevel,
            startTime: startTime,
            endTime: endTime
        )
        
        activityManager.updateActivity(updatedActivity)
        showingSuccessAlert = true
    }
}

// MARK: - Activity Type Row
struct ActivityTypeRow: View {
    let type: ActivityType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(type.color.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: type.icon)
                        .font(.title3)
                        .foregroundColor(type.color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(type.color)
                } else {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? type.color.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? type.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stress Level Slider
struct StressLevelSlider: View {
    @Binding var value: Int
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...10, id: \.self) { level in
                Button {
                    value = level
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(level <= value ? colorForLevel(level) : Color(.systemGray5))
                            .frame(height: 40)
                        
                        Text("\(level)")
                            .font(.caption)
                            .fontWeight(level == value ? .bold : .regular)
                            .foregroundColor(level <= value ? .white : .gray)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func colorForLevel(_ level: Int) -> Color {
        switch level {
        case 1...3: return .green
        case 4...6: return .yellow
        case 7...10: return .red
        default: return .gray
        }
    }
}

// MARK: - Activity History Card (for Dashboard)
struct ActivityHistoryCard: View {
    @ObservedObject var activityManager = ActivityManager.shared
    @State private var selectedActivityForEdit: ActivityEntry? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.clipboard.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Today's Activities")
                    .font(.headline)
                
                Spacer()
                
                if let avgStress = activityManager.todayAverageStress {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Avg Stress")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f", avgStress))
                            .font(.headline)
                            .foregroundColor(colorForStress(avgStress))
                    }
                }
            }
            
            if activityManager.todaysActivities.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "note.text.badge.plus")
                            .font(.largeTitle)
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No activities logged today")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Tap + to add an activity")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(activityManager.todaysActivities.prefix(3)) { activity in
                        ActivityRow(activity: activity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedActivityForEdit = activity
                            }
                    }
                    
                    if activityManager.todaysActivities.count > 3 {
                        Text("+ \(activityManager.todaysActivities.count - 3) more activities")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Hint for editing
            if !activityManager.todaysActivities.isEmpty {
                HStack {
                    Spacer()
                    Text("Tap an activity to edit")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .sheet(item: $selectedActivityForEdit) { activity in
            EditActivityView(activity: activity)
        }
    }
    
    private func colorForStress(_ stress: Double) -> Color {
        switch stress {
        case 0..<4: return .green
        case 4..<7: return .yellow
        default: return .red
        }
    }
}

// MARK: - Activity Row
struct ActivityRow: View {
    let activity: ActivityEntry
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(activity.activityType.color.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Image(systemName: activity.activityType.icon)
                    .font(.subheadline)
                    .foregroundColor(activity.activityType.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.activityName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    Text(activity.activityType.rawValue)
                    Text("•")
                    Text("\(timeFormatter.string(from: activity.startTime)) - \(timeFormatter.string(from: activity.endTime))")
                    Text("•")
                    Text(activity.durationString)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(activity.stressLevel)")
                        .font(.headline)
                        .foregroundColor(activity.stressColor)
                    Text("stress")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Floating Add Button
struct FloatingAddButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Preview
struct AddActivityView_Previews: PreviewProvider {
    static var previews: some View {
        AddActivityView()
    }
}
