import AppKit
import SwiftUI

// MARK: - History record

struct DayRecord: Codable, Identifiable, Equatable {
    var id: String { date }
    let date: String // yyyy-MM-dd
    let jobs: Int
    let leetcode: Int
    let food: Bool
    let prep: Bool
    let workout: Bool
    var foodEnabled: Bool = true
    var workoutEnabled: Bool = true

    enum CodingKeys: String, CodingKey {
        case date, jobs, leetcode, food, prep, workout, foodEnabled, workoutEnabled
    }

    init(date: String, jobs: Int, leetcode: Int, food: Bool, prep: Bool, workout: Bool,
         foodEnabled: Bool = true, workoutEnabled: Bool = true) {
        self.date = date
        self.jobs = jobs
        self.leetcode = leetcode
        self.food = food
        self.prep = prep
        self.workout = workout
        self.foodEnabled = foodEnabled
        self.workoutEnabled = workoutEnabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(String.self, forKey: .date)
        jobs = try c.decode(Int.self, forKey: .jobs)
        leetcode = try c.decode(Int.self, forKey: .leetcode)
        food = try c.decode(Bool.self, forKey: .food)
        prep = try c.decode(Bool.self, forKey: .prep)
        workout = try c.decode(Bool.self, forKey: .workout)
        foodEnabled = try c.decodeIfPresent(Bool.self, forKey: .foodEnabled) ?? true
        workoutEnabled = try c.decodeIfPresent(Bool.self, forKey: .workoutEnabled) ?? true
    }

    var perfect: Bool {
        jobs >= 10 && leetcode >= 3 && prep && (!foodEnabled || food) && (!workoutEnabled || workout)
    }
}

// MARK: - Persistent daily store

final class DailyStore: ObservableObject {
    @Published var jobsApplied: Int { didSet { defaults.set(jobsApplied, forKey: Keys.jobs); evaluate() } }
    @Published var leetcodeSolved: Int { didSet { defaults.set(leetcodeSolved, forKey: Keys.leet); evaluate() } }
    @Published var loggedFood: Bool { didSet { defaults.set(loggedFood, forKey: Keys.food); evaluate() } }
    @Published var interviewPrep: Bool { didSet { defaults.set(interviewPrep, forKey: Keys.prep); evaluate() } }
    @Published var workedOut: Bool { didSet { defaults.set(workedOut, forKey: Keys.workout); evaluate() } }
    @Published var foodEnabled: Bool { didSet { defaults.set(foodEnabled, forKey: Keys.foodEnabled); evaluate() } }
    @Published var workoutEnabled: Bool { didSet { defaults.set(workoutEnabled, forKey: Keys.workoutEnabled); evaluate() } }
    @Published var history: [DayRecord] = []

    let jobsTarget = 10
    let leetTarget = 3

    var allComplete: Bool {
        jobsApplied >= jobsTarget && leetcodeSolved >= leetTarget && interviewPrep
            && (!foodEnabled || loggedFood) && (!workoutEnabled || workedOut)
    }

    var onAllComplete: (() -> Void)?
    var onNewDay: (() -> Void)?

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let jobs = "jobsApplied"
        static let leet = "leetcodeSolved"
        static let food = "loggedFood"
        static let prep = "interviewPrep"
        static let workout = "workedOut"
        static let foodEnabled = "foodEnabled"
        static let workoutEnabled = "workoutEnabled"
        static let lastReset = "lastResetDate"
        static let celebratedDate = "celebratedDate"
    }

    private var resetTimer: Timer?
    private let historyURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("DailyGrind", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        historyURL = dir.appendingPathComponent("history.json")

        defaults.register(defaults: [Keys.foodEnabled: true, Keys.workoutEnabled: true])

        jobsApplied = defaults.integer(forKey: Keys.jobs)
        leetcodeSolved = defaults.integer(forKey: Keys.leet)
        loggedFood = defaults.bool(forKey: Keys.food)
        interviewPrep = defaults.bool(forKey: Keys.prep)
        workedOut = defaults.bool(forKey: Keys.workout)
        foodEnabled = defaults.bool(forKey: Keys.foodEnabled)
        workoutEnabled = defaults.bool(forKey: Keys.workoutEnabled)

        loadHistory()
        checkDailyReset()
        resetTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkDailyReset()
        }
    }

    private static var todayString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func evaluate() {
        guard allComplete else { return }
        let today = Self.todayString
        if defaults.string(forKey: Keys.celebratedDate) != today {
            defaults.set(today, forKey: Keys.celebratedDate)
            onAllComplete?()
        }
    }

    func checkDailyReset() {
        let today = Self.todayString
        let last = defaults.string(forKey: Keys.lastReset)
        guard last != today else { return }

        if let last = last {
            let record = DayRecord(date: last, jobs: jobsApplied, leetcode: leetcodeSolved,
                                    food: loggedFood, prep: interviewPrep, workout: workedOut,
                                    foodEnabled: foodEnabled, workoutEnabled: workoutEnabled)
            history.removeAll { $0.date == last }
            history.append(record)
            saveHistory()
        }

        jobsApplied = 0
        leetcodeSolved = 0
        loggedFood = false
        interviewPrep = false
        workedOut = false
        foodEnabled = true
        workoutEnabled = true
        defaults.set(today, forKey: Keys.lastReset)
        defaults.removeObject(forKey: Keys.celebratedDate)

        if last != nil {
            onNewDay?()
        }
    }

    func resetNow() {
        jobsApplied = 0
        leetcodeSolved = 0
        loggedFood = false
        interviewPrep = false
        workedOut = false
        foodEnabled = true
        workoutEnabled = true
        defaults.set(Self.todayString, forKey: Keys.lastReset)
        defaults.removeObject(forKey: Keys.celebratedDate)
    }

    private func loadHistory() {
        guard let data = try? Data(contentsOf: historyURL),
              let decoded = try? JSONDecoder().decode([DayRecord].self, from: data) else { return }
        history = decoded
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        try? data.write(to: historyURL, options: .atomic)
    }

    /// Today's live record merged with history for the stats view, newest first.
    var displayRecords: [DayRecord] {
        let today = DayRecord(date: Self.todayString, jobs: jobsApplied, leetcode: leetcodeSolved,
                               food: loggedFood, prep: interviewPrep, workout: workedOut,
                               foodEnabled: foodEnabled, workoutEnabled: workoutEnabled)
        return ([today] + history.sorted { $0.date > $1.date })
    }

    func exportCSV() -> URL? {
        var csv = "date,jobs_applied,leetcode_solved,logged_food,food_enabled,interview_prep,workout,workout_enabled,perfect_day\n"
        for r in displayRecords.sorted(by: { $0.date < $1.date }) {
            csv += "\(r.date),\(r.jobs),\(r.leetcode),\(r.food),\(r.foodEnabled),\(r.prep),\(r.workout),\(r.workoutEnabled),\(r.perfect)\n"
        }
        let url = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            .appendingPathComponent("DailyGrindStats.csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}

// MARK: - Visual effect background (frosted glass)

struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Widget UI

struct CounterRow: View {
    let icon: String
    let title: String
    @Binding var value: Int
    let target: Int

    var done: Bool { value >= target }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(icon) \(title)")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(value)/\(target)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(done ? .green : .primary)
            }
            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.25))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(done ? Color.green : Color.accentColor)
                            .frame(width: geo.size.width * min(CGFloat(value) / CGFloat(target), 1.0))
                    }
                }
                .frame(height: 6)

                Button(action: { if value > 0 { value -= 1 } }) {
                    Image(systemName: "minus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Button(action: { value += 1 }) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
        }
    }
}

struct ToggleRow: View {
    let icon: String
    let title: String
    @Binding var checked: Bool

    var body: some View {
        Button(action: { checked.toggle() }) {
            HStack(spacing: 6) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .foregroundColor(checked ? .green : .secondary)
                Text("\(icon) \(title)")
                    .font(.system(size: 12))
                    .strikethrough(checked, color: .secondary)
                    .foregroundColor(checked ? .secondary : .primary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

/// Small pill switch used to enable/disable an optional habit for the day.
struct MiniSwitch: View {
    @Binding var isOn: Bool
    var body: some View {
        Button(action: { isOn.toggle() }) {
            Capsule()
                .fill(isOn ? Color.green : Color.gray.opacity(0.35))
                .frame(width: 28, height: 15)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 11, height: 11)
                        .offset(x: isOn ? 6.5 : -6.5)
                        .shadow(radius: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// A checkbox row for a habit that can itself be switched on/off for the day.
/// When disabled, the checkbox is dimmed and not required for "all complete".
struct HabitRow: View {
    let icon: String
    let title: String
    @Binding var checked: Bool
    @Binding var enabled: Bool

    var body: some View {
        HStack(spacing: 6) {
            Button(action: { if enabled { checked.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: (checked && enabled) ? "checkmark.square.fill" : "square")
                        .foregroundColor(enabled ? (checked ? .green : .secondary) : .secondary.opacity(0.3))
                    Text("\(icon) \(title)")
                        .font(.system(size: 12))
                        .strikethrough(checked && enabled, color: .secondary)
                        .foregroundColor(enabled ? (checked ? .secondary : .primary) : .secondary.opacity(0.4))
                }
            }
            .buttonStyle(.plain)
            .disabled(!enabled)

            Spacer()

            MiniSwitch(isOn: $enabled)
        }
    }
}

struct ContentView: View {
    @ObservedObject var store: DailyStore
    var onStats: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Daily Grind")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button(action: onStats) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("View Stats")

                Button(action: onQuit) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Quit")
            }

            CounterRow(icon: "💼", title: "Jobs Applied", value: $store.jobsApplied, target: store.jobsTarget)
            CounterRow(icon: "🧩", title: "LeetCode", value: $store.leetcodeSolved, target: store.leetTarget)

            Divider().padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 6) {
                HabitRow(icon: "🍽️", title: "Log food", checked: $store.loggedFood, enabled: $store.foodEnabled)
                ToggleRow(icon: "📚", title: "Interview prep", checked: $store.interviewPrep)
                HabitRow(icon: "🏋️", title: "Workout", checked: $store.workedOut, enabled: $store.workoutEnabled)
            }

            if store.allComplete {
                Text("🎉 All done for today!")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(12)
        .frame(width: 210)
        .background(VisualEffect())
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Stats window UI

struct StatTile: View {
    let title: String
    let value: String
    let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(color)
            Text(title).font(.system(size: 11)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
    }
}

struct MiniBar: View {
    let label: String
    let jobs: Int
    let leet: Int
    let perfect: Bool
    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.15)).frame(width: 16, height: 60)
                VStack(spacing: 1) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.orange)
                        .frame(width: 16, height: max(2, CGFloat(min(leet, 10)) * 3))
                    RoundedRectangle(cornerRadius: 2).fill(Color.accentColor)
                        .frame(width: 16, height: max(2, CGFloat(min(jobs, 15)) * 3))
                }
            }
            .frame(height: 60, alignment: .bottom)
            Text(label).font(.system(size: 8)).foregroundColor(perfect ? .green : .secondary)
        }
    }
}

struct StatsView: View {
    @ObservedObject var store: DailyStore
    @State private var exportMessage: String?

    var totalJobs: Int { store.displayRecords.reduce(0) { $0 + $1.jobs } }
    var totalLeet: Int { store.displayRecords.reduce(0) { $0 + $1.leetcode } }
    var perfectDays: Int { store.displayRecords.filter { $0.perfect }.count }
    var streak: Int {
        var count = 0
        for r in store.displayRecords {
            if r.perfect { count += 1 } else { break }
        }
        return count
    }

    @ViewBuilder
    func habitCell(enabled: Bool, done: Bool) -> some View {
        if enabled {
            Image(systemName: done ? "checkmark" : "minus")
        } else {
            Text("off").font(.system(size: 9)).foregroundColor(.secondary.opacity(0.6))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("📊 Daily Grind — Stats")
                .font(.system(size: 18, weight: .bold))

            HStack(spacing: 10) {
                StatTile(title: "Total Jobs Applied", value: "\(totalJobs)", color: .accentColor)
                StatTile(title: "Total LeetCode Solved", value: "\(totalLeet)", color: .orange)
                StatTile(title: "Perfect Days", value: "\(perfectDays)", color: .green)
                StatTile(title: "Current Streak", value: "\(streak)🔥", color: .pink)
            }

            Text("Last 14 days").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(store.displayRecords.prefix(14).reversed()) { r in
                        MiniBar(label: String(r.date.suffix(5)), jobs: r.jobs, leet: r.leetcode, perfect: r.perfect)
                    }
                }
                .padding(.vertical, 4)
            }

            Divider()

            Text("History").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)

            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        Text("Date").frame(width: 90, alignment: .leading)
                        Text("Jobs").frame(width: 50)
                        Text("LeetCode").frame(width: 70)
                        Text("Food").frame(width: 50)
                        Text("Prep").frame(width: 50)
                        Text("Workout").frame(width: 60)
                        Spacer()
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)

                    ForEach(store.displayRecords) { r in
                        HStack {
                            Text(r.date).frame(width: 90, alignment: .leading)
                            Text("\(r.jobs)/\(store.jobsTarget)").frame(width: 50)
                            Text("\(r.leetcode)/\(store.leetTarget)").frame(width: 70)
                            habitCell(enabled: r.foodEnabled, done: r.food).frame(width: 50)
                            Image(systemName: r.prep ? "checkmark" : "minus").frame(width: 50)
                            habitCell(enabled: r.workoutEnabled, done: r.workout).frame(width: 60)
                            Spacer()
                        }
                        .font(.system(size: 11))
                        .padding(.vertical, 5)
                        .background(r.perfect ? Color.green.opacity(0.08) : Color.clear)
                    }
                }
            }

            HStack {
                Button("Export CSV to Desktop") {
                    if let url = store.exportCSV() {
                        exportMessage = "Saved to \(url.lastPathComponent)"
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } else {
                        exportMessage = "Export failed"
                    }
                }
                if let msg = exportMessage {
                    Text(msg).font(.system(size: 11)).foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding(20)
        .frame(minWidth: 640, minHeight: 520)
    }
}

// MARK: - App delegate / window management

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var panel: NSPanel?
    var statsWindow: NSWindow?
    var statusItem: NSStatusItem!
    let store = DailyStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // no Dock icon, no app switcher entry by default

        store.onAllComplete = { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                self?.panel?.orderOut(nil)
            }
        }
        store.onNewDay = { [weak self] in
            self?.showPanel()
        }

        setupStatusItem()
        showPanel()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "target", accessibilityDescription: "Daily Grind")
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Widget", action: #selector(showPanelAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "View Stats…", action: #selector(showStatsAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Reset Today", action: #selector(resetTodayAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Daily Grind", action: #selector(quitAction), keyEquivalent: "q"))
        for item in menu.items { item.target = self }
        statusItem.menu = menu
    }

    @objc func showPanelAction() { showPanel() }
    @objc func showStatsAction() { showStats() }
    @objc func resetTodayAction() { store.resetNow() }
    @objc func quitAction() { NSApp.terminate(nil) }

    func showPanel() {
        if let panel = panel {
            panel.orderFrontRegardless()
            return
        }
        let content = ContentView(store: store, onStats: { [weak self] in self?.showStats() },
                                   onQuit: { [weak self] in self?.panel?.orderOut(nil) })
        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(x: 0, y: 0, width: 234, height: 320)

        let panel = NSPanel(
            contentRect: hosting.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.contentView = hosting
        panel.setFrameAutosaveName("JobGrindWidgetPanel")

        if panel.frame.origin == .zero, let screen = NSScreen.main {
            let x = screen.visibleFrame.maxX - hosting.frame.width - 20
            let y = screen.visibleFrame.maxY - hosting.frame.height - 20
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFrontRegardless()
        self.panel = panel
    }

    func showStats() {
        if let win = statsWindow {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            win.makeKeyAndOrderFront(nil)
            return
        }
        let view = StatsView(store: store)
        let hosting = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 560),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Daily Grind — Stats"
        window.contentView = hosting
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        self.statsWindow = window
    }

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === statsWindow {
            statsWindow = nil
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
