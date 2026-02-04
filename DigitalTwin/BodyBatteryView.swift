import SwiftUI

// MARK: - Body Battery Data Models

/// Represents a de-stress activity that can boost battery
struct DestressActivity: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let duration: Int // in minutes
    let batteryGain: Int // percentage points
    let description: String
    let color: Color
    let activityType: DestressType
    
    enum DestressType {
        case breathing
        case walking
        case meditation
        case stretching
        case hydration
    }
}

/// Represents a day's battery history
struct BatteryHistoryEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    var batteryLevel: Int
    var stressEvents: Int
    var recoveryActivities: Int
    var minBattery: Int
    var maxBattery: Int
    
    init(id: UUID = UUID(), date: Date, batteryLevel: Int, stressEvents: Int = 0, recoveryActivities: Int = 0, minBattery: Int? = nil, maxBattery: Int? = nil) {
        self.id = id
        self.date = date
        self.batteryLevel = batteryLevel
        self.stressEvents = stressEvents
        self.recoveryActivities = recoveryActivities
        self.minBattery = minBattery ?? batteryLevel
        self.maxBattery = maxBattery ?? batteryLevel
    }
}

/// Represents a completed recovery activity
struct CompletedRecoveryActivity: Identifiable, Codable {
    let id: UUID
    let activityName: String
    let completedAt: Date
    let batteryGained: Int
    var sessionMetricsId: UUID? // Optional link to saved session metrics
    
    init(id: UUID = UUID(), activityName: String, completedAt: Date = Date(), batteryGained: Int, sessionMetricsId: UUID? = nil) {
        self.id = id
        self.activityName = activityName
        self.completedAt = completedAt
        self.batteryGained = batteryGained
        self.sessionMetricsId = sessionMetricsId
    }
}

/// Saved session metrics for persistence
struct SavedSessionMetrics: Identifiable, Codable {
    let id: UUID
    let activityName: String
    let startTime: Date
    let endTime: Date
    let durationSeconds: Int
    let minHeartRate: Double?
    let maxHeartRate: Double?
    let avgHeartRate: Double?
    let rmssd: Double?
    let avgHRV: Double?
    let caloriesBurned: Double?
    let relaxationScore: Int
    
    init(from metrics: ActivitySessionMetrics) {
        self.id = metrics.id
        self.activityName = metrics.activityName
        self.startTime = metrics.startTime
        self.endTime = metrics.endTime
        self.durationSeconds = metrics.durationSeconds
        self.minHeartRate = metrics.minHeartRate
        self.maxHeartRate = metrics.maxHeartRate
        self.avgHeartRate = metrics.avgHeartRate
        self.rmssd = metrics.rmssd
        self.avgHRV = metrics.avgHRV
        self.caloriesBurned = metrics.caloriesBurned
        self.relaxationScore = metrics.relaxationScore
    }
}

/// Tracks an active recovery session in progress
struct ActiveRecoverySession {
    let activity: DestressActivity
    let startTime: Date
    
    var elapsedSeconds: Int {
        Int(Date().timeIntervalSince(startTime))
    }
}

// MARK: - Body Battery Manager

@MainActor
class BodyBatteryManager: ObservableObject {
    static let shared = BodyBatteryManager()
    
    private let batteryKey = "bodyBatteryLevel"
    private let historyKey = "batteryHistory"
    private let recoveryKey = "recoveryActivities"
    private let lastUpdateKey = "lastBatteryUpdate"
    private let sessionMetricsKey = "savedSessionMetrics"
    
    @Published var currentBattery: Int = 75
    @Published var batteryHistory: [BatteryHistoryEntry] = []
    @Published var completedRecoveryActivities: [CompletedRecoveryActivity] = []
    @Published var savedSessionMetrics: [SavedSessionMetrics] = []
    @Published var activeBreathingSession: Bool = false
    @Published var breathingTimeRemaining: Int = 0
    
    // Simulated activity in progress
    @Published var simulatedActivity: String? = nil
    @Published var simulatedBatteryChange: Int = 0
    
    // Active session tracking
    @Published var activeSession: ActiveRecoverySession? = nil
    
    let destressActivities: [DestressActivity] = [
        DestressActivity(
            name: "Deep Breathing",
            icon: "wind",
            duration: 5,
            batteryGain: 8,
            description: "5 minutes of guided breathing to calm your mind",
            color: .cyan,
            activityType: .breathing
        ),
        DestressActivity(
            name: "Take a Walk",
            icon: "figure.walk",
            duration: 15,
            batteryGain: 12,
            description: "A short walk to refresh and recharge",
            color: .green,
            activityType: .walking
        ),
        DestressActivity(
            name: "Quick Meditation",
            icon: "brain.head.profile",
            duration: 10,
            batteryGain: 10,
            description: "Clear your mind with a brief meditation",
            color: .purple,
            activityType: .meditation
        ),
        DestressActivity(
            name: "Stretch Break",
            icon: "figure.flexibility",
            duration: 5,
            batteryGain: 6,
            description: "Release tension with gentle stretches",
            color: .orange,
            activityType: .stretching
        ),
        DestressActivity(
            name: "Hydrate",
            icon: "drop.fill",
            duration: 1,
            batteryGain: 3,
            description: "Drink a glass of water",
            color: .blue,
            activityType: .hydration
        )
    ]
    
    private init() {
        loadData()
        checkForNewDay()
    }
    
    // MARK: - Active Session Management
    
    /// Starts a new recovery activity session
    func startActivitySession(for activity: DestressActivity) {
        activeSession = ActiveRecoverySession(
            activity: activity,
            startTime: Date()
        )
    }
    
    /// Ends the current activity session and saves metrics
    func endActivitySession(with metrics: ActivitySessionMetrics?) {
        guard let session = activeSession else { return }
        
        var sessionMetricsId: UUID? = nil
        
        // Save metrics if available
        if let metrics = metrics {
            let savedMetrics = SavedSessionMetrics(from: metrics)
            sessionMetricsId = savedMetrics.id
            savedSessionMetrics.insert(savedMetrics, at: 0)
            
            // Keep only last 50 sessions
            if savedSessionMetrics.count > 50 {
                savedSessionMetrics = Array(savedSessionMetrics.prefix(50))
            }
        }
        
        // Add battery gain
        currentBattery = min(100, currentBattery + session.activity.batteryGain)
        
        // Record completed activity
        let completed = CompletedRecoveryActivity(
            activityName: session.activity.name,
            batteryGained: session.activity.batteryGain,
            sessionMetricsId: sessionMetricsId
        )
        completedRecoveryActivities.insert(completed, at: 0)
        
        updateTodayHistory(recoveryEvent: true)
        activeSession = nil
        saveData()
    }
    
    /// Cancels the current activity session without saving
    func cancelActivitySession() {
        activeSession = nil
    }
    
    // MARK: - Battery Calculations
    
    /// Calculate battery drain based on stress level and duration
    func calculateBatteryDrain(stressLevel: Int, durationMinutes: Int) -> Int {
        // Higher stress = more drain per minute
        // Base drain: 0.5% per 10 minutes at stress level 1
        // Max drain: 2% per 10 minutes at stress level 10
        let drainPerTenMinutes = Double(stressLevel) * 0.2
        let totalDrain = (Double(durationMinutes) / 10.0) * drainPerTenMinutes
        return Int(ceil(totalDrain))
    }
    
    /// Apply stress to battery
    func applyStress(stressLevel: Int, durationMinutes: Int) {
        let drain = calculateBatteryDrain(stressLevel: stressLevel, durationMinutes: durationMinutes)
        currentBattery = max(5, currentBattery - drain)
        updateTodayHistory(stressEvent: true)
        saveData()
    }
    
    /// Complete a recovery activity
    func completeRecoveryActivity(_ activity: DestressActivity) {
        currentBattery = min(100, currentBattery + activity.batteryGain)
        
        let completed = CompletedRecoveryActivity(
            activityName: activity.name,
            batteryGained: activity.batteryGain
        )
        completedRecoveryActivities.insert(completed, at: 0)
        
        updateTodayHistory(recoveryEvent: true)
        saveData()
    }
    
    /// Simulate adding an activity to see impact
    func simulateActivity(name: String, stressLevel: Int, durationMinutes: Int) {
        simulatedActivity = name
        simulatedBatteryChange = -calculateBatteryDrain(stressLevel: stressLevel, durationMinutes: durationMinutes)
    }
    
    func clearSimulation() {
        simulatedActivity = nil
        simulatedBatteryChange = 0
    }
    
    // MARK: - History Management
    
    private func updateTodayHistory(stressEvent: Bool = false, recoveryEvent: Bool = false) {
        let today = Calendar.current.startOfDay(for: Date())
        
        if let index = batteryHistory.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            batteryHistory[index].batteryLevel = currentBattery
            batteryHistory[index].minBattery = min(batteryHistory[index].minBattery, currentBattery)
            batteryHistory[index].maxBattery = max(batteryHistory[index].maxBattery, currentBattery)
            if stressEvent { batteryHistory[index].stressEvents += 1 }
            if recoveryEvent { batteryHistory[index].recoveryActivities += 1 }
        } else {
            let newEntry = BatteryHistoryEntry(
                date: today,
                batteryLevel: currentBattery,
                stressEvents: stressEvent ? 1 : 0,
                recoveryActivities: recoveryEvent ? 1 : 0
            )
            batteryHistory.insert(newEntry, at: 0)
        }
        
        // Keep only last 30 days
        if batteryHistory.count > 30 {
            batteryHistory = Array(batteryHistory.prefix(30))
        }
    }
    
    private func checkForNewDay() {
        let lastUpdate = UserDefaults.standard.object(forKey: lastUpdateKey) as? Date ?? Date()
        let calendar = Calendar.current
        
        if !calendar.isDateInToday(lastUpdate) {
            // New day - apply overnight recovery
            let hoursSlept = 7.0 // Could integrate with HealthKit sleep data
            let overnightRecovery = Int(hoursSlept * 3) // ~3% per hour of sleep
            currentBattery = min(100, currentBattery + overnightRecovery)
            updateTodayHistory()
        }
        
        UserDefaults.standard.set(Date(), forKey: lastUpdateKey)
        saveData()
    }
    
    /// Get history for a specific date
    func historyForDate(_ date: Date) -> BatteryHistoryEntry? {
        batteryHistory.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    /// Get weekly average battery
    var weeklyAverageBattery: Int? {
        let weekEntries = batteryHistory.prefix(7)
        guard !weekEntries.isEmpty else { return nil }
        let total = weekEntries.reduce(0) { $0 + $1.batteryLevel }
        return total / weekEntries.count
    }
    
    // MARK: - Insights
    
    var batteryInsight: String {
        switch currentBattery {
        case 80...100:
            return "You're fully charged! Great time for challenging tasks."
        case 60..<80:
            return "Good energy levels. Pace yourself throughout the day."
        case 40..<60:
            return "Battery getting low. Consider taking a break soon."
        case 20..<40:
            return "Low energy. Time to recharge with a recovery activity."
        default:
            return "Critical! Please take immediate steps to recover."
        }
    }
    
    var recommendedActivity: DestressActivity {
        if currentBattery < 30 {
            return destressActivities.first { $0.activityType == .breathing }!
        } else if currentBattery < 50 {
            return destressActivities.first { $0.activityType == .walking }!
        } else {
            return destressActivities.first { $0.activityType == .hydration }!
        }
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        UserDefaults.standard.set(currentBattery, forKey: batteryKey)
        
        if let historyData = try? JSONEncoder().encode(batteryHistory) {
            UserDefaults.standard.set(historyData, forKey: historyKey)
        }
        
        if let recoveryData = try? JSONEncoder().encode(completedRecoveryActivities) {
            UserDefaults.standard.set(recoveryData, forKey: recoveryKey)
        }
        
        if let metricsData = try? JSONEncoder().encode(savedSessionMetrics) {
            UserDefaults.standard.set(metricsData, forKey: sessionMetricsKey)
        }
    }
    
    private func loadData() {
        currentBattery = UserDefaults.standard.integer(forKey: batteryKey)
        if currentBattery == 0 { currentBattery = 75 } // Default for new users
        
        if let historyData = UserDefaults.standard.data(forKey: historyKey),
           let history = try? JSONDecoder().decode([BatteryHistoryEntry].self, from: historyData) {
            batteryHistory = history
        }
        
        if let recoveryData = UserDefaults.standard.data(forKey: recoveryKey),
           let activities = try? JSONDecoder().decode([CompletedRecoveryActivity].self, from: recoveryData) {
            completedRecoveryActivities = activities
        }
        
        if let metricsData = UserDefaults.standard.data(forKey: sessionMetricsKey),
           let metrics = try? JSONDecoder().decode([SavedSessionMetrics].self, from: metricsData) {
            savedSessionMetrics = metrics
        }
    }
    
    /// Retrieves saved metrics for a completed activity
    func getSessionMetrics(for activityId: UUID?) -> SavedSessionMetrics? {
        guard let id = activityId else { return nil }
        return savedSessionMetrics.first { $0.id == id }
    }
}

// MARK: - Body Battery View

struct BodyBatteryView: View {
    @StateObject private var batteryManager = BodyBatteryManager.shared
    @ObservedObject private var activityManager = ActivityManager.shared
    @EnvironmentObject var healthKitManager: HealthKitManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDate = Date()
    @State private var showingActivitySimulator = false
    @State private var showingBreathingExercise = false
    @State private var showingCalendar = false
    
    var batteryColor: Color {
        switch batteryManager.currentBattery {
        case 70...100: return .green
        case 40..<70: return .yellow
        case 20..<40: return .orange
        default: return .red
        }
    }
    
    var backgroundColor: LinearGradient {
        let battery = batteryManager.currentBattery
        switch battery {
        case 70...100:
            return LinearGradient(colors: [Color.green.opacity(0.1), Color(.systemBackground)], startPoint: .top, endPoint: .bottom)
        case 40..<70:
            return LinearGradient(colors: [Color.yellow.opacity(0.1), Color(.systemBackground)], startPoint: .top, endPoint: .bottom)
        case 20..<40:
            return LinearGradient(colors: [Color.orange.opacity(0.1), Color(.systemBackground)], startPoint: .top, endPoint: .bottom)
        default:
            return LinearGradient(colors: [Color.red.opacity(0.15), Color(.systemBackground)], startPoint: .top, endPoint: .bottom)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Main Battery Display with Human Figure
                    BatteryHumanView(
                        batteryLevel: batteryManager.currentBattery,
                        simulatedChange: batteryManager.simulatedBatteryChange,
                        batteryColor: batteryColor
                    )
                    .padding(.horizontal)
                    
                    // Insight Card
                    InsightCard(
                        insight: batteryManager.batteryInsight,
                        batteryLevel: batteryManager.currentBattery
                    )
                    .padding(.horizontal)
                    
                    // Activity Impact Simulator
                    ActivityImpactCard(batteryManager: batteryManager)
                        .padding(.horizontal)
                    
                    // Calendar / History Section
                    BatteryCalendarCard(
                        batteryManager: batteryManager,
                        selectedDate: $selectedDate,
                        showingCalendar: $showingCalendar
                    )
                    .padding(.horizontal)
                    
                    // Recovery Activities Section
                    RecoveryActivitiesSection(
                        batteryManager: batteryManager,
                        showingBreathingExercise: $showingBreathingExercise
                    )
                    .padding(.horizontal)
                    
                    // Today's Activity Impact
                    TodayActivityImpactCard(
                        activities: activityManager.todaysActivities,
                        batteryManager: batteryManager
                    )
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Body Battery")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Dashboard")
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .sheet(isPresented: $showingBreathingExercise) {
            BreathingExerciseView(batteryManager: batteryManager)
        }
    }
}

// MARK: - Battery Human View

struct BatteryHumanView: View {
    let batteryLevel: Int
    let simulatedChange: Int
    let batteryColor: Color
    
    @State private var pulseAnimation = false
    @State private var fillAnimation: CGFloat = 0
    
    var displayedBattery: Int {
        max(0, min(100, batteryLevel + simulatedChange))
    }
    
    var displayColor: Color {
        if simulatedChange != 0 {
            return simulatedChange > 0 ? .green : .red
        }
        return batteryColor
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background glow
                Circle()
                    .fill(displayColor.opacity(0.2))
                    .frame(width: 220, height: 220)
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseAnimation)
                
                // Human figure outline
                ZStack {
                    // Body silhouette background
                    Image(systemName: "figure.stand")
                        .font(.system(size: 120, weight: .thin))
                        .foregroundColor(Color(.systemGray4))
                    
                    // Filled portion based on battery
                    Image(systemName: "figure.stand")
                        .font(.system(size: 120, weight: .regular))
                        .foregroundColor(displayColor)
                        .mask(
                            VStack(spacing: 0) {
                                Spacer()
                                Rectangle()
                                    .frame(height: 150 * fillAnimation)
                            }
                            .frame(height: 150)
                        )
                }
                
                // Battery percentage ring
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: CGFloat(displayedBattery) / 100.0)
                    .stroke(
                        displayColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1), value: displayedBattery)
            }
            .onAppear {
                pulseAnimation = true
                withAnimation(.easeInOut(duration: 1.5)) {
                    fillAnimation = CGFloat(batteryLevel) / 100.0
                }
            }
            .onChange(of: batteryLevel) { oldValue, newValue in
                withAnimation(.easeInOut(duration: 0.8)) {
                    fillAnimation = CGFloat(newValue) / 100.0
                }
            }
            
            // Battery percentage text
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(displayedBattery)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(displayColor)
                    Text("%")
                        .font(.title)
                        .foregroundColor(.secondary)
                }
                
                if simulatedChange != 0 {
                    HStack(spacing: 4) {
                        Image(systemName: simulatedChange > 0 ? "arrow.up" : "arrow.down")
                        Text("\(abs(simulatedChange))%")
                    }
                    .font(.caption)
                    .foregroundColor(simulatedChange > 0 ? .green : .red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        (simulatedChange > 0 ? Color.green : Color.red).opacity(0.15)
                    )
                    .cornerRadius(12)
                }
                
                Text("Body Battery")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 20)
    }
}

// MARK: - Insight Card

struct InsightCard: View {
    let insight: String
    let batteryLevel: Int
    
    var iconName: String {
        switch batteryLevel {
        case 70...100: return "bolt.fill"
        case 40..<70: return "battery.75"
        case 20..<40: return "battery.25"
        default: return "battery.0"
        }
    }
    
    var iconColor: Color {
        switch batteryLevel {
        case 70...100: return .green
        case 40..<70: return .yellow
        case 20..<40: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.title)
                .foregroundColor(iconColor)
                .frame(width: 50, height: 50)
                .background(iconColor.opacity(0.15))
                .cornerRadius(12)
            
            Text(insight)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Activity Impact Card

struct ActivityImpactCard: View {
    @ObservedObject var batteryManager: BodyBatteryManager
    
    @State private var selectedActivityType: ActivityType = .aerobic
    @State private var activityName = ""
    @State private var stressLevel: Double = 5
    @State private var duration: Double = 30
    
    var estimatedDrain: Int {
        batteryManager.calculateBatteryDrain(stressLevel: Int(stressLevel), durationMinutes: Int(duration))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .foregroundColor(.purple)
                Text("Activity Impact Simulator")
                    .font(.headline)
                Spacer()
            }
            
            Text("See how activities would affect your battery")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Activity Type Picker
            HStack(spacing: 8) {
                ForEach(ActivityType.allCases) { type in
                    Button(action: { selectedActivityType = type }) {
                        VStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .font(.title3)
                            Text(type.rawValue)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedActivityType == type
                                ? type.color.opacity(0.2)
                                : Color(.systemGray6)
                        )
                        .foregroundColor(selectedActivityType == type ? type.color : .secondary)
                        .cornerRadius(10)
                    }
                }
            }
            
            // Duration Slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Duration")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(duration)) min")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $duration, in: 15...120, step: 15)
                    .tint(.purple)
            }
            
            // Stress Level Slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Expected Stress Level")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(stressLevel))/10")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $stressLevel, in: 1...10, step: 1)
                    .tint(stressColor)
            }
            
            // Impact Preview
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimated Impact")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .foregroundColor(.red)
                        Text("\(estimatedDrain)%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        Text("battery drain")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    batteryManager.simulateActivity(
                        name: selectedActivityType.rawValue,
                        stressLevel: Int(stressLevel),
                        durationMinutes: Int(duration)
                    )
                }) {
                    Text("Preview")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.purple)
                        .cornerRadius(10)
                }
            }
            
            if batteryManager.simulatedActivity != nil {
                Button(action: { batteryManager.clearSimulation() }) {
                    Text("Clear Preview")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    var stressColor: Color {
        switch Int(stressLevel) {
        case 1...3: return .green
        case 4...6: return .yellow
        default: return .red
        }
    }
}

// MARK: - Battery Calendar Card

struct BatteryCalendarCard: View {
    @ObservedObject var batteryManager: BodyBatteryManager
    @Binding var selectedDate: Date
    @Binding var showingCalendar: Bool
    
    let calendar = Calendar.current
    
    var weekDates: [Date] {
        let today = Date()
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }.reversed()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                Text("Battery History")
                    .font(.headline)
                Spacer()
                
                Button(action: { showingCalendar.toggle() }) {
                    Text(showingCalendar ? "Week" : "Month")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if showingCalendar {
                // Month Calendar View
                CalendarGridView(
                    batteryManager: batteryManager,
                    selectedDate: $selectedDate
                )
            } else {
                // Week View
                HStack(spacing: 8) {
                    ForEach(weekDates, id: \.self) { date in
                        DayBatteryView(
                            date: date,
                            entry: batteryManager.historyForDate(date),
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate)
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                    }
                }
            }
            
            // Selected day details
            if let entry = batteryManager.historyForDate(selectedDate) {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(formattedDate(selectedDate))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 20) {
                        StatItem(title: "Battery", value: "\(entry.batteryLevel)%", icon: "battery.75", color: batteryColor(for: entry.batteryLevel))
                        StatItem(title: "Stress Events", value: "\(entry.stressEvents)", icon: "exclamationmark.triangle", color: .orange)
                        StatItem(title: "Recovery", value: "\(entry.recoveryActivities)", icon: "heart.fill", color: .green)
                    }
                    
                    if entry.minBattery != entry.maxBattery {
                        Text("Range: \(entry.minBattery)% - \(entry.maxBattery)%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("No data for \(formattedDate(selectedDate))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = calendar.isDateInToday(date) ? "'Today'" : "EEEE, MMM d"
        return formatter.string(from: date)
    }
    
    func batteryColor(for level: Int) -> Color {
        switch level {
        case 70...100: return .green
        case 40..<70: return .yellow
        case 20..<40: return .orange
        default: return .red
        }
    }
}

struct DayBatteryView: View {
    let date: Date
    let entry: BatteryHistoryEntry?
    let isSelected: Bool
    
    var dayAbbrev: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: date).prefix(1))
    }
    
    var batteryColor: Color {
        guard let level = entry?.batteryLevel else { return .gray }
        switch level {
        case 70...100: return .green
        case 40..<70: return .yellow
        case 20..<40: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Text(dayAbbrev)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            ZStack {
                Circle()
                    .fill(batteryColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                if let level = entry?.batteryLevel {
                    Circle()
                        .trim(from: 0, to: CGFloat(level) / 100.0)
                        .stroke(batteryColor, lineWidth: 3)
                        .frame(width: 32, height: 32)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(level)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(batteryColor)
                } else {
                    Text("--")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(isSelected ? Color(.systemGray5) : Color.clear)
        .cornerRadius(10)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Calendar Grid View

struct CalendarGridView: View {
    @ObservedObject var batteryManager: BodyBatteryManager
    @Binding var selectedDate: Date
    
    let calendar = Calendar.current
    @State private var currentMonth = Date()
    
    var monthDates: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }
        
        var dates: [Date] = []
        var currentDate = monthFirstWeek.start
        
        while dates.count < 42 { // 6 weeks max
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return dates
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Month Navigation
            HStack {
                Button(action: { moveMonth(-1) }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(monthYearString)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(action: { moveMonth(1) }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                }
            }
            
            // Day headers
            HStack(spacing: 0) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(monthDates, id: \.self) { date in
                    CalendarDayCell(
                        date: date,
                        currentMonth: currentMonth,
                        entry: batteryManager.historyForDate(date),
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate)
                    )
                    .onTapGesture {
                        selectedDate = date
                    }
                }
            }
        }
    }
    
    var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
    
    func moveMonth(_ offset: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: offset, to: currentMonth) {
            currentMonth = newMonth
        }
    }
}

struct CalendarDayCell: View {
    let date: Date
    let currentMonth: Date
    let entry: BatteryHistoryEntry?
    let isSelected: Bool
    
    let calendar = Calendar.current
    
    var isCurrentMonth: Bool {
        calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
    }
    
    var batteryColor: Color {
        guard let level = entry?.batteryLevel else { return .clear }
        switch level {
        case 70...100: return .green
        case 40..<70: return .yellow
        case 20..<40: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(Color.blue.opacity(0.2))
            }
            
            if entry != nil {
                Circle()
                    .fill(batteryColor.opacity(0.3))
                    .frame(width: 28, height: 28)
            }
            
            Text("\(calendar.component(.day, from: date))")
                .font(.caption)
                .foregroundColor(isCurrentMonth ? .primary : .secondary.opacity(0.5))
        }
        .frame(height: 32)
    }
}

// MARK: - Recovery Activities Section

struct RecoveryActivitiesSection: View {
    @ObservedObject var batteryManager: BodyBatteryManager
    @Binding var showingBreathingExercise: Bool
    @State private var selectedActivity: DestressActivity? = nil
    @State private var showingActivitySession = false
    @State private var showingWalkSession = false
    @State private var showingMeditationSession = false
    @State private var showingStretchSession = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.green)
                Text("Recharge Your Battery")
                    .font(.headline)
                Spacer()
            }
            
            Text("Complete these activities to boost your energy")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(batteryManager.destressActivities) { activity in
                        RecoveryActivityCard(
                            activity: activity,
                            onTap: {
                                switch activity.activityType {
                                case .breathing:
                                    showingBreathingExercise = true
                                case .walking:
                                    showingWalkSession = true
                                case .meditation:
                                    showingMeditationSession = true
                                case .stretching:
                                    showingStretchSession = true
                                case .hydration:
                                    // Hydrate is quick - just mark as complete
                                    batteryManager.completeRecoveryActivity(activity)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
            
            // Recently completed
            if !batteryManager.completedRecoveryActivities.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Recovery")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(batteryManager.completedRecoveryActivities.prefix(3)) { activity in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(activity.activityName)
                                .font(.caption)
                            Spacer()
                            
                            if activity.sessionMetricsId != nil {
                                Image(systemName: "heart.text.square")
                                    .foregroundColor(.pink)
                                    .font(.caption)
                            }
                            
                            Text("+\(activity.batteryGained)%")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .sheet(isPresented: $showingWalkSession) {
            if let activity = batteryManager.destressActivities.first(where: { $0.activityType == .walking }) {
                ActivitySessionView(activity: activity, batteryManager: batteryManager)
            }
        }
        .sheet(isPresented: $showingMeditationSession) {
            if let activity = batteryManager.destressActivities.first(where: { $0.activityType == .meditation }) {
                ActivitySessionView(activity: activity, batteryManager: batteryManager)
            }
        }
        .sheet(isPresented: $showingStretchSession) {
            if let activity = batteryManager.destressActivities.first(where: { $0.activityType == .stretching }) {
                ActivitySessionView(activity: activity, batteryManager: batteryManager)
            }
        }
    }
}

struct RecoveryActivityCard: View {
    let activity: DestressActivity
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: activity.icon)
                    .font(.title)
                    .foregroundColor(activity.color)
                    .frame(width: 50, height: 50)
                    .background(activity.color.opacity(0.15))
                    .cornerRadius(12)
                
                VStack(spacing: 4) {
                    Text(activity.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("\(activity.duration) min")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text("+\(activity.batteryGain)%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(8)
            }
            .frame(width: 100)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Today's Activity Impact Card

struct TodayActivityImpactCard: View {
    let activities: [ActivityEntry]
    let batteryManager: BodyBatteryManager
    
    var totalDrain: Int {
        activities.reduce(0) { total, activity in
            total + batteryManager.calculateBatteryDrain(
                stressLevel: activity.stressLevel,
                durationMinutes: activity.durationMinutes
            )
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(.orange)
                Text("Today's Stress Impact")
                    .font(.headline)
                Spacer()
                
                Text("-\(totalDrain)%")
                    .font(.headline)
                    .foregroundColor(.red)
            }
            
            if activities.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                    Text("No stressful activities logged today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(activities.prefix(5)) { activity in
                    HStack {
                        Image(systemName: activity.activityType.icon)
                            .foregroundColor(activity.activityType.color)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activity.activityName)
                                .font(.subheadline)
                            Text("\(activity.durationString) • Stress: \(activity.stressLevel)/10")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        let drain = batteryManager.calculateBatteryDrain(
                            stressLevel: activity.stressLevel,
                            durationMinutes: activity.durationMinutes
                        )
                        Text("-\(drain)%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Activity Session View

/// A view that guides users through a timed recovery activity while recording physiological metrics
struct ActivitySessionView: View {
    let activity: DestressActivity
    @ObservedObject var batteryManager: BodyBatteryManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var sessionState: SessionState = .ready
    @State private var secondsElapsed: Int = 0
    @State private var timer: Timer?
    @State private var startTime: Date?
    @State private var sessionMetrics: ActivitySessionMetrics?
    @State private var pulseAnimation = false
    @State private var isLoadingMetrics = false
    
    enum SessionState {
        case ready
        case inProgress
        case completing
        case showingResults
    }
    
    var targetDurationSeconds: Int {
        activity.duration * 60
    }
    
    var progress: Double {
        min(1.0, Double(secondsElapsed) / Double(targetDurationSeconds))
    }
    
    var formattedTime: String {
        let minutes = secondsElapsed / 60
        let seconds = secondsElapsed % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var targetTime: String {
        let minutes = targetDurationSeconds / 60
        return "\(minutes):00"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dynamic background based on activity type
                activityGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Activity progress visualization
                    ZStack {
                        // Outer pulse ring
                        Circle()
                            .fill(activity.color.opacity(0.1))
                            .frame(width: 280, height: 280)
                            .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseAnimation)
                        
                        // Progress ring background
                        Circle()
                            .stroke(activity.color.opacity(0.2), lineWidth: 12)
                            .frame(width: 220, height: 220)
                        
                        // Progress ring
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(activity.color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .frame(width: 220, height: 220)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: progress)
                        
                        // Center content
                        VStack(spacing: 8) {
                            Image(systemName: activity.icon)
                                .font(.system(size: 50))
                                .foregroundColor(activity.color)
                            
                            if sessionState == .inProgress {
                                Text(formattedTime)
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text("/ \(targetTime)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else if sessionState == .ready {
                                Text(activity.name)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                            } else if sessionState == .completing {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("Analyzing...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Recording indicator
                    if sessionState == .inProgress {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                                .opacity(pulseAnimation ? 1.0 : 0.5)
                            Text("Recording physiological data...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                    
                    // Instructions
                    VStack(spacing: 8) {
                        Text(instructionTitle)
                            .font(.headline)
                        Text(instructionText)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    // Control buttons
                    VStack(spacing: 16) {
                        Button(action: handlePrimaryAction) {
                            Text(primaryButtonText)
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(activity.color)
                                .cornerRadius(16)
                        }
                        .disabled(sessionState == .completing)
                        
                        if sessionState == .inProgress {
                            Button(action: { endSessionEarly() }) {
                                Text("End Early")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(activity.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancelSession()
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { sessionState == .showingResults && sessionMetrics != nil },
                set: { if !$0 { dismiss() } }
            )) {
                if let metrics = sessionMetrics {
                    SessionMetricsSummaryView(
                        metrics: metrics,
                        activity: activity,
                        batteryManager: batteryManager
                    )
                }
            }
        }
        .onAppear {
            pulseAnimation = true
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    var activityGradient: LinearGradient {
        LinearGradient(
            colors: [activity.color.opacity(0.2), activity.color.opacity(0.05), Color(.systemBackground)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var instructionTitle: String {
        switch sessionState {
        case .ready:
            return "Ready to begin?"
        case .inProgress:
            return activityGuideTitle
        case .completing:
            return "Great job!"
        case .showingResults:
            return "Session Complete"
        }
    }
    
    var instructionText: String {
        switch sessionState {
        case .ready:
            return activity.description
        case .inProgress:
            return activityGuideText
        case .completing:
            return "Analyzing your physiological response..."
        case .showingResults:
            return "View your session metrics"
        }
    }
    
    var activityGuideTitle: String {
        switch activity.activityType {
        case .walking:
            return "Keep walking"
        case .meditation:
            return "Stay focused"
        case .stretching:
            return "Breathe and stretch"
        default:
            return "Keep going"
        }
    }
    
    var activityGuideText: String {
        switch activity.activityType {
        case .walking:
            return "Maintain a comfortable pace. Focus on your breathing and surroundings."
        case .meditation:
            return "Clear your mind. Focus on your breath and let thoughts pass by."
        case .stretching:
            return "Move slowly through each stretch. Hold each position for 15-30 seconds."
        default:
            return activity.description
        }
    }
    
    var primaryButtonText: String {
        switch sessionState {
        case .ready:
            return "Start \(activity.name)"
        case .inProgress:
            return "Complete Activity"
        case .completing:
            return "Analyzing..."
        case .showingResults:
            return "View Results"
        }
    }
    
    func handlePrimaryAction() {
        switch sessionState {
        case .ready:
            startSession()
        case .inProgress:
            completeSession()
        case .showingResults:
            dismiss()
        default:
            break
        }
    }
    
    func startSession() {
        startTime = Date()
        sessionState = .inProgress
        batteryManager.startActivitySession(for: activity)
        
        // Start workout session for high-frequency HR monitoring
        Task {
            await healthKitManager.startWorkoutSession()
        }
        
        // Start the timer
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            secondsElapsed += 1
            
            // Auto-complete when target duration is reached
            if secondsElapsed >= targetDurationSeconds {
                completeSession()
            }
        }
    }
    
    func completeSession() {
        timer?.invalidate()
        timer = nil
        sessionState = .completing
        
        guard let start = startTime else {
            dismiss()
            return
        }
        
        let endTime = Date()
        
        // End workout session and fetch metrics from HealthKit
        Task {
            // End workout session first
            await healthKitManager.endWorkoutSession()
            
            // Wait for Apple Watch data to sync to iPhone
            // HealthKit data from Watch can take 2-5 seconds to appear on iPhone
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            
            let metrics = await healthKitManager.fetchActivitySessionMetrics(
                activityName: activity.name,
                from: start,
                to: endTime
            )
            
            await MainActor.run {
                self.sessionMetrics = metrics
                batteryManager.endActivitySession(with: metrics)
                sessionState = .showingResults
            }
        }
    }
    
    func endSessionEarly() {
        // End the session even if not at target duration
        completeSession()
    }
    
    func cancelSession() {
        timer?.invalidate()
        timer = nil
        batteryManager.cancelActivitySession()
        
        // End workout session
        Task {
            await healthKitManager.endWorkoutSession()
        }
        
        dismiss()
    }
}

// MARK: - Session Metrics Summary View

/// Displays the recorded physiological metrics after completing a recovery activity
struct SessionMetricsSummaryView: View {
    let metrics: ActivitySessionMetrics
    let activity: DestressActivity
    @ObservedObject var batteryManager: BodyBatteryManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Success header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.2))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                        }
                        
                        Text("Session Complete!")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(activity.name)
                            .font(.headline)
                            .foregroundColor(activity.color)
                        
                        HStack(spacing: 20) {
                            VStack {
                                Text(metrics.formattedDuration)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                Text("Duration")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                                .frame(height: 40)
                            
                            VStack {
                                Text("+\(activity.batteryGain)%")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                                Text("Battery Gained")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(.top, 20)
                    
                    // Show appropriate content based on data availability
                    if metrics.hasAnyData {
                        // Relaxation Score Card (only show if we have HR data)
                        if metrics.hasHeartRateData {
                            relaxationScoreCard
                        }
                        
                        // Heart Rate Metrics Card
                        heartRateCard
                        
                        // HRV Metrics Card (only if we have data)
                        if metrics.rmssd != nil || metrics.avgHRV != nil {
                            hrvCard
                        }
                        
                        // Additional Metrics Card (if available)
                        if metrics.caloriesBurned != nil || metrics.respiratoryRate != nil {
                            additionalMetricsCard
                        }
                    } else {
                        // No data available - show helpful message
                        limitedDataCard
                    }
                    
                    // Done button
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(activity.color)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Session Results")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Limited Data Card
    
    private var limitedDataCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "applewatch.side.right")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("Limited Data Available")
                .font(.headline)
            
            Text("Your Apple Watch didn't record enough heart rate samples during this session.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 12) {
                tipRow(icon: "applewatch", text: "Make sure your Apple Watch is worn snugly")
                tipRow(icon: "hand.raised", text: "Keep your wrist still during the exercise")
                tipRow(icon: "clock", text: "Sessions of 2+ minutes provide more data")
                tipRow(icon: "arrow.clockwise", text: "Try opening the Heart Rate app on your Watch before starting")
            }
            .font(.caption)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Relaxation Score Card
    
    private var relaxationScoreCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("Relaxation Analysis")
                    .font(.headline)
                Spacer()
            }
            
            ZStack {
                Circle()
                    .stroke(Color.purple.opacity(0.2), lineWidth: 10)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: Double(metrics.relaxationScore) / 100.0)
                    .stroke(Color.purple, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text("\(metrics.relaxationScore)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.purple)
                    Text(metrics.relaxationLevel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            
            Text("Based on your heart rate patterns and HRV during the session")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
    
    // MARK: - Heart Rate Card
    
    private var heartRateCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("Heart Rate Metrics")
                    .font(.headline)
                Spacer()
            }
            
            if metrics.hasHeartRateData {
                HStack(spacing: 16) {
                    MetricBox(
                        title: "Min",
                        value: metrics.minHeartRate != nil ? "\(Int(metrics.minHeartRate!))" : "--",
                        unit: "BPM",
                        icon: "arrow.down",
                        color: .green
                    )
                    
                    MetricBox(
                        title: "Avg",
                        value: metrics.avgHeartRate != nil ? "\(Int(metrics.avgHeartRate!))" : "--",
                        unit: "BPM",
                        icon: "heart.fill",
                        color: .red
                    )
                    
                    MetricBox(
                        title: "Max",
                        value: metrics.maxHeartRate != nil ? "\(Int(metrics.maxHeartRate!))" : "--",
                        unit: "BPM",
                        icon: "arrow.up",
                        color: .orange
                    )
                }
                
                Text("\(metrics.heartRateSamples.count) measurements recorded")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                HStack {
                    Image(systemName: "waveform.slash")
                        .foregroundColor(.secondary)
                    Text("No heart rate data recorded")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
    
    // MARK: - HRV Card
    
    private var hrvCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.pink)
                Text("Heart Rate Variability (HRV)")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 16) {
                if metrics.rmssd != nil {
                    VStack(spacing: 8) {
                        Text("RMSSD")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(metrics.heartRateVariability)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.pink)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.pink.opacity(0.1))
                    .cornerRadius(12)
                }
                
                if let avgHRV = metrics.avgHRV {
                    VStack(spacing: 8) {
                        Text("Avg SDNN")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f ms", avgHRV))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            // HRV interpretation
            VStack(alignment: .leading, spacing: 8) {
                Text("What this means:")
                    .font(.caption)
                    .fontWeight(.medium)
                Text(metrics.hrvInterpretation)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
    
    // MARK: - Additional Metrics Card
    
    private var additionalMetricsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("Additional Metrics")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 16) {
                if let calories = metrics.caloriesBurned {
                    VStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text(String(format: "%.1f", calories))
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("kcal burned")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
                
                if let respRate = metrics.respiratoryRate {
                    VStack(spacing: 8) {
                        Image(systemName: "lungs.fill")
                            .foregroundColor(.cyan)
                        Text(String(format: "%.0f", respRate))
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("breaths/min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.cyan.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
}

// MARK: - Metric Box Component

struct MetricBox: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Breathing Exercise View

struct BreathingExerciseView: View {
    @ObservedObject var batteryManager: BodyBatteryManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var breathPhase: BreathPhase = .ready
    @State private var circleScale: CGFloat = 1.0
    @State private var secondsRemaining: Int = 300 // 5 minutes
    @State private var currentCycle = 0
    @State private var timer: Timer?
    @State private var breathTimer: Timer?
    @State private var startTime: Date?
    @State private var sessionMetrics: ActivitySessionMetrics?
    @State private var showingMetrics = false
    
    enum BreathPhase: String {
        case ready = "Get Ready"
        case inhale = "Breathe In"
        case hold = "Hold"
        case exhale = "Breathe Out"
        case completing = "Analyzing..."
        case complete = "Complete!"
    }
    
    var breathingActivity: DestressActivity? {
        batteryManager.destressActivities.first { $0.activityType == .breathing }
    }
    
    var formattedTime: String {
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [.cyan.opacity(0.3), .blue.opacity(0.2), .purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Recording indicator
                    if breathPhase != .ready && breathPhase != .complete && breathPhase != .completing {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("Recording heart data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(20)
                    }
                    
                    // Breathing circle
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.2))
                            .frame(width: 250, height: 250)
                            .scaleEffect(circleScale)
                        
                        Circle()
                            .stroke(Color.cyan, lineWidth: 4)
                            .frame(width: 200, height: 200)
                            .scaleEffect(circleScale)
                        
                        VStack(spacing: 8) {
                            if breathPhase == .completing {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .padding(.bottom, 8)
                            }
                            
                            Text(breathPhase.rawValue)
                                .font(.title)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            if breathPhase != .ready && breathPhase != .complete && breathPhase != .completing {
                                Text(formattedTime)
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundColor(.cyan)
                            }
                        }
                    }
                    
                    // Cycle counter
                    if breathPhase != .ready && breathPhase != .complete && breathPhase != .completing {
                        Text("Cycle \(currentCycle + 1)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Instructions
                    VStack(spacing: 8) {
                        Text(instructionText)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    // Control Button
                    Button(action: handleButtonTap) {
                        Text(buttonText)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.cyan)
                            .cornerRadius(16)
                    }
                    .disabled(breathPhase == .completing)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Deep Breathing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        stopExercise()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingMetrics) {
                if let metrics = sessionMetrics, let activity = breathingActivity {
                    SessionMetricsSummaryView(
                        metrics: metrics,
                        activity: activity,
                        batteryManager: batteryManager
                    )
                }
            }
            .onChange(of: showingMetrics) { _, newValue in
                if !newValue && breathPhase == .complete {
                    dismiss()
                }
            }
        }
        .onDisappear {
            stopExercise()
        }
    }
    
    var instructionText: String {
        switch breathPhase {
        case .ready:
            return "Take a moment to find a comfortable position. When you're ready, tap Start."
        case .inhale:
            return "Slowly breathe in through your nose"
        case .hold:
            return "Gently hold your breath"
        case .exhale:
            return "Slowly release through your mouth"
        case .completing:
            return "Analyzing your physiological response..."
        case .complete:
            return "Great job! You've completed the breathing exercise."
        }
    }
    
    var buttonText: String {
        switch breathPhase {
        case .ready: return "Start Breathing"
        case .completing: return "Analyzing..."
        case .complete: return "View Results"
        default: return "End & View Results"
        }
    }
    
    func handleButtonTap() {
        switch breathPhase {
        case .ready:
            startExercise()
        case .complete:
            showingMetrics = true
        case .completing:
            break
        default:
            completeExercise()
        }
    }
    
    func startExercise() {
        startTime = Date()
        breathPhase = .inhale
        currentCycle = 0
        
        // Start session tracking
        if let activity = breathingActivity {
            batteryManager.startActivitySession(for: activity)
        }
        
        // Start workout session for high-frequency HR monitoring
        Task {
            await healthKitManager.startWorkoutSession()
        }
        
        animateBreath()
        
        // Main countdown timer
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if secondsRemaining > 0 {
                secondsRemaining -= 1
            } else {
                completeExercise()
            }
        }
    }
    
    func animateBreath() {
        // 4-7-8 breathing pattern
        breathPhase = .inhale
        withAnimation(.easeInOut(duration: 4)) {
            circleScale = 1.5
        }
        
        breathTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { _ in
            breathPhase = .hold
            
            breathTimer = Timer.scheduledTimer(withTimeInterval: 7, repeats: false) { _ in
                breathPhase = .exhale
                withAnimation(.easeInOut(duration: 8)) {
                    circleScale = 1.0
                }
                
                breathTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { _ in
                    currentCycle += 1
                    if secondsRemaining > 0 {
                        animateBreath()
                    }
                }
            }
        }
    }
    
    func stopExercise() {
        timer?.invalidate()
        timer = nil
        breathTimer?.invalidate()
        breathTimer = nil
        batteryManager.cancelActivitySession()
        
        // End workout session
        Task {
            await healthKitManager.endWorkoutSession()
        }
        
        breathPhase = .ready
        secondsRemaining = 300
        circleScale = 1.0
    }
    
    func completeExercise() {
        timer?.invalidate()
        timer = nil
        breathTimer?.invalidate()
        breathTimer = nil
        breathPhase = .completing
        
        guard let start = startTime else {
            breathPhase = .complete
            showingMetrics = true
            return
        }
        
        let endTime = Date()
        
        // End workout session and fetch metrics from HealthKit
        Task {
            // End workout session first
            await healthKitManager.endWorkoutSession()
            
            // Wait for Apple Watch data to sync to iPhone
            // HealthKit data from Watch can take 2-5 seconds to appear on iPhone
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            
            let metrics = await healthKitManager.fetchActivitySessionMetrics(
                activityName: "Deep Breathing",
                from: start,
                to: endTime
            )
            
            await MainActor.run {
                self.sessionMetrics = metrics
                batteryManager.endActivitySession(with: metrics)
                breathPhase = .complete
                withAnimation(.spring()) {
                    circleScale = 1.2
                }
                showingMetrics = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BodyBatteryView()
        .environmentObject(HealthKitManager())
}
