# Digital Twin iOS App

Your personal health companion that transforms raw health data into clear, actionable insights.

## Vision

Digital Twin connects to Apple Health to give you a comprehensive view of your daily wellness. Whether you use an Apple Watch, Fitbit, Garmin, or any other wearable that syncs with Apple Health, Digital Twin provides:

- **Real-time health insights** from your wearable data
- **Stress tracking** based on Heart Rate Variability (HRV)
- **Sleep quality analysis** with recommendations
- **Activity trends** with weekly comparisons
- **Future: Stress predictions** and lifestyle recommendations

## Features

- ✅ Beautiful minimalistic dashboard
- ✅ Animated heart rate display synced to your BPM
- ✅ HRV-based stress level indicator
- ✅ Sleep tracking with quality insights
- ✅ Weekly activity trends with bar charts
- ✅ Pull-to-refresh for latest data
- ✅ Works with ANY wearable synced to Apple Health
- ✅ Dark mode support

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Apple Developer Account (for deployment)
- Real iOS device (HealthKit doesn't work on Simulator)

## Setup Instructions

### 1. Open the Project
```bash
open DigitalTwin.xcodeproj
```

### 2. Configure Signing
1. Open the project in Xcode
2. Select the "DigitalTwin" target
3. Go to "Signing & Capabilities" tab
4. Select your Development Team
5. Xcode will automatically manage signing

### 3. Add HealthKit Capability (if not automatically added)
1. In Xcode, select the project in the navigator
2. Select the "DigitalTwin" target
3. Go to "Signing & Capabilities" tab
4. Click "+ Capability"
5. Search for "HealthKit" and add it

### 4. Run the App
- Select a simulator or connected device
- Press ⌘+R or click the Play button

## HealthKit Data Access

The app requests access to the following health data:

**Read Access:**
- Step Count
- Active Energy Burned
- Walking/Running Distance
- Heart Rate
- Resting Heart Rate
- Heart Rate Variability (HRV)
- Sleep Analysis
- Body Mass (Weight)
- Height
- Workouts

**Write Access:**
- Step Count (for demo purposes)

## Project Structure

```
DigitalTwin/
├── DigitalTwinApp.swift      # App entry point
├── ContentView.swift          # Main UI with dashboard components
├── HealthKitManager.swift     # HealthKit data fetching & management
├── Assets.xcassets/           # App icons and colors
├── Info.plist                 # App configuration with HealthKit permissions
└── DigitalTwin.entitlements   # HealthKit entitlements
```

## Dashboard Components

| Component | Description |
|-----------|-------------|
| **Heart Rate Card** | Animated heart synced to BPM with status indicator |
| **Quick Stats** | Steps and calories burned today |
| **Stress Level** | HRV-based stress indicator with visual bar |
| **Sleep Card** | Last night's sleep with quality assessment |
| **Activity Summary** | Distance traveled and resting heart rate |
| **Weekly Insights** | 7-day step trend with activity analysis |

## Health Data Access

The app reads the following from Apple Health:

- Step Count
- Active Energy Burned  
- Walking/Running Distance
- Heart Rate
- Resting Heart Rate
- Heart Rate Variability (HRV)
- Sleep Analysis
- Body Mass & Height
- Workouts

## Roadmap

### Phase 1 (Current) ✅
- Basic health data visualization
- Real-time data from Apple Health
- Stress level based on HRV thresholds
- Weekly activity trends

### Phase 2 (Planned)
- [ ] Stress score predictions using ML
- [ ] Trend forecasting (next 7 days)
- [ ] Time-of-day stress patterns
- [ ] Personalized lifestyle recommendations

### Phase 3 (Future)
- [ ] Historical trend analysis
- [ ] Anomaly detection
- [ ] Integration with calendar for stress correlation
- [ ] Export reports

## Deployment Checklist

1. [ ] Set your Development Team in Xcode
2. [ ] Update Bundle Identifier (e.g., `com.yourcompany.digitaltwin`)
3. [ ] Add App Icon (1024x1024 PNG)
4. [ ] Test on real device
5. [ ] Archive and upload to App Store Connect

## License

MIT License
