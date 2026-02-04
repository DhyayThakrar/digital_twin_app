import Foundation
import HealthKit
import Combine

// MARK: - Data Models
struct DailySteps: Identifiable {
    let id = UUID()
    let date: Date
    let steps: Double
    
    var dayAbbreviation: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: date).prefix(1))
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
}

// MARK: - Activity Session Metrics
/// Metrics recorded during a recharge activity session (breathing, walking, meditation, stretching)
struct ActivitySessionMetrics: Identifiable {
    let id = UUID()
    let activityName: String
    let startTime: Date
    let endTime: Date
    let durationSeconds: Int
    
    // Heart Rate Metrics
    let heartRateSamples: [HeartRateSample]
    let minHeartRate: Double?
    let maxHeartRate: Double?
    let avgHeartRate: Double?
    
    // Heart Rate Variability Metrics
    let hrvSamples: [HRVSample]
    let rmssd: Double? // Root Mean Square of Successive Differences
    let avgHRV: Double?
    
    // Additional Metrics
    let caloriesBurned: Double?
    let respiratoryRate: Double?
    
    var heartRateRange: String {
        guard let min = minHeartRate, let max = maxHeartRate else { return "N/A" }
        return "\(Int(min)) - \(Int(max)) BPM"
    }
    
    var formattedDuration: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
    
    var heartRateVariability: String {
        guard let rmssd = rmssd else { return "N/A" }
        return String(format: "%.1f ms", rmssd)
    }
    
    /// Interprets the HRV reading
    var hrvInterpretation: String {
        guard let rmssd = rmssd else { return "Not enough data" }
        switch rmssd {
        case 0..<20:
            return "Low variability - indicates higher stress"
        case 20..<40:
            return "Moderate variability - normal stress levels"
        case 40..<60:
            return "Good variability - relaxed state"
        default:
            return "Excellent variability - very relaxed"
        }
    }
    
    /// Overall relaxation score based on metrics
    var relaxationScore: Int {
        var score = 50 // Base score
        
        // Add points for good HRV
        if let rmssd = rmssd {
            if rmssd > 50 { score += 25 }
            else if rmssd > 30 { score += 15 }
            else if rmssd > 20 { score += 5 }
        }
        
        // Add points for heart rate reduction during activity
        if let samples = heartRateSamples.count > 2 ? heartRateSamples : nil {
            let firstHalf = Array(samples.prefix(samples.count / 2))
            let secondHalf = Array(samples.suffix(samples.count / 2))
            
            let firstAvg = firstHalf.map { $0.bpm }.reduce(0, +) / Double(firstHalf.count)
            let secondAvg = secondHalf.map { $0.bpm }.reduce(0, +) / Double(secondHalf.count)
            
            if secondAvg < firstAvg {
                score += Int((firstAvg - secondAvg) * 2)
            }
        }
        
        return min(100, max(0, score))
    }
    
    var relaxationLevel: String {
        switch relaxationScore {
        case 80...100: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Moderate"
        default: return "Developing"
        }
    }
    
    /// Whether this session has any meaningful heart rate data
    var hasHeartRateData: Bool {
        return !heartRateSamples.isEmpty
    }
    
    /// Whether this session has any data at all
    var hasAnyData: Bool {
        return hasHeartRateData || !hrvSamples.isEmpty || (caloriesBurned ?? 0) > 0
    }
}

struct HeartRateSample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let bpm: Double
}

struct HRVSample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let sdnn: Double // Standard deviation of NN intervals (ms)
}

// MARK: - HealthKit Manager
@MainActor
class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    
    @Published var isAuthorized = false
    @Published var authorizationStatus = "Not connected"
    
    @Published var latestHeartRate: Double?
    @Published var restingHeartRate: Double?
    @Published var latestHRV: Double?
    @Published var todaySteps: Double?
    @Published var activeCalories: Double?
    @Published var todayDistance: Double?
    @Published var lastNightSleep: Double?
    @Published var weeklySteps: [DailySteps] = []
    
    private let typesToRead: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        let quantityTypes: [HKQuantityTypeIdentifier] = [
            .stepCount, .activeEnergyBurned, .distanceWalkingRunning,
            .heartRate, .restingHeartRate, .heartRateVariabilitySDNN,
            .bodyMass, .height, .appleExerciseTime, .respiratoryRate
        ]
        for id in quantityTypes {
            if let type = HKObjectType.quantityType(forIdentifier: id) {
                types.insert(type)
            }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        types.insert(HKObjectType.workoutType())
        return types
    }()
    
    private let typesToWrite: Set<HKSampleType> = {
        var types = Set<HKSampleType>()
        types.insert(HKObjectType.workoutType())
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        return types
    }()
    
    // Workout session for high-frequency HR monitoring
    private var workoutBuilder: HKWorkoutBuilder?
    
    init() {
        checkAuthorizationStatus()
    }
    
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    func checkAuthorizationStatus() {
        guard isHealthKitAvailable else {
            authorizationStatus = "HealthKit not available"
            isAuthorized = false
            return
        }
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }
        let status = healthStore.authorizationStatus(for: stepType)
        switch status {
        case .sharingAuthorized:
            authorizationStatus = "Connected"
            isAuthorized = true
        case .sharingDenied:
            authorizationStatus = "Access denied"
            isAuthorized = false
        case .notDetermined:
            authorizationStatus = "Not connected"
            isAuthorized = false
        @unknown default:
            authorizationStatus = "Unknown"
            isAuthorized = false
        }
    }
    
    func requestAuthorization() {
        guard isHealthKitAvailable else {
            authorizationStatus = "HealthKit not available"
            return
        }
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { [weak self] success, error in
            Task { @MainActor in
                if success {
                    self?.isAuthorized = true
                    self?.authorizationStatus = "Connected"
                    await self?.refreshAllData()
                } else {
                    self?.isAuthorized = false
                    self?.authorizationStatus = error?.localizedDescription ?? "Authorization failed"
                }
            }
        }
    }
    
    func refreshAllData() async {
        async let steps = fetchTodaySteps()
        async let calories = fetchActiveCalories()
        async let distance = fetchTodayDistance()
        async let heartRate = fetchLatestHeartRate()
        async let restingHR = fetchRestingHeartRate()
        async let hrv = fetchLatestHRV()
        async let sleep = fetchLastNightSleep()
        async let weekly = fetchWeeklySteps()
        
        todaySteps = await steps
        activeCalories = await calories
        todayDistance = await distance
        latestHeartRate = await heartRate
        restingHeartRate = await restingHR
        latestHRV = await hrv
        lastNightSleep = await sleep
        weeklySteps = await weekly
    }
    
    private func fetchTodaySteps() async -> Double? {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let steps = result?.sumQuantity()?.doubleValue(for: .count())
                continuation.resume(returning: steps)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchActiveCalories() async -> Double? {
        guard let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return nil }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: calorieType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let calories = result?.sumQuantity()?.doubleValue(for: .kilocalorie())
                continuation.resume(returning: calories)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchTodayDistance() async -> Double? {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return nil }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: distanceType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let distance = result?.sumQuantity()?.doubleValue(for: .meter())
                continuation.resume(returning: distance)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchLatestHeartRate() async -> Double? {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                let heartRate = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: HKUnit(from: "count/min"))
                continuation.resume(returning: heartRate)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchRestingHeartRate() async -> Double? {
        guard let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: restingHRType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                let heartRate = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: HKUnit(from: "count/min"))
                continuation.resume(returning: heartRate)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchLatestHRV() async -> Double? {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: hrvType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                let hrv = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: .secondUnit(with: .milli))
                continuation.resume(returning: hrv)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchLastNightSleep() async -> Double? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let calendar = Calendar.current
        let now = Date()
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return nil }
        let startOfYesterday = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday)!
        let endOfSleep = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfYesterday, end: endOfSleep, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }
                let asleepSamples = samples.filter { sample in
                    let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
                    return value == .asleepCore || value == .asleepDeep || value == .asleepREM || value == .asleep
                }
                let totalSeconds = asleepSamples.reduce(0.0) { total, sample in
                    total + sample.endDate.timeIntervalSince(sample.startDate)
                }
                let hours = totalSeconds / 3600.0
                continuation.resume(returning: hours > 0 ? hours : nil)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchWeeklySteps() async -> [DailySteps] {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [] }
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: startOfToday) else { return [] }
        var interval = DateComponents()
        interval.day = 1
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: nil,
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, _ in
                var dailySteps: [DailySteps] = []
                results?.enumerateStatistics(from: startDate, to: now) { statistics, _ in
                    let steps = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    dailySteps.append(DailySteps(date: statistics.startDate, steps: steps))
                }
                continuation.resume(returning: dailySteps)
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Workout Session for High-Frequency HR Monitoring
    
    /// Starts a workout session to enable high-frequency heart rate sampling from Apple Watch.
    /// During a workout session, the Watch samples HR every 5-6 seconds instead of every 5-10 minutes.
    func startWorkoutSession() async {
        guard isHealthKitAvailable else { return }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .mindAndBody
        configuration.locationType = .indoor
        
        do {
            workoutBuilder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
            try await workoutBuilder?.beginCollection(at: Date())
            print("✅ Started workout session for high-frequency HR monitoring")
        } catch {
            print("⚠️ Could not start workout session: \(error.localizedDescription)")
            // Continue anyway - we'll still try to get passive HR data
        }
    }
    
    /// Ends the current workout session and saves it to HealthKit
    func endWorkoutSession() async {
        guard let builder = workoutBuilder else { return }
        
        do {
            try await builder.endCollection(at: Date())
            let workout = try await builder.finishWorkout()
            print("✅ Ended workout session: \(workout?.duration ?? 0) seconds")
        } catch {
            print("⚠️ Could not end workout session: \(error.localizedDescription)")
        }
        
        workoutBuilder = nil
    }
    
    // MARK: - Activity Session Metrics Methods
    
    /// Fetches all heart rate samples within a given time range
    /// Uses expanded time window to catch samples that may have slightly offset timestamps
    func fetchHeartRateSamples(from startDate: Date, to endDate: Date) async -> [HeartRateSample] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return [] }
        
        // Expand the time window slightly to catch samples that might have offset timestamps
        // Apple Watch samples sometimes have timestamps slightly before/after the actual session
        let expandedStart = startDate.addingTimeInterval(-30) // 30 seconds before
        let expandedEnd = endDate.addingTimeInterval(30) // 30 seconds after
        
        let predicate = HKQuery.predicateForSamples(withStart: expandedStart, end: expandedEnd, options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                let heartRateSamples = (samples as? [HKQuantitySample])?.map { sample in
                    HeartRateSample(
                        timestamp: sample.startDate,
                        bpm: sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    )
                } ?? []
                continuation.resume(returning: heartRateSamples)
            }
            healthStore.execute(query)
        }
    }
    
    /// Fetches HRV samples within a given time range
    /// Uses expanded time window to catch samples that may have slightly offset timestamps
    func fetchHRVSamples(from startDate: Date, to endDate: Date) async -> [HRVSample] {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return [] }
        
        // Expand the time window to catch HRV samples which are calculated less frequently
        let expandedStart = startDate.addingTimeInterval(-60) // 1 minute before
        let expandedEnd = endDate.addingTimeInterval(60) // 1 minute after
        
        let predicate = HKQuery.predicateForSamples(withStart: expandedStart, end: expandedEnd, options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                let hrvSamples = (samples as? [HKQuantitySample])?.map { sample in
                    HRVSample(
                        timestamp: sample.startDate,
                        sdnn: sample.quantity.doubleValue(for: .secondUnit(with: .milli))
                    )
                } ?? []
                continuation.resume(returning: hrvSamples)
            }
            healthStore.execute(query)
        }
    }
    
    /// Fetches active calories burned within a given time range
    func fetchCaloriesBurned(from startDate: Date, to endDate: Date) async -> Double? {
        guard let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: calorieType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let calories = result?.sumQuantity()?.doubleValue(for: .kilocalorie())
                continuation.resume(returning: calories)
            }
            healthStore.execute(query)
        }
    }
    
    /// Fetches respiratory rate (if available) within a given time range
    func fetchRespiratoryRate(from startDate: Date, to endDate: Date) async -> Double? {
        guard let respType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: respType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                let rate = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: HKUnit(from: "count/min"))
                continuation.resume(returning: rate)
            }
            healthStore.execute(query)
        }
    }
    
    /// Calculates RMSSD (Root Mean Square of Successive Differences) from heart rate samples
    /// RMSSD is a key HRV metric that reflects parasympathetic (rest & recovery) nervous system activity
    func calculateRMSSD(from heartRateSamples: [HeartRateSample]) -> Double? {
        guard heartRateSamples.count >= 3 else { return nil }
        
        // Convert heart rates to RR intervals (in ms)
        let rrIntervals = heartRateSamples.map { 60000.0 / $0.bpm }
        
        // Calculate successive differences
        var squaredDifferences: [Double] = []
        for i in 1..<rrIntervals.count {
            let diff = rrIntervals[i] - rrIntervals[i - 1]
            squaredDifferences.append(diff * diff)
        }
        
        guard !squaredDifferences.isEmpty else { return nil }
        
        // Calculate mean of squared differences
        let meanSquaredDiff = squaredDifferences.reduce(0, +) / Double(squaredDifferences.count)
        
        // Return square root (RMSSD)
        return sqrt(meanSquaredDiff)
    }
    
    /// Fetches complete activity session metrics for a given time period
    /// Includes retry logic to handle Apple Watch data sync delays
    func fetchActivitySessionMetrics(activityName: String, from startDate: Date, to endDate: Date, retryCount: Int = 0) async -> ActivitySessionMetrics {
        // Fetch all data concurrently
        async let heartRateSamples = fetchHeartRateSamples(from: startDate, to: endDate)
        async let hrvSamples = fetchHRVSamples(from: startDate, to: endDate)
        async let calories = fetchCaloriesBurned(from: startDate, to: endDate)
        async let respiratoryRate = fetchRespiratoryRate(from: startDate, to: endDate)
        
        let hrSamples = await heartRateSamples
        let hrvData = await hrvSamples
        
        // If no heart rate data found and we haven't exhausted retries, wait and try again
        // This handles the delay in Apple Watch data syncing to iPhone
        if hrSamples.isEmpty && retryCount < 3 {
            print("⏳ No heart rate data found, retrying in 2 seconds... (attempt \(retryCount + 1)/3)")
            try? await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds
            return await fetchActivitySessionMetrics(activityName: activityName, from: startDate, to: endDate, retryCount: retryCount + 1)
        }
        
        // Calculate heart rate statistics
        let minHR = hrSamples.map { $0.bpm }.min()
        let maxHR = hrSamples.map { $0.bpm }.max()
        let avgHR = hrSamples.isEmpty ? nil : hrSamples.map { $0.bpm }.reduce(0, +) / Double(hrSamples.count)
        
        // Calculate HRV statistics
        let rmssd = calculateRMSSD(from: hrSamples)
        let avgHRV = hrvData.isEmpty ? nil : hrvData.map { $0.sdnn }.reduce(0, +) / Double(hrvData.count)
        
        let duration = Int(endDate.timeIntervalSince(startDate))
        
        return ActivitySessionMetrics(
            activityName: activityName,
            startTime: startDate,
            endTime: endDate,
            durationSeconds: duration,
            heartRateSamples: hrSamples,
            minHeartRate: minHR,
            maxHeartRate: maxHR,
            avgHeartRate: avgHR,
            hrvSamples: hrvData,
            rmssd: rmssd,
            avgHRV: avgHRV,
            caloriesBurned: await calories,
            respiratoryRate: await respiratoryRate
        )
    }
}
