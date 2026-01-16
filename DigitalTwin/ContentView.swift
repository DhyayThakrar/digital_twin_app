import SwiftUI

struct ContentView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    
    var body: some View {
        Group {
            if !healthKitManager.isAuthorized {
                OnboardingView()
            } else {
                DashboardView()
            }
        }
        .environmentObject(healthKitManager)
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var heartScale: CGFloat = 1.0
    @State private var heartOpacity: Double = 0.8
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 180, height: 180)
                        .scaleEffect(heartScale)
                        .opacity(heartOpacity)
                    
                    Circle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 140, height: 140)
                        .scaleEffect(heartScale * 0.9)
                    
                    Image(systemName: "heart.fill")
                        .font(.system(size: 70))
                        .foregroundColor(.red)
                        .scaleEffect(heartScale)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        heartScale = 1.15
                        heartOpacity = 0.4
                    }
                }
                
                VStack(spacing: 16) {
                    Text("Digital Twin")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    
                    Text("Your personal health companion")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text("Connect your health data to get personalized insights, track trends, and understand your daily wellness patterns.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                }
                
                Spacer()
                
                Button(action: {
                    healthKitManager.requestAuthorization()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.title2)
                        Text("Connect Apple Health")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [.red, .red.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                
                Text("Works with any wearable synced to Apple Health")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Dashboard View
struct DashboardView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var heartScale: CGFloat = 1.0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Insights & Forecast Section at the top
                    InsightsAndForecastCard(
                        hrv: healthKitManager.latestHRV,
                        sleepHours: healthKitManager.lastNightSleep,
                        todaySteps: healthKitManager.todaySteps,
                        weeklySteps: healthKitManager.weeklySteps,
                        restingHR: healthKitManager.restingHeartRate
                    )
                    .padding(.horizontal)
                    
                    HeartRateCard(
                        heartRate: healthKitManager.latestHeartRate,
                        heartScale: $heartScale
                    )
                    .onAppear { startHeartAnimation() }
                    
                    HStack(spacing: 12) {
                        QuickStatCard(
                            icon: "figure.walk",
                            title: "Steps",
                            value: formatNumber(healthKitManager.todaySteps),
                            color: .green
                        )
                        
                        QuickStatCard(
                            icon: "flame.fill",
                            title: "Calories",
                            value: formatNumber(healthKitManager.activeCalories),
                            unit: "kcal",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)
                    
                    HRVCard(hrv: healthKitManager.latestHRV)
                        .padding(.horizontal)
                    
                    SleepCard(sleepHours: healthKitManager.lastNightSleep)
                        .padding(.horizontal)
                    
                    ActivitySummaryCard(
                        distance: healthKitManager.todayDistance,
                        restingHR: healthKitManager.restingHeartRate
                    )
                    .padding(.horizontal)
                    
                    WeeklyInsightsCard(weeklyData: healthKitManager.weeklySteps)
                        .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
                .padding(.top)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await healthKitManager.refreshAllData()
            }
        }
        .onAppear {
            Task { await healthKitManager.refreshAllData() }
        }
    }
    
    private func startHeartAnimation() {
        let bpm = healthKitManager.latestHeartRate ?? 72
        let interval = 60.0 / bpm
        withAnimation(.easeInOut(duration: interval / 2).repeatForever(autoreverses: true)) {
            heartScale = 1.2
        }
    }
    
    private func formatNumber(_ value: Double?) -> String {
        guard let value = value else { return "--" }
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        }
        return String(format: "%.0f", value)
    }
}

// MARK: - Heart Rate Card
struct HeartRateCard: View {
    let heartRate: Double?
    @Binding var heartScale: CGFloat
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Heart Rate")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(heartRate != nil ? String(format: "%.0f", heartRate!) : "--")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Text("BPM")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(getHeartRateStatus())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 80, height: 80)
                        .scaleEffect(heartScale)
                    
                    Image(systemName: "heart.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.red)
                        .scaleEffect(heartScale)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
    
    private func getHeartRateStatus() -> String {
        guard let hr = heartRate else { return "No recent data" }
        if hr < 60 { return "Below resting range" }
        if hr <= 100 { return "Normal resting range" }
        return "Elevated"
    }
}

// MARK: - Quick Stat Card
struct QuickStatCard: View {
    let icon: String
    let title: String
    let value: String
    var unit: String = ""
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - HRV Card
struct HRVCard: View {
    let hrv: Double?
    
    var stressLevel: (text: String, color: Color, description: String) {
        guard let hrv = hrv else {
            return ("--", .gray, "No HRV data available")
        }
        if hrv >= 50 {
            return ("Low Stress", .green, "Your body is well recovered")
        } else if hrv >= 30 {
            return ("Moderate", .yellow, "Consider taking some rest")
        } else {
            return ("High Stress", .red, "Your body needs recovery time")
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stress Level")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(stressLevel.text)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(stressLevel.color)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("HRV")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(hrv != nil ? String(format: "%.0f", hrv!) : "--")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("ms")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.green, .yellow, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: getStressBarWidth(geometry.size.width), height: 8)
                }
            }
            .frame(height: 8)
            
            Text(stressLevel.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    private func getStressBarWidth(_ totalWidth: CGFloat) -> CGFloat {
        guard let hrv = hrv else { return 0 }
        let stressPercent = max(0, min(1, (100 - hrv) / 100))
        return totalWidth * stressPercent
    }
}

// MARK: - Sleep Card
struct SleepCard: View {
    let sleepHours: Double?
    
    var sleepQuality: (text: String, color: Color) {
        guard let hours = sleepHours else { return ("No data", .gray) }
        if hours >= 7 { return ("Great", .green) }
        else if hours >= 6 { return ("Fair", .yellow) }
        else { return ("Needs improvement", .red) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "moon.fill")
                    .font(.title2)
                    .foregroundColor(.indigo)
                
                Text("Last Night's Sleep")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(sleepQuality.text)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(sleepQuality.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(sleepQuality.color.opacity(0.15))
                    .cornerRadius(8)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(sleepHours != nil ? String(format: "%.1f", sleepHours!) : "--")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("hours")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            if let hours = sleepHours, hours < 7 {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text("Try to get 7-9 hours for optimal recovery")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Activity Summary Card
struct ActivitySummaryCard: View {
    let distance: Double?
    let restingHR: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity Summary")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.run")
                            .foregroundColor(.blue)
                        Text("Distance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(distance != nil ? String(format: "%.1f", distance! / 1000) : "--")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                        Text("km")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider().frame(height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                            .foregroundColor(.pink)
                        Text("Resting HR")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(restingHR != nil ? String(format: "%.0f", restingHR!) : "--")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                        Text("bpm")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Weekly Insights Card
struct WeeklyInsightsCard: View {
    let weeklyData: [DailySteps]
    
    var maxSteps: Double {
        weeklyData.map { $0.steps }.max() ?? 10000
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("This Week")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let average = averageSteps {
                    Text("Avg: \(Int(average)) steps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(weeklyData, id: \.date) { day in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(day.isToday ? Color.green : Color.green.opacity(0.4))
                            .frame(width: 32, height: getBarHeight(for: day.steps))
                        
                        Text(day.dayAbbreviation)
                            .font(.caption2)
                            .foregroundColor(day.isToday ? .primary : .secondary)
                    }
                }
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            
            if let insight = getWeeklyInsight() {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text(insight)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    private var averageSteps: Double? {
        guard !weeklyData.isEmpty else { return nil }
        let total = weeklyData.reduce(0) { $0 + $1.steps }
        return total / Double(weeklyData.count)
    }
    
    private func getBarHeight(for steps: Double) -> CGFloat {
        let minHeight: CGFloat = 10
        let maxHeight: CGFloat = 100
        guard maxSteps > 0 else { return minHeight }
        return max(minHeight, (steps / maxSteps) * maxHeight)
    }
    
    private func getWeeklyInsight() -> String? {
        guard weeklyData.count >= 2 else { return nil }
        
        let recentDays = weeklyData.suffix(3)
        let earlierDays = weeklyData.prefix(3)
        
        let recentAvg = recentDays.reduce(0) { $0 + $1.steps } / Double(recentDays.count)
        let earlierAvg = earlierDays.reduce(0) { $0 + $1.steps } / Double(earlierDays.count)
        
        if recentAvg > earlierAvg * 1.1 {
            return "Activity trending up! Keep it going."
        } else if recentAvg < earlierAvg * 0.9 {
            return "Activity slightly down. Try a short walk today!"
        }
        return "Consistent activity this week."
    }
}

// MARK: - Insights & Forecast Card
struct InsightsAndForecastCard: View {
    let hrv: Double?
    let sleepHours: Double?
    let todaySteps: Double?
    let weeklySteps: [DailySteps]
    let restingHR: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                Text("Insights & Forecast")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Divider()
            
            // Lifestyle Recommendations
            VStack(alignment: .leading, spacing: 12) {
                Text("LIFESTYLE RECOMMENDATIONS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                ForEach(getLifestyleRecommendations(), id: \.title) { recommendation in
                    RecommendationRow(
                        icon: recommendation.icon,
                        iconColor: recommendation.color,
                        title: recommendation.title,
                        description: recommendation.description,
                        priority: recommendation.priority
                    )
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Health Forecast
            VStack(alignment: .leading, spacing: 12) {
                Text("7-DAY FORECAST")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                ForEach(getHealthForecasts(), id: \.title) { forecast in
                    ForecastRow(
                        icon: forecast.icon,
                        iconColor: forecast.color,
                        title: forecast.title,
                        prediction: forecast.prediction,
                        trend: forecast.trend
                    )
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.05), Color.blue.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Recommendation Logic
    
    struct Recommendation {
        let icon: String
        let color: Color
        let title: String
        let description: String
        let priority: Priority
        
        enum Priority {
            case high, medium, low
        }
    }
    
    private func getLifestyleRecommendations() -> [Recommendation] {
        var recommendations: [Recommendation] = []
        
        // Sleep-based recommendations
        if let sleep = sleepHours {
            if sleep < 6 {
                recommendations.append(Recommendation(
                    icon: "bed.double.fill",
                    color: .red,
                    title: "Prioritize Sleep Tonight",
                    description: "You got \(String(format: "%.1f", sleep))h last night. Aim for 7-9 hours to improve recovery and reduce stress.",
                    priority: .high
                ))
            } else if sleep < 7 {
                recommendations.append(Recommendation(
                    icon: "moon.stars.fill",
                    color: .yellow,
                    title: "Slightly More Sleep Needed",
                    description: "Try going to bed 30 minutes earlier. Consistent sleep improves HRV and energy levels.",
                    priority: .medium
                ))
            }
        }
        
        // HRV/Stress-based recommendations
        if let hrv = hrv {
            if hrv < 30 {
                recommendations.append(Recommendation(
                    icon: "figure.mind.and.body",
                    color: .red,
                    title: "High Stress Detected",
                    description: "Consider a rest day, meditation, or light stretching. Avoid intense workouts today.",
                    priority: .high
                ))
            } else if hrv < 50 {
                recommendations.append(Recommendation(
                    icon: "leaf.fill",
                    color: .yellow,
                    title: "Manage Your Stress",
                    description: "Take short breaks during work. A 10-minute walk or breathing exercises can help.",
                    priority: .medium
                ))
            }
        }
        
        // Activity-based recommendations
        if let steps = todaySteps {
            if steps < 3000 {
                recommendations.append(Recommendation(
                    icon: "figure.walk",
                    color: .orange,
                    title: "Get Moving",
                    description: "Only \(Int(steps)) steps so far. A 15-minute walk adds ~1,500 steps and boosts mood.",
                    priority: .medium
                ))
            }
        }
        
        // Weekly trend-based recommendations
        if weeklySteps.count >= 5 {
            let avgSteps = weeklySteps.reduce(0) { $0 + $1.steps } / Double(weeklySteps.count)
            if avgSteps < 5000 {
                recommendations.append(Recommendation(
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue,
                    title: "Increase Daily Activity",
                    description: "Weekly average is \(Int(avgSteps)) steps. Gradually increase to 8,000+ for better cardiovascular health.",
                    priority: .medium
                ))
            }
        }
        
        // If everything looks good
        if recommendations.isEmpty {
            recommendations.append(Recommendation(
                icon: "checkmark.seal.fill",
                color: .green,
                title: "Great Job!",
                description: "Your health metrics look balanced. Keep up your current routine!",
                priority: .low
            ))
        }
        
        return Array(recommendations.prefix(3)) // Limit to 3 recommendations
    }
    
    // MARK: - Forecast Logic
    
    struct Forecast {
        let icon: String
        let color: Color
        let title: String
        let prediction: String
        let trend: TrendDirection
        
        enum TrendDirection {
            case up, down, stable
        }
    }
    
    private func getHealthForecasts() -> [Forecast] {
        var forecasts: [Forecast] = []
        
        // Stress forecast based on current HRV trend
        if let hrv = hrv {
            let stressForecast: Forecast
            if hrv >= 50 {
                stressForecast = Forecast(
                    icon: "brain.head.profile",
                    color: .green,
                    title: "Stress Level",
                    prediction: "Expected to remain low if sleep stays consistent",
                    trend: .stable
                )
            } else if hrv >= 30 {
                stressForecast = Forecast(
                    icon: "brain.head.profile",
                    color: .yellow,
                    title: "Stress Level",
                    prediction: "May increase without adequate rest and recovery",
                    trend: .up
                )
            } else {
                stressForecast = Forecast(
                    icon: "brain.head.profile",
                    color: .red,
                    title: "Stress Level",
                    prediction: "Likely to stay elevated. Prioritize rest this week.",
                    trend: .up
                )
            }
            forecasts.append(stressForecast)
        }
        
        // Activity forecast based on weekly trend
        if weeklySteps.count >= 3 {
            let recentDays = weeklySteps.suffix(3)
            let earlierDays = weeklySteps.prefix(3)
            let recentAvg = recentDays.reduce(0) { $0 + $1.steps } / Double(recentDays.count)
            let earlierAvg = earlierDays.reduce(0) { $0 + $1.steps } / Double(max(earlierDays.count, 1))
            
            let activityForecast: Forecast
            if recentAvg > earlierAvg * 1.1 {
                activityForecast = Forecast(
                    icon: "figure.run",
                    color: .green,
                    title: "Activity Trend",
                    prediction: "On track to exceed weekly goals. Momentum building!",
                    trend: .up
                )
            } else if recentAvg < earlierAvg * 0.9 {
                activityForecast = Forecast(
                    icon: "figure.run",
                    color: .orange,
                    title: "Activity Trend",
                    prediction: "Declining activity. May miss weekly target without change.",
                    trend: .down
                )
            } else {
                activityForecast = Forecast(
                    icon: "figure.run",
                    color: .blue,
                    title: "Activity Trend",
                    prediction: "Steady pace. Maintaining current activity levels.",
                    trend: .stable
                )
            }
            forecasts.append(activityForecast)
        }
        
        // Recovery forecast based on sleep + HRV
        if let sleep = sleepHours {
            let recoveryForecast: Forecast
            let goodSleep = sleep >= 7
            let goodHRV = (hrv ?? 40) >= 40
            
            if goodSleep && goodHRV {
                recoveryForecast = Forecast(
                    icon: "battery.100",
                    color: .green,
                    title: "Recovery Outlook",
                    prediction: "Excellent recovery expected. Ready for higher intensity.",
                    trend: .up
                )
            } else if goodSleep || goodHRV {
                recoveryForecast = Forecast(
                    icon: "battery.50",
                    color: .yellow,
                    title: "Recovery Outlook",
                    prediction: "Moderate recovery. Consider balanced activity levels.",
                    trend: .stable
                )
            } else {
                recoveryForecast = Forecast(
                    icon: "battery.25",
                    color: .red,
                    title: "Recovery Outlook",
                    prediction: "Recovery may be slow. Focus on rest and nutrition.",
                    trend: .down
                )
            }
            forecasts.append(recoveryForecast)
        }
        
        return forecasts
    }
}

// MARK: - Recommendation Row
struct RecommendationRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let priority: InsightsAndForecastCard.Recommendation.Priority
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if priority == .high {
                        Text("Priority")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(iconColor)
                            .cornerRadius(4)
                    }
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Forecast Row
struct ForecastRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let prediction: String
    let trend: InsightsAndForecastCard.Forecast.TrendDirection
    
    var trendIcon: String {
        switch trend {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }
    
    var trendColor: Color {
        switch trend {
        case .up: return title.contains("Stress") ? .red : .green
        case .down: return title.contains("Stress") ? .green : .orange
        case .stable: return .blue
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Image(systemName: trendIcon)
                        .font(.caption)
                        .foregroundColor(trendColor)
                }
                
                Text(prediction)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthKitManager())
}
