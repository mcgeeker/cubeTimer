import SwiftUI

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

struct UserProfile: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var bestTime: TimeInterval = 0
    var lastTime: TimeInterval = 0
    var solveCount: Int = 0
    var totalTime: TimeInterval = 0
    var themeColor: CodableColor = CodableColor(.purple)
    var history: [SolveRecord] = []
}

struct SolveRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    let time: TimeInterval
    let date: Date
    
    init(time: TimeInterval) {
        self.time = time
        self.date = Date()
    }
}

enum Penalty: Codable, Equatable {
    case none, plus2, dnf
}

struct CodableColor: Codable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    
    init(_ color: Color) {
        if let cgColor = color.cgColor,
           let components = cgColor.components {
            if components.count >= 3 {
                red = Double(components[0])
                green = Double(components[1])
                blue = Double(components[2])
                alpha = components.count >= 4 ? Double(components[3]) : 1.0
            } else if components.count == 2 {
                red = Double(components[0])
                green = Double(components[0])
                blue = Double(components[0])
                alpha = Double(components[1])
            } else {
                red = 0
                green = 0
                blue = 0
                alpha = 1
            }
        } else {
            red = 0
            green = 0
            blue = 0
            alpha = 1
        }
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
    @State private var inspectionStartMonotonic: TimeInterval?
    @State private var pendingPenalty: Penalty = .none
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
    @State private var showingFirstUserAlert = false
    @State private var newUserName = ""

    @AppStorage("userProfiles") private var userProfilesData: Data = Data()
    @AppStorage("currentUserId") private var currentUserId: String = ""
    @State private var userProfiles: [UserProfile] = []
    @State private var currentProfile: UserProfile = UserProfile(name: "")
    
    var averageTime: TimeInterval {
        guard currentProfile.solveCount > 0 else { return 0 }
        return currentProfile.totalTime / Double(currentProfile.solveCount)
    }
    
    // MARK: - Rolling averages
    var ao5: TimeInterval? { rollingAoN(currentProfile.history, N: 5) }
    var ao12: TimeInterval? { rollingAoN(currentProfile.history, N: 12) }

    /// WCA-style rolling average over last N solves using *displayed* times (your stored SolveRecord.time).
    /// Drops single best and single worst; if any non-finite remains in the middle, AoN is DNF (nil).
    private func rollingAoN(_ records: [SolveRecord], N: Int) -> TimeInterval? {
        guard records.count >= N else { return nil }
        let lastN = records.suffix(N).map { $0.time } // displayedTime == stored time
        // Sort finite before non-finite so Infinity (DNF) sits at the end
        let sorted = lastN.sorted { (a, b) in
            if a.isFinite != b.isFinite { return a.isFinite }
            return a < b
        }
        let middle = sorted.dropFirst().dropLast()
        if middle.contains(where: { !$0.isFinite }) { return nil }
        let sum = middle.reduce(0, +)
        return sum / Double(middle.count)
    }

    private func formatTimeOptional(_ t: TimeInterval?) -> String {
        guard let t = t else { return "—" }
        return formatTime(t)
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
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                StatCard(title: "Best", value: formatTime(currentProfile.bestTime), color: .green)
                                StatCard(title: "Last", value: formatTime(currentProfile.lastTime), color: .blue)
                                StatCard(title: "Average", value: formatTime(averageTime), color: .purple)
                                StatCard(title: "Solves", value: "\(currentProfile.solveCount)", color: .orange)
                                StatCard(title: "Ao5", value: formatTimeOptional(ao5), color: .teal)
                                StatCard(title: "Ao12", value: formatTimeOptional(ao12), color: .indigo)
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
            }
        }
        .ignoresSafeArea()
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
        .alert("New User", isPresented: $showingFirstUserAlert, actions: firstUserAlert) {
            Text("Enter a name for your profile")
        }
        .onAppear {
            loadProfiles()
        }
    }
    
    private func getStatusText() -> String {
        if isRunning { return "Solving..." }
        if isInspecting {
            // Show penalty hints during inspection window
            let overrun = max(0, 15 - inspectionTime)
            if pendingPenalty == .dnf { return "Inspection — DNF (≥17s)" }
            if overrun > 0 { return "Inspection — +2 if started now" }
            return "Inspection"
        }
        if pendingPenalty == .dnf { return "DNF — over inspection (≥17s)" }
        if readyToStart { return "Release to start!" }
        if bothButtonsPressed { return "Hold both buttons" }
        return "Place hands on both sides"
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
            // If inspecting, startInspection's timer loop will handle transitioning to ready when both are pressed.
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
        readyToStart = false
        pendingPenalty = .none

        inspectionStartMonotonic = CACurrentMediaTime()
        // We display a countdown toward 15.00; compute from monotonic "now" to avoid drift.
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            guard let start = inspectionStartMonotonic else { return }
            let elapsed = CACurrentMediaTime() - start
            // Show remaining time down toward 0 at 15s, then clamp at 0
            let remaining = 15.0 - elapsed
            inspectionTime = max(0, remaining)

            // Determine current penalty state based on elapsed
            if elapsed >= 17.0 {
                pendingPenalty = .dnf
                isInspecting = false
                readyToStart = false
                timer?.invalidate()
                return
            } else if elapsed >= 15.0 {
                pendingPenalty = .plus2
            } else {
                pendingPenalty = .none
            }

            // Transition to "ready" only when BOTH pads are currently pressed (no arbitrary 8s rule)
            if bothButtonsPressed {
                isInspecting = false
                // If already DNF we won't allow start; otherwise allow ready-to-release start.
                if pendingPenalty != .dnf {
                    readyToStart = true
                }
                timer?.invalidate()
            }
        }
        // Small tolerance helps power without affecting display cadence
        timer?.tolerance = 0.003
    }
    
    private func startSolve() {
        // Do not start if inspection exceeded 17s (DNF)
        if pendingPenalty == .dnf {
            // Reset readiness; user must re-start a new inspection
            readyToStart = false
            isInspecting = false
            return
        }
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

        // Apply WCA +2 if pending
        let finalTime = currentTime + (pendingPenalty == .plus2 ? 2.0 : 0.0)
        let isNewBest = currentProfile.bestTime == 0 || finalTime < currentProfile.bestTime

        currentProfile.lastTime = finalTime
        currentProfile.totalTime += finalTime
        currentProfile.solveCount += 1
        currentProfile.history.append(SolveRecord(time: finalTime))

        if isNewBest {
            currentProfile.bestTime = finalTime
            showingNewBest = true
            confettiTrigger += 1
        }

        // Reset penalty state for the next attempt
        pendingPenalty = .none

        saveProfiles()
    }
    
    private func loadProfiles() {
        if let decoded = try? JSONDecoder().decode([UserProfile].self, from: userProfilesData) {
            userProfiles = decoded
        }
        
        if userProfiles.isEmpty {
            showingFirstUserAlert = true
        } else if !currentUserId.isEmpty, let profile = userProfiles.first(where: { $0.id.uuidString == currentUserId }) {
            currentProfile = profile
        } else {
            currentProfile = userProfiles.first!
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

    @ViewBuilder
    private func firstUserAlert() -> some View {
        TextField("Name", text: $newUserName)
        Button("Create") {
            if !newUserName.trimmingCharacters(in: .whitespaces).isEmpty {
                let newProfile = UserProfile(name: newUserName)
                userProfiles = [newProfile]
                currentProfile = newProfile
                saveProfiles()
                newUserName = ""
            } else {
                showingFirstUserAlert = true
            }
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
            settingsForm
        }
    }

    private var settingsForm: some View {
        Form {
            currentUserSection
            userManagementSection
            themeColorSection
            statisticsSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear { setInitialSelections() }
        .onChange(of: currentProfile) { _, newProfile in
            updateSelections(with: newProfile)
        }
        .alert("New User", isPresented: $showingNewUserAlert, actions: newUserAlert) {
            Text("Enter a name for the new user profile")
        }
        .alert("Delete User", isPresented: $showingDeleteAlert, actions: deleteUserAlert) {
            Text("Are you sure you want to delete \(currentProfile.name)'s profile? This cannot be undone.")
        }
    }

    private var currentUserSection: some View {
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
    }

    private var userManagementSection: some View {
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
    }

    private var themeColorSection: some View {
        Section("Theme Color") {
            ColorPicker("Button Color", selection: $selectedColor)
                .onChange(of: selectedColor) { _, newColor in
                    let codableColor = CodableColor(newColor)
                    if let index = userProfiles.firstIndex(where: { $0.id == currentProfile.id }) {
                        userProfiles[index].themeColor = codableColor
                        currentProfile = userProfiles[index]
                        onSave()
                    }
                }
        }
    }

    private var statisticsSection: some View {
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Done") {
                onSave()
                dismiss()
            }
        }
    }

    private func setInitialSelections() {
        selectedColor = currentProfile.themeColor.color
        selectedProfileId = currentProfile.id
    }

    private func updateSelections(with profile: UserProfile) {
        selectedColor = profile.themeColor.color
        selectedProfileId = profile.id
    }

    @ViewBuilder
    private func newUserAlert() -> some View {
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
    }

    @ViewBuilder
    private func deleteUserAlert() -> some View {
        Button("Cancel", role: .cancel) { }
        Button("Delete", role: .destructive) {
            if let index = userProfiles.firstIndex(where: { $0.id == currentProfile.id }) {
                userProfiles.remove(at: index)
                currentProfile = userProfiles.first!
                onSave()
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
    
    // Precomputed arrays to keep the compiler happy
    private var times: [TimeInterval] { profile.history.map { $0.time } }
    private var sortedTimes: [TimeInterval] { times.sorted() }

    private var bestTimeComputed: TimeInterval { profile.bestTime }
    private var averageTimeComputed: TimeInterval {
        guard !times.isEmpty else { return 0 }
        return times.reduce(0, +) / Double(times.count)
    }
    private var medianTimeComputed: TimeInterval {
        guard !sortedTimes.isEmpty else { return 0 }
        if sortedTimes.count % 2 == 0 {
            let mid = sortedTimes.count / 2
            return (sortedTimes[mid - 1] + sortedTimes[mid]) / 2
        } else {
            return sortedTimes[sortedTimes.count / 2]
        }
    }
    private var stdDevSampleComputed: TimeInterval {
        let n = times.count
        guard n > 1 else { return 0 }
        let mean = averageTimeComputed
        let sse = times.reduce(0) { partial, t in
            let d = t - mean
            return partial + d * d
        }
        return sqrt(sse / Double(n - 1))
    }

    private var historySortedDesc: [SolveRecord] {
        profile.history.sorted { a, b in a.date > b.date }
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
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            StatCard(title: "Best", value: formatTime(bestTimeComputed), color: .green)
                            StatCard(title: "Average", value: formatTime(averageTimeComputed), color: .blue)
                            StatCard(title: "Median", value: formatTime(medianTimeComputed), color: .purple)
                            StatCard(title: "Std Dev", value: formatTime(stdDevSampleComputed), color: .orange)
                            StatCard(title: "Ao5", value: formatTimeOptional(rollingAoN(profile.history, N: 5)), color: .teal)
                            StatCard(title: "Ao12", value: formatTimeOptional(rollingAoN(profile.history, N: 12)), color: .indigo)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                
                // History List
                List {
                    ForEach(historySortedDesc) { record in
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
    


    private func formatTime(_ time: TimeInterval) -> String {
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
        
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatTimeOptional(_ t: TimeInterval?) -> String {
        guard let t = t else { return "—" }
        return formatTime(t)
    }

    private func rollingAoN(_ records: [SolveRecord], N: Int) -> TimeInterval? {
        guard records.count >= N else { return nil }
        let lastN = records.suffix(N).map { $0.time }
        let sorted = lastN.sorted { (a, b) in
            if a.isFinite != b.isFinite { return a.isFinite }
            return a < b
        }
        let middle = sorted.dropFirst().dropLast()
        if middle.contains(where: { !$0.isFinite }) { return nil }
        let sum = middle.reduce(0, +)
        return sum / Double(middle.count)
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
                ForEach(0..<5, id: \.self) { i in
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
                        let count = data.count
                        guard count > 0 else { return }
                        for index in 0..<count {
                            let value = data[index]
                            let x = width * CGFloat(index) / CGFloat(max(count - 1, 1)) + 20
                            let normalized = range > 0 ? (maxValue - value) / range : 0.5
                            let y = height * normalized + 20

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.blue, lineWidth: 2)

                    // Data points (index-based to help the compiler)
                    ForEach(0..<data.count, id: \.self) { index in
                        let value = data[index]
                        let x = width * CGFloat(index) / CGFloat(max(data.count - 1, 1)) + 20
                        let normalized = range > 0 ? (maxValue - value) / range : 0.5
                        let y = height * normalized + 20

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
                                let avg = profile.totalTime / Double(profile.solveCount)
                                Text("Avg: \(formatTime(avg))")
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
