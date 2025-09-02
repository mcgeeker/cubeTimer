import SwiftUI
import UIKit

func formatTime(_ time: TimeInterval) -> String {
    if time <= 0 {
        return "0.00"
    }

    let minutes = Int(time) / 60
    let seconds = time.truncatingRemainder(dividingBy: 60)

    if minutes > 0 {
        return String(format: "%d:%05.2f", minutes, seconds)
    } else {
        return String(format: "%.2f", seconds)
    }
}

struct UserProfile: Codable, Identifiable {
    let id = UUID()
    var name: String
    var bestTime: TimeInterval = 0
    var lastTime: TimeInterval = 0
    var solveCount: Int = 0
    var totalTime: TimeInterval = 0
    var themeColor: CodableColor = CodableColor(.purple)
    var history: [SolveRecord] = []
}

struct SolveRecord: Codable, Identifiable {
    let id = UUID()
    let time: TimeInterval
    let date: Date
    
    init(time: TimeInterval) {
        self.time = time
        self.date = Date()
    }
}

struct CodableColor: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    
    init(_ color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        red = Double(r)
        green = Double(g)
        blue = Double(b)
        alpha = Double(a)
    }
    
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

struct ContentView: View {
    @State private var currentTime: TimeInterval = 0
    @State private var isRunning = false
    @State private var isInspecting = false
    @State private var inspectionTime: TimeInterval = 15
    @State private var timer: Timer?
    @State private var startTime: Date?
    
    @State private var leftButtonPressed = false
    @State private var rightButtonPressed = false
    @State private var readyToStart = false
    @State private var showingSettings = false
    @State private var showingNewBest = false
    @State private var confettiTrigger = 0
    @State private var showingHistory = false
    @State private var showingLeaderboard = false
    
    @AppStorage("userProfiles") private var userProfilesData: Data = Data()
    @AppStorage("currentUserId") private var currentUserId: String = ""
    @State private var userProfiles: [UserProfile] = []
    @State private var currentProfile: UserProfile = UserProfile(name: "Default")
    
    var averageTime: TimeInterval {
        guard currentProfile.solveCount > 0 else { return 0 }
        return currentProfile.totalTime / Double(currentProfile.solveCount)
    }
    
    var bothButtonsPressed: Bool {
        leftButtonPressed && rightButtonPressed
    }
    
    var selectedButtonColor: Color {
        currentProfile.themeColor.color
    }
    
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width < geometry.size.height {
                // Portrait - Show rotation instruction
                VStack(spacing: 30) {
                    Spacer()
                    
                    Image(systemName: "rotate.right")
                        .font(.system(size: 80))
                        .foregroundColor(.secondary)
                    
                    Text("Rotate to landscape")
                        .font(.title)
                        .fontWeight(.semibold)
                    
                    Text("Turn your phone sideways to use the timer")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // Landscape - Show timer
                HStack(spacing: 0) {
                    // Left Button
                    Rectangle()
                        .fill(leftButtonPressed ? selectedButtonColor.opacity(0.4) : selectedButtonColor.opacity(0.15))
                        .frame(width: 120)
                        .overlay(
                            Rectangle()
                                .stroke(selectedButtonColor, lineWidth: 2)
                        )
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if !leftButtonPressed {
                                        leftButtonPressed = true
                                        handleButtonPress()
                                    }
                                }
                                .onEnded { _ in
                                    leftButtonPressed = false
                                    handleButtonRelease()
                                }
                        )
                    
                    // Center Content
                    VStack(spacing: 25) {
                        HStack {
                            Spacer()
                            Button(action: { showingSettings = true }) {
                                Image(systemName: "gearshape.fill")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Timer Display
                        VStack(spacing: 15) {
                            Text(getStatusText())
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Text(formatTime(isInspecting ? inspectionTime : currentTime))
                                .font(.system(size: 56, weight: .light, design: .monospaced))
                                .foregroundColor(getTimerColor())
                        }
                        
                        if showingNewBest {
                            Text("🎉 NEW BEST TIME! 🎉")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.yellow)
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        showingNewBest = false
                                    }
                                }
                        }
                        
                        Spacer()
                        
                        // Statistics
                        VStack(spacing: 15) {
                            Button("Statistics - \(currentProfile.name)") {
                                showingHistory = true
                            }
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            
                            Button("Leaderboard") {
                                showingLeaderboard = true
                            }
                            .font(.body)
                            .foregroundColor(.secondary)
                            
                            LazyVGrid(columns: [
                                GridColumn(.flexible()),
                                GridColumn(.flexible())
                            ], spacing: 12) {
                                StatCard(title: "Best", value: formatTime(currentProfile.bestTime), color: .green)
                                StatCard(title: "Last", value: formatTime(currentProfile.lastTime), color: .blue)
                                StatCard(title: "Average", value: formatTime(averageTime), color: .purple)
                                StatCard(title: "Solves", value: "\(currentProfile.solveCount)", color: .orange)
                            }
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    
                    // Right Button
                    Rectangle()
                        .fill(rightButtonPressed ? selectedButtonColor.opacity(0.4) : selectedButtonColor.opacity(0.15))
                        .frame(width: 120)
                        .overlay(
                            Rectangle()
                                .stroke(selectedButtonColor, lineWidth: 2)
                        )
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if !rightButtonPressed {
                                        rightButtonPressed = true
                                        handleButtonPress()
                                    }
                                }
                                .onEnded { _ in
                                    rightButtonPressed = false
                                    handleButtonRelease()
                                }
                        )
                }
                .ignoresSafeArea()
            }
        }
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.8), trigger: isRunning)
        .confettiCannon(counter: $confettiTrigger)
        .sheet(isPresented: $showingSettings) {
            SettingsView(userProfiles: $userProfiles, currentProfile: $currentProfile) {
                saveProfiles()
            }
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView(profile: currentProfile)
        }
        .sheet(isPresented: $showingLeaderboard) {
            LeaderboardView(userProfiles: userProfiles)
        }
        .onAppear {
            loadProfiles()
        }
        .onChange(of: isRunning) { oldValue, newValue in
            UIApplication.shared.isIdleTimerDisabled = newValue
        }
    }
    
    private func getStatusText() -> String {
        if isRunning {
            return "Solving..."
        } else if isInspecting {
            return "Inspection"
        } else if readyToStart {
            return "Release to start!"
        } else if bothButtonsPressed {
            return "Hold both buttons"
        } else {
            return "Place hands on both sides"
        }
    }
    
    private func getTimerColor() -> Color {
        if isInspecting {
            return inspectionTime <= 5 ? .red : .orange
        } else if isRunning {
            return .green
        } else if readyToStart {
            return .blue
        } else {
            return .primary
        }
    }
    
    private func handleButtonPress() {
        if bothButtonsPressed {
            if isRunning {
                stopSolve()
            } else if !isInspecting && !readyToStart {
                startInspection()
            }
        }
    }
    
    private func handleButtonRelease() {
        if readyToStart && (!leftButtonPressed || !rightButtonPressed) {
            startSolve()
            readyToStart = false
        }
    }
    
    private func startInspection() {
        isInspecting = true
        inspectionTime = 15
        readyToStart = false
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            inspectionTime -= 0.01
            if inspectionTime <= 0 {
                readyToStart = true
                isInspecting = false
                timer?.invalidate()
            } else if inspectionTime <= 8 && bothButtonsPressed {
                readyToStart = true
                isInspecting = false
                timer?.invalidate()
            }
        }
    }
    
    private func startSolve() {
        timer?.invalidate()
        isInspecting = false
        readyToStart = false
        isRunning = true
        currentTime = 0
        startTime = Date()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            if let start = startTime {
                currentTime = Date().timeIntervalSince(start)
            }
        }
    }
    
    private func stopSolve() {
        timer?.invalidate()
        isRunning = false
        
        let isNewBest = currentProfile.bestTime == 0 || currentTime < currentProfile.bestTime
        
        currentProfile.lastTime = currentTime
        currentProfile.totalTime += currentTime
        currentProfile.solveCount += 1
        currentProfile.history.append(SolveRecord(time: currentTime))
        
        if isNewBest {
            currentProfile.bestTime = currentTime
            showingNewBest = true
            confettiTrigger += 1
        }
        
        saveProfiles()
    }
    
    private func loadProfiles() {
        if let decoded = try? JSONDecoder().decode([UserProfile].self, from: userProfilesData) {
            userProfiles = decoded
        }
        
        if userProfiles.isEmpty {
            let defaultProfile = UserProfile(name: "Default")
            userProfiles = [defaultProfile]
            currentProfile = defaultProfile
            currentUserId = defaultProfile.id.uuidString
            saveProfiles()
        } else if !currentUserId.isEmpty, let profile = userProfiles.first(where: { $0.id.uuidString == currentUserId }) {
            currentProfile = profile
        } else {
            currentProfile = userProfiles.first!
            currentUserId = currentProfile.id.uuidString
            saveProfiles()
        }
    }
    
    private func saveProfiles() {
        if let index = userProfiles.firstIndex(where: { $0.id == currentProfile.id }) {
            userProfiles[index] = currentProfile
        }
        
        if let encoded = try? JSONEncoder().encode(userProfiles) {
            userProfilesData = encoded
        }
        currentUserId = currentProfile.id.uuidString
    }
    
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct SettingsView: View {
    @Binding var userProfiles: [UserProfile]
    @Binding var currentProfile: UserProfile
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingNewUserAlert = false
    @State private var newUserName = ""
    @State private var showingDeleteAlert = false
    @State private var selectedColor: Color = .purple
    @State private var selectedProfileId: UUID = .init()

    
    var body: some View {
        NavigationStack {
            Form {
                Section("Current User") {
                    Picker("Profile", selection: $selectedProfileId) {
                        ForEach(userProfiles) { profile in
                            Text(profile.name).tag(profile.id)
                        }
                    }
                    .onChange(of: selectedProfileId) { _, newId in
                        if let p = userProfiles.first(where: { $0.id == newId }) {
                            currentProfile = p
                            selectedColor = p.themeColor.color
                            onSave()
                        }
                    }
                }
                
                Section("User Management") {
                    Button("Add New User") {
                        showingNewUserAlert = true
                    }
                    
                    if userProfiles.count > 1 {
                        Button("Delete Current User") {
                            showingDeleteAlert = true
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Section("Theme Color") {
                    ColorPicker("Button Color", selection: $selectedColor)
                        .onChange(of: selectedColor) { _, newColor in
                            let codableColor = CodableColor(newColor)
                            if let index = userProfiles.firstIndex(where: { $0.id == currentProfile.id }) {
                                userProfiles[index].themeColor = codableColor
                                currentProfile = userProfiles[index]
                            }
                        }
                }
                
                Section("Statistics") {
                    Button("Reset Current User's Statistics") {
                        currentProfile.bestTime = 0
                        currentProfile.lastTime = 0
                        currentProfile.solveCount = 0
                        currentProfile.totalTime = 0
                        currentProfile.history = []
                        onSave()
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onSave()
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedColor = currentProfile.themeColor.color
                selectedProfileId = currentProfile.id
            }
            .onChange(of: currentProfile) { _, newProfile in
                selectedColor = newProfile.themeColor.color
                selectedProfileId = newProfile.id
            }
            .alert("New User", isPresented: $showingNewUserAlert) {
                TextField("Name", text: $newUserName)
                Button("Cancel", role: .cancel) { }
                Button("Add") {
                    if !newUserName.isEmpty {
                        let newProfile = UserProfile(name: newUserName)
                        userProfiles.append(newProfile)
                        currentProfile = newProfile
                        selectedColor = newProfile.themeColor.color
                        onSave()
                        newUserName = ""
                    }
                }
            } message: {
                Text("Enter a name for the new user profile")
            }
            .alert("Delete User", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let index = userProfiles.firstIndex(where: { $0.id == currentProfile.id }) {
                        userProfiles.remove(at: index)
                        currentProfile = userProfiles.first!
                        onSave()
                    }
                }
            } message: {
                Text("Are you sure you want to delete \(currentProfile.name)'s profile? This cannot be undone.")
            }
        }
    }
}

struct ConfettiView: View {
    @State private var animate = false
    let colors: [Color] = [.red, .green, .blue, .orange, .pink, .purple, .yellow]
    
    var body: some View {
        ZStack {
            ForEach(0..<50, id: \.self) { index in
                Rectangle()
                    .fill(colors.randomElement() ?? .blue)
                    .frame(width: 10, height: 10)
                    .rotationEffect(.degrees(animate ? 360 : 0))
                    .offset(
                        x: animate ? CGFloat.random(in: -200...200) : 0,
                        y: animate ? CGFloat.random(in: -300...300) : 0
                    )
                    .opacity(animate ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 2)) {
                animate = true
            }
        }
    }
}

struct HistoryView: View {
    let profile: UserProfile
    @Environment(\.dismiss) private var dismiss
    @State private var showingChart = false
    
    var statistics: (bestTime: TimeInterval, averageTime: TimeInterval, medianTime: TimeInterval, standardDeviation: TimeInterval) {
        let times = profile.history.map { $0.time }
        let sortedTimes = times.sorted()
        
        let bestTime = profile.bestTime
        let averageTime = times.isEmpty ? 0 : times.reduce(0, +) / Double(times.count)
        
        let medianTime: TimeInterval
        if sortedTimes.isEmpty {
            medianTime = 0
        } else if sortedTimes.count % 2 == 0 {
            let mid = sortedTimes.count / 2
            medianTime = (sortedTimes[mid - 1] + sortedTimes[mid]) / 2
        } else {
            medianTime = sortedTimes[sortedTimes.count / 2]
        }
        
        let standardDeviation: TimeInterval
        if times.count < 2 {
            standardDeviation = 0
        } else {
            let variance = times.map { pow($0 - averageTime, 2) }.reduce(0, +) / Double(times.count)
            standardDeviation = sqrt(variance)
        }
        
        return (bestTime, averageTime, medianTime, standardDeviation)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Statistics Header
                VStack(spacing: 16) {
                    Text("Statistics Summary")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if profile.history.isEmpty {
                        Text("No solves recorded yet")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        LazyVGrid(columns: [
                            GridColumn(.flexible()),
                            GridColumn(.flexible())
                        ], spacing: 12) {
                            StatCard(title: "Best", value: formatTime(statistics.bestTime), color: .green)
                            StatCard(title: "Average", value: formatTime(statistics.averageTime), color: .blue)
                            StatCard(title: "Median", value: formatTime(statistics.medianTime), color: .purple)
                            StatCard(title: "Std Dev", value: formatTime(statistics.standardDeviation), color: .orange)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                
                // History List
                List {
                    ForEach(profile.history.sorted(by: { $0.date > $1.date })) { record in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(formatTime(record.time))
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                Text(formatDate(record.date))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if record.time == profile.bestTime {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("\(profile.name)'s History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Chart") {
                        showingChart = true
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingChart) {
            ChartView(history: profile.history)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ChartView: View {
    let history: [SolveRecord]
    @Environment(\.dismiss) private var dismiss
    
    var sortedHistory: [SolveRecord] {
        history.sorted(by: { $0.date < $1.date })
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if sortedHistory.isEmpty {
                    Text("No solve history available")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            Text("Progress Over Time")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .padding()
                            
                            SimpleLineChart(data: sortedHistory.map { $0.time })
                                .frame(height: 300)
                                .padding()
                        }
                    }
                }
            }
            .navigationTitle("Progress Chart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SimpleLineChart: View {
    let data: [TimeInterval]
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width - 40
            let height = geometry.size.height - 40
            let maxValue = data.max() ?? 1
            let minValue = data.min() ?? 0
            let range = maxValue - minValue
            
            ZStack {
                // Grid lines
                ForEach(0..<5) { i in
                    let y = height * CGFloat(i) / 4
                    Path { path in
                        path.move(to: CGPoint(x: 20, y: y + 20))
                        path.addLine(to: CGPoint(x: width + 20, y: y + 20))
                    }
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                }
                
                // Line chart
                if data.count > 1 {
                    Path { path in
                        for (index, value) in data.enumerated() {
                            let x = width * CGFloat(index) / CGFloat(data.count - 1) + 20
                            let normalizedValue = range > 0 ? (maxValue - value) / range : 0.5
                            let y = height * normalizedValue + 20
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.blue, lineWidth: 2)
                    
                    // Data points
                    ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                        let x = width * CGFloat(index) / CGFloat(data.count - 1) + 20
                        let normalizedValue = range > 0 ? (maxValue - value) / range : 0.5
                        let y = height * normalizedValue + 20
                        
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                            .position(x: x, y: y)
                    }
                }
                
                // Y-axis labels
                VStack {
                    HStack {
                        Text(formatTime(maxValue))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Text(formatTime(minValue))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding(.leading, 5)
            }
        }
    }
    
}

struct LeaderboardView: View {
    let userProfiles: [UserProfile]
    @Environment(\.dismiss) private var dismiss
    
    var sortedProfiles: [UserProfile] {
        userProfiles
            .filter { $0.bestTime > 0 }
            .sorted { $0.bestTime < $1.bestTime }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(sortedProfiles.enumerated()), id: \.element.id) { index, profile in
                    HStack {
                        // Rank
                        Text("\(index + 1)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(getRankColor(index))
                            .frame(width: 30)
                        
                        // User info
                        VStack(alignment: .leading) {
                            Text(profile.name)
                                .font(.headline)
                            Text("\(profile.solveCount) solves")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Best time
                        VStack(alignment: .trailing) {
                            Text(formatTime(profile.bestTime))
                                .font(.title3)
                                .fontWeight(.semibold)
                            if profile.solveCount > 0 {
                                Text("Avg: \(formatTime(profile.totalTime / Double(profile.solveCount)))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Crown for winner
                        if index == 0 {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                if sortedProfiles.isEmpty {
                    Text("No times recorded yet")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func getRankColor(_ index: Int) -> Color {
        switch index {
        case 0: return .yellow  // Gold
        case 1: return .gray    // Silver
        case 2: return .brown   // Bronze
        default: return .primary
        }
    }
}

extension View {
    func confettiCannon(counter: Binding<Int>) -> some View {
        self.overlay(
            ZStack {
                if counter.wrappedValue > 0 {
                    ConfettiView()
                }
            }
        )
    }
}
