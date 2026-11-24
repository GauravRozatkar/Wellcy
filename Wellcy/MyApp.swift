//
//  WellcyApp.swift
//  Wellcy: supporting cancer patients through every stage of life.
//  Developed by Gaurav Rozatkar for Nexora
//  Single file. No packages. Requires Xcode 15 or later and iOS 17 or later.
//  Screens: Home, Daily Check-in, Appointment calendar, Journey.
//

import SwiftUI
import Combine
import PDFKit
import UserNotifications
import UniformTypeIdentifiers

// MARK: - Theme

enum Theme {
    static let ink = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.94, green: 0.91, blue: 0.98, alpha: 1)
            : UIColor(red: 0.12, green: 0.08, blue: 0.22, alpha: 1)
    })
    static let amethyst = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.73, green: 0.61, blue: 0.91, alpha: 1)
            : UIColor(red: 0.357, green: 0.216, blue: 0.510, alpha: 1)
    })
    static let surface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.10, blue: 0.15, alpha: 1)
            : UIColor.white
    })
    static let violet = Color(red: 0.482, green: 0.318, blue: 0.659)
    static let orchid = Color(red: 0.949, green: 0.863, blue: 0.961)
    static let lilac = Color(red: 0.894, green: 0.843, blue: 0.969)
    static let mist = Color(red: 0.973, green: 0.961, blue: 0.988)
    static let magenta = Color(red: 0.722, green: 0.267, blue: 0.600)
    static let deepPurple = Color(red: 0.290, green: 0.133, blue: 0.478)
    static let brightPurple = Color(red: 0.463, green: 0.220, blue: 0.722)
}

// MARK: - Sample data (change these to match your demo)

enum Sample {
    // Noon UTC timestamps so the dates look the same in every time zone.
    static let diagnosed: Double = 1677672000      // 1 Mar 2023
    static let surgery: Double = 1682942400        // 1 May 2023
    static let lastTreatment: Double = 1732881600  // 29 Nov 2024
    static let userName = ""
    static let familyName = ""
}

// MARK: - Labels

enum Mood {
    static let names = ["Great", "Good", "Okay", "Low", "Rough"]
    static let emojis = ["😄", "🙂", "😐", "😔", "😣"]

    static func message(for index: Int) -> String {
        switch index {
        case 0, 1: return "That is lovely to hear. Enjoy the good moments today."
        case 2: return "Thanks for sharing. Be gentle with yourself today."
        default: return "Thanks for telling us. Taking a few slow breaths might help."
        }
    }
}

enum Fatigue {
    static let labels = ["Energised", "Good", "Tired", "Very tired", "Exhausted"]
    static let emojis = ["⚡", "🔋", "🥱", "😴", "🪫"]
}

enum SleepQuality {
    static let labels = ["Excellent", "Good", "Fair", "Poor", "Barely slept"]
    static let emojis = ["🌟", "😴", "😪", "😵‍💫", "🌙"]
}

enum AppointmentType {
    static let all = ["Blood test", "Oncology review", "Chemo / Infusion", "Scan", "Check-up"]
    static let slots = ["09:30", "11:00", "14:00", "16:30"]
}

// MARK: - Helpers

func fmt(_ date: Date, _ format: String) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_GB")
    f.dateFormat = format
    return f.string(from: date)
}

func daysUntil(_ date: Date) -> Int {
    Calendar.current.dateComponents([.day], from: Date().startOfDay, to: date.startOfDay).day ?? 0
}

func dateBinding(_ source: Binding<Double>) -> Binding<Date> {
    Binding(
        get: { Date(timeIntervalSince1970: source.wrappedValue) },
        set: { source.wrappedValue = $0.timeIntervalSince1970 }
    )
}

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
}

// MARK: - Models

struct Appointment: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var types: [String]
    var location: String

    var title: String {
        var parts: [String] = []
        for (index, t) in types.enumerated() {
            parts.append(index == 0 ? t : t.lowercased())
        }
        return parts.joined(separator: " + ")
    }
}

struct CheckIn: Identifiable, Codable, Hashable {
    var id = UUID()
    var day: Date
    var feeling: Int?
    var fatigue: Int?
    var sleep: Int?
    var note: String = ""
}

struct Letter: Identifiable, Codable, Hashable {
    var id: UUID
    var text: String
    var created: Date
    var opensOn: Date
    var isOpened: Bool

    private enum CodingKeys: String, CodingKey {
        case id, text, created, opensOn, isOpened
    }

    init(
        id: UUID = UUID(),
        text: String,
        created: Date,
        opensOn: Date,
        isOpened: Bool = false
    ) {
        self.id = id
        self.text = text
        self.created = created
        self.opensOn = opensOn
        self.isOpened = isOpened
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        text = try values.decode(String.self, forKey: .text)
        created = try values.decode(Date.self, forKey: .created)
        opensOn = try values.decode(Date.self, forKey: .opensOn)
        isOpened = try values.decodeIfPresent(Bool.self, forKey: .isOpened) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(text, forKey: .text)
        try values.encode(created, forKey: .created)
        try values.encode(opensOn, forKey: .opensOn)
        try values.encode(isOpened, forKey: .isOpened)
    }
}

struct Report: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var date: Date
    var fileName: String
}

struct Milestone {
    let years: Int
    let days: Int
    let progress: Double

    var sentence: String {
        let yearText = years == 1 ? "1 year" : "\(years) years"
        if days <= 0 { return "Today marks \(yearText) since your last treatment" }
        let dayText = days == 1 ? "1 day" : "\(days) days"
        return "\(dayText) until \(yearText) since your last treatment"
    }

    static func next(after last: Date, now: Date = Date()) -> Milestone? {
        let cal = Calendar.current
        guard last <= now else { return nil }
        let completed = cal.dateComponents([.year], from: last, to: now).year ?? 0
        guard let prev = cal.date(byAdding: .year, value: completed, to: last),
              let target = cal.date(byAdding: .year, value: completed + 1, to: last) else { return nil }
        if completed >= 1 && cal.isDate(prev, inSameDayAs: now) {
            return Milestone(years: completed, days: 0, progress: 1)
        }
        let days = cal.dateComponents([.day], from: now.startOfDay, to: target.startOfDay).day ?? 0
        let total = max(1, cal.dateComponents([.day], from: prev.startOfDay, to: target.startOfDay).day ?? 365)
        let progress = min(1, max(0, Double(total - days) / Double(total)))
        return Milestone(years: completed + 1, days: days, progress: progress)
    }
}

// MARK: - Store (saved on the device)

final class Store: ObservableObject {
    @Published var appointments: [Appointment] = [] {
        didSet { Store.save(appointments, "wellcy.appointments") }
    }
    @Published var checkIns: [CheckIn] = [] {
        didSet { Store.save(checkIns, "wellcy.checkins") }
    }
    @Published var letters: [Letter] = [] {
        didSet { Store.save(letters, "wellcy.letters") }
    }
    @Published var reports: [Report] = [] {
        didSet { Store.save(reports, "wellcy.reports") }
    }

    init() {
        appointments = Store.load("wellcy.appointments", fallback: Store.sampleAppointments())
        checkIns = Store.load("wellcy.checkins", fallback: [])
        letters = Store.load("wellcy.letters", fallback: [])
        reports = Store.load("wellcy.reports", fallback: [])
    }

    // Persistence
    private static func load<T: Decodable>(_ key: String, fallback: T) -> T {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode(T.self, from: data) else { return fallback }
        return value
    }

    private static func save<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func sampleAppointments() -> [Appointment] {
        let comps = DateComponents(year: 2026, month: 12, day: 4, hour: 9, minute: 30)
        guard let date = Calendar.current.date(from: comps) else { return [] }
        return [Appointment(date: date, types: ["Blood test", "Oncology review"], location: "Oncology clinic")]
    }

    // Appointments
    var nextAppointment: Appointment? {
        appointments.filter { $0.date >= Date() }.sorted { $0.date < $1.date }.first
    }

    func appointmentsOn(_ day: Date) -> [Appointment] {
        appointments
            .filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            .sorted { $0.date < $1.date }
    }

    func addAppointment(_ appointment: Appointment) {
        appointments.append(appointment)
        appointments.sort { $0.date < $1.date }
        Reminders.schedule(for: appointment)
    }

    func deleteAppointment(_ appointment: Appointment) {
        Reminders.cancel(appointment)
        appointments.removeAll { $0.id == appointment.id }
    }

    // Check-ins
    func checkIn(on day: Date) -> CheckIn? {
        checkIns.first { Calendar.current.isDate($0.day, inSameDayAs: day) }
    }

    func update(day: Date, _ change: (inout CheckIn) -> Void) {
        if let index = checkIns.firstIndex(where: { Calendar.current.isDate($0.day, inSameDayAs: day) }) {
            change(&checkIns[index])
        } else {
            var entry = CheckIn(day: day.startOfDay)
            change(&entry)
            checkIns.append(entry)
        }
    }

    func setMood(_ index: Int) {
        update(day: Date()) { $0.feeling = index }
    }

    func openLetter(_ letter: Letter) {
        guard let index = letters.firstIndex(where: { $0.id == letter.id }) else { return }
        letters[index].isOpened = true
    }

    func deleteLetter(_ letter: Letter) {
        letters.removeAll { $0.id == letter.id && $0.isOpened }
    }

    // Reports (PDF files copied into the app's Documents folder)
    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func fileURL(for report: Report) -> URL {
        documentsURL.appendingPathComponent(report.fileName)
    }

    func importReport(from url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let name = UUID().uuidString + ".pdf"
        let destination = Store.documentsURL.appendingPathComponent(name)
        do {
            try FileManager.default.copyItem(at: url, to: destination)
            let title = url.deletingPathExtension().lastPathComponent
            reports.insert(Report(title: title, date: Date(), fileName: name), at: 0)
        } catch {
            // Ignore: the file could not be copied.
        }
    }

    func deleteReport(_ report: Report) {
        try? FileManager.default.removeItem(at: Store.fileURL(for: report))
        reports.removeAll { $0.id == report.id }
    }
}

// MARK: - Appointment reminders

enum Reminders {
    static func schedule(for appointment: Appointment) {
        let fire = appointment.date.addingTimeInterval(-24 * 3600)
        guard fire > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Appointment tomorrow"
        content.body = "\(appointment.title) at \(fmt(appointment.date, "HH:mm")), \(appointment.location)"
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: appointment.id.uuidString, content: content, trigger: trigger)

        Task {
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            if granted {
                try? await center.add(request)
            }
        }
    }

    static func cancel(_ appointment: Appointment) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [appointment.id.uuidString])
    }
}

// MARK: - PDF export for the doctor

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

enum ReportExporter {
    static func measure(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs,
            context: nil
        )
        return ceil(rect.height)
    }

    @discardableResult
    static func draw(_ text: String, font: UIFont, color: UIColor, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let height = measure(text, font: font, width: width)
        (text as NSString).draw(in: CGRect(x: x, y: y, width: width, height: height), withAttributes: attrs)
        return height
    }

    static func makePDF(checkIns: [CheckIn], name: String) -> URL? {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 40
        let width = page.width - margin * 2
        let purple = UIColor(red: 0.357, green: 0.216, blue: 0.510, alpha: 1)
        let entries = Array(checkIns.sorted { $0.day > $1.day }.prefix(60))
        let renderer = UIGraphicsPDFRenderer(bounds: page)

        let data = renderer.pdfData { ctx in
            var y: CGFloat = margin

            func startPage() {
                ctx.beginPage()
                y = margin
            }

            startPage()
            y += ReportExporter.draw("Wellcy symptom report", font: .systemFont(ofSize: 24, weight: .bold),
                                     color: purple, x: margin, y: y, width: width) + 6
            y += ReportExporter.draw("Prepared for: \(name)", font: .systemFont(ofSize: 13),
                                     color: .darkGray, x: margin, y: y, width: width) + 2
            y += ReportExporter.draw("Generated on \(fmt(Date(), "d MMMM yyyy")). Most recent check-ins first.",
                                     font: .systemFont(ofSize: 11), color: .gray, x: margin, y: y, width: width) + 18

            if entries.isEmpty {
                y += ReportExporter.draw("No check-ins have been logged yet.", font: .systemFont(ofSize: 13),
                                         color: .black, x: margin, y: y, width: width)
            }

            for entry in entries {
                let feeling = entry.feeling.map { Mood.names[$0] } ?? "not logged"
                let fatigue = entry.fatigue.map { Fatigue.labels[$0] } ?? "not logged"
                let sleep = entry.sleep.map { SleepQuality.labels[$0] } ?? "not logged"
                let summary = "Feeling: \(feeling)     Fatigue: \(fatigue)     Sleep: \(sleep)"
                let note = entry.note.trimmingCharacters(in: .whitespacesAndNewlines)
                let noteText = note.isEmpty ? "" : "Note: \(note)"

                let headFont = UIFont.systemFont(ofSize: 13, weight: .semibold)
                let bodyFont = UIFont.systemFont(ofSize: 12)
                var needed = ReportExporter.measure("Ag", font: headFont, width: width) + 3
                needed += ReportExporter.measure(summary, font: bodyFont, width: width) + 3
                if !noteText.isEmpty { needed += ReportExporter.measure(noteText, font: bodyFont, width: width) + 3 }
                needed += 14

                if y + needed > page.height - margin { startPage() }

                y += ReportExporter.draw(fmt(entry.day, "EEEE, d MMMM yyyy"), font: headFont,
                                         color: purple, x: margin, y: y, width: width) + 3
                y += ReportExporter.draw(summary, font: bodyFont, color: .black,
                                         x: margin, y: y, width: width) + 3
                if !noteText.isEmpty {
                    y += ReportExporter.draw(noteText, font: bodyFont, color: .darkGray,
                                             x: margin, y: y, width: width) + 3
                }
                y += 6
                let line = UIBezierPath()
                line.move(to: CGPoint(x: margin, y: y))
                line.addLine(to: CGPoint(x: margin + width, y: y))
                line.lineWidth = 0.5
                UIColor.lightGray.setStroke()
                line.stroke()
                y += 8
            }
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Wellcy-Symptom-Report.pdf")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}

// MARK: - Small reusable UI

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct PDFKitView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}

struct BackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                LinearGradient(colors: [Color(red: 0.025, green: 0.02, blue: 0.04),
                                       Color(red: 0.055, green: 0.045, blue: 0.075),
                                       Color(red: 0.025, green: 0.02, blue: 0.04)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .fill(Theme.violet.opacity(0.12))
                    .frame(width: 300, height: 300)
                    .blur(radius: 70)
                    .offset(x: -140, y: -250)
                Circle()
                    .fill(Theme.magenta.opacity(0.10))
                    .frame(width: 320, height: 320)
                    .blur(radius: 80)
                    .offset(x: 150, y: 260)
            } else {
                LinearGradient(colors: [Theme.lilac, Theme.mist, Theme.orchid],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .fill(Theme.violet.opacity(0.18))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: -140, y: -250)
                Circle()
                    .fill(Theme.magenta.opacity(0.14))
                    .frame(width: 320, height: 320)
                    .blur(radius: 70)
                    .offset(x: 150, y: 260)
            }
        }
        .ignoresSafeArea()
    }
}

struct GlassCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(colorScheme == .dark ? Color(red: 0.085, green: 0.07, blue: 0.11) : Color.white.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.12) : Theme.surface.opacity(0.7), lineWidth: 1)
                    )
                    .shadow(color: Theme.amethyst.opacity(colorScheme == .dark ? 0.05 : 0.10), radius: 14, x: 0, y: 6)
            )
    }
}

extension View {
    func glassCard() -> some View { modifier(GlassCard()) }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                LinearGradient(colors: [Theme.amethyst, Theme.violet],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Capsule()
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct Chip: View {
    let title: String
    let selected: Bool
    var expand: Bool = false

    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(selected ? Color.white : Theme.ink)
            .padding(.horizontal, expand ? 4 : 14)
            .padding(.vertical, 9)
            .frame(maxWidth: expand ? CGFloat.infinity : nil)
            .background(Capsule().fill(selected ? Theme.amethyst : Theme.surface.opacity(0.7)))
    }
}

struct BackChip: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text("← Home")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.amethyst)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Theme.surface.opacity(0.85)))
        }
        .buttonStyle(.plain)
    }
}

struct ScreenHeader: View {
    let title: String
    let subtitle: String
    var back: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if let back = back { BackChip(action: back) }
            }
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink.opacity(0.65))
        }
    }
}

struct DaysBadge: View {
    let days: Int

    var body: some View {
        VStack(spacing: 0) {
            if days <= 0 {
                Text("Today").font(.system(size: 16, weight: .bold, design: .rounded))
            } else if days == 1 {
                Text("Tomorrow").font(.system(size: 14, weight: .bold, design: .rounded))
            } else {
                Text("\(days)").font(.system(size: 26, weight: .bold, design: .rounded))
                Text("days").font(.system(size: 12, weight: .medium))
            }
        }
        .foregroundStyle(Color.white)
        .frame(width: 72, height: 66)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
        )
    }
}

// MARK: - App entry

@main
struct WellcyApp: App {
    @StateObject private var store = Store()
    @AppStorage("wellcy.appearance") private var appearance = "system"

    private var preferredScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(preferredScheme)
                .tint(Theme.amethyst)
        }
    }
}

enum Screen {
    case home, checkIn, appointments, journey, profile
}

struct RootView: View {
    @State private var screen: Screen = .home
    @State private var showHelp = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            BackgroundView()

            Group {
                switch screen {
                case .home:
                    HomeScreen(screen: $screen, showHelp: $showHelp)
                case .checkIn:
                    CheckInScreen(screen: $screen)
                case .appointments:
                    AppointmentScreen(screen: $screen)
                case .journey:
                    JourneyScreen()
                case .profile:
                    ProfileScreen()
                }
            }

        }
        .safeAreaInset(edge: .bottom) {
            TabBar(screen: $screen)
        }
        .sheet(isPresented: $showHelp) { HelpSheet() }
    }
}

struct TabBar: View {
    @Binding var screen: Screen

    var body: some View {
        HStack(spacing: 6) {
            tab(.home, "Home", "house")
            tab(.journey, "Journey", "flag")
            tab(.profile, "Profile", "person")
        }
        .padding(6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.7), lineWidth: 1))
                .shadow(color: Theme.amethyst.opacity(0.12), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    private func tab(_ target: Screen, _ title: String, _ icon: String) -> some View {
        let selected = screen == target
        return Button {
            screen = target
        } label: {
            VStack(spacing: 2) {
                Image(systemName: selected ? icon + ".fill" : icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(selected ? Color.white : Theme.amethyst)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .background(Capsule().fill(selected ? Theme.amethyst : Color.clear))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) tab")
        .accessibilityIdentifier("\(title.lowercased())Tab")
    }
}

// MARK: - Home

struct HomeScreen: View {
    @EnvironmentObject private var store: Store
    @Binding var screen: Screen
    @Binding var showHelp: Bool
    @AppStorage("wellcy.userName") private var userName = Sample.userName
    @AppStorage("wellcy.lastTreatmentTS") private var lastTreatmentTS = Sample.lastTreatment
    @State private var editingName = false
    @State private var nameDraft = ""

    private func greeting(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        let part = hour < 12 ? "Good morning" : (hour < 18 ? "Good afternoon" : "Good evening")
        let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? part : "\(part), \(name)"
    }

    private var todayMood: Int? { store.checkIn(on: Date())?.feeling }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Spacer()
                    Button { showHelp = true } label: {
                        Label("Help now", systemImage: "heart")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.magenta)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Theme.surface.opacity(0.85)))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    nameDraft = userName
                    editingName = true
                } label: {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Text(greeting(for: context.date))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                    }
                }
                .buttonStyle(.plain)

                feelingCard
                nextCheckupCard
                comingUpCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 90)
        }
        .scrollIndicators(.hidden)
        .alert("What should we call you?", isPresented: $editingName) {
            TextField("Name", text: $nameDraft)
            Button("Save") {
                userName = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func go(_ target: Screen) {
        withAnimation(.easeInOut(duration: 0.2)) { screen = target }
    }

    private var feelingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text("How are you feeling today?")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Button { go(.checkIn) } label: {
                    Text("Daily Check-in →")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.amethyst)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                ForEach(Mood.names.indices, id: \.self) { i in
                    Button { store.setMood(i) } label: {
                        Chip(title: Mood.names[i], selected: todayMood == i, expand: true)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let mood = todayMood {
                Text(Mood.message(for: mood))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.ink.opacity(0.75))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface.opacity(0.6)))
            }
        }
        .glassCard()
    }

    private var nextCheckupCard: some View {
        Button { go(.appointments) } label: {
            VStack(alignment: .leading, spacing: 14) {
                if let next = store.nextAppointment {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Next check-up")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.8))
                            Text(next.title)
                                .font(.system(size: 21, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white)
                                .multilineTextAlignment(.leading)
                            Text("\(fmt(next.date, "EEE d MMM · HH:mm")) · \(next.location)")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.white.opacity(0.85))
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 8)
                        DaysBadge(days: daysUntil(next.date))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Next check-up")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.8))
                        Text("No appointments yet")
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                        Text("Add your next visit so you never lose track of it.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.85))
                            .multilineTextAlignment(.leading)
                    }
                }

                Divider().overlay(Color.white.opacity(0.35))

                HStack {
                    Text("View and manage dates")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.85))
                    Spacer()
                    Text("Full calendar →")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.amethyst)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Theme.surface.opacity(0.92)))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.amethyst, Theme.violet],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .shadow(color: Theme.amethyst.opacity(0.3), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var comingUpCard: some View {
        let last = Date(timeIntervalSince1970: lastTreatmentTS)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Coming up")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.amethyst)
            if let milestone = Milestone.next(after: last) {
                Text(milestone.sentence)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.violet.opacity(0.18))
                        Capsule()
                            .fill(LinearGradient(colors: [Theme.violet, Theme.magenta],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * milestone.progress)
                    }
                }
                .frame(height: 8)
            } else {
                Text("Add your last treatment day in Journey to see your next milestone.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.ink.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

// MARK: - Daily Check-in

struct OptionRow: View {
    let title: String
    let emojis: [String]
    let labels: [String]
    @Binding var selection: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if let s = selection {
                    Text(labels[s])
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.amethyst)
                }
            }
            HStack(spacing: 8) {
                ForEach(emojis.indices, id: \.self) { i in
                    Button { selection = i } label: {
                        Text(emojis[i])
                            .font(.system(size: 26))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(selection == i ? Theme.amethyst.opacity(0.18) : Theme.surface.opacity(0.6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(selection == i ? Theme.amethyst : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(labels[i])
                }
            }
        }
        .glassCard()
    }
}

struct CheckInScreen: View {
    @EnvironmentObject private var store: Store
    @Binding var screen: Screen
    @AppStorage("wellcy.userName") private var userName = Sample.userName
    @State private var day = Date().startOfDay
    @State private var feeling: Int?
    @State private var fatigue: Int?
    @State private var sleep: Int?
    @State private var note = ""
    @State private var saved = false
    @State private var shareItem: IdentifiableURL?

    private var isToday: Bool { day >= Date().startOfDay }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: "Daily Check-in",
                             subtitle: "How is your body today? Takes about 10 seconds",
                             back: goHome)

                HStack {
                    Button { shift(-1) } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Theme.surface.opacity(0.8)))
                    }
                    Spacer()
                    Text(isToday ? "Today, \(fmt(day, "d MMMM yyyy"))" : fmt(day, "EEEE, d MMMM yyyy"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Button { shift(1) } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Theme.surface.opacity(0.8)))
                    }
                    .disabled(isToday)
                    .opacity(isToday ? 0.35 : 1)
                }
                .foregroundStyle(Theme.amethyst)
                .glassCard()

                OptionRow(title: "Overall Feeling", emojis: Mood.emojis, labels: Mood.names, selection: $feeling)
                OptionRow(title: "Fatigue", emojis: Fatigue.emojis, labels: Fatigue.labels, selection: $fatigue)
                OptionRow(title: "Sleep Quality", emojis: SleepQuality.emojis, labels: SleepQuality.labels, selection: $sleep)

                TextField("Add a note... (e.g. tingling in foot after walk)", text: $note, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.system(size: 15))
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface.opacity(0.75)))

                Button(action: save) {
                    Text(saved ? "Saved ✓" : "Save today's log")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button(action: export) {
                    Text("↓ Export report for my doctor (PDF)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.amethyst)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surface.opacity(0.8)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onAppear { load() }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
    }

    private func goHome() {
        withAnimation(.easeInOut(duration: 0.2)) { screen = .home }
    }

    private func load() {
        let entry = store.checkIn(on: day)
        feeling = entry?.feeling
        fatigue = entry?.fatigue
        sleep = entry?.sleep
        note = entry?.note ?? ""
    }

    private func shift(_ delta: Int) {
        if let next = Calendar.current.date(byAdding: .day, value: delta, to: day),
           next <= Date().startOfDay {
            day = next
            load()
        }
    }

    private func save() {
        store.update(day: day) { entry in
            entry.feeling = feeling
            entry.fatigue = fatigue
            entry.sleep = sleep
            entry.note = note
        }
        saved = true
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            saved = false
        }
    }

    private func export() {
        if let url = ReportExporter.makePDF(checkIns: store.checkIns, name: userName) {
            shareItem = IdentifiableURL(url: url)
        }
    }
}

// MARK: - Appointments

struct AppointmentScreen: View {
    @EnvironmentObject private var store: Store
    @Binding var screen: Screen
    @State private var month = Date()
    @State private var selected = Date().startOfDay
    @State private var types: Set<String> = ["Blood test"]
    @State private var slot = "09:30"
    @State private var location = "Oncology clinic"

    private var cal: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }

    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: "Appointment",
                             subtitle: "Select a date to schedule or view appointments",
                             back: goHome)
                calendarCard
                detailsCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private func goHome() {
        withAnimation(.easeInOut(duration: 0.2)) { screen = .home }
    }

    // Calendar

    private var calendarCard: some View {
        VStack(spacing: 10) {
            HStack {
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Theme.surface.opacity(0.8)))
                }
                Spacer()
                Text(fmt(month, "MMMM yyyy"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Theme.surface.opacity(0.8)))
                }
            }
            .foregroundStyle(Theme.amethyst)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    Text(weekdays[i])
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.ink.opacity(0.5))
                }
            }

            let days = daysInMonth()
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(days.indices, id: \.self) { i in
                    if let date = days[i] {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }

            HStack(spacing: 16) {
                legend(Theme.amethyst, "Selected")
                legend(Theme.violet.opacity(0.7), "Appointment")
                legend(Theme.magenta.opacity(0.6), "Today")
            }
            .padding(.top, 4)
        }
        .glassCard()
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(Theme.ink.opacity(0.65))
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selected)
        let isToday = Calendar.current.isDateInToday(date)
        let hasAppointment = !store.appointmentsOn(date).isEmpty
        let dayNumber = Calendar.current.component(.day, from: date)

        return Button {
            selected = date.startOfDay
        } label: {
            ZStack {
                if isSelected {
                    Circle().fill(Theme.amethyst)
                } else if isToday {
                    Circle().strokeBorder(Theme.magenta.opacity(0.7), lineWidth: 1.5)
                }
                Text("\(dayNumber)")
                    .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.white : Theme.ink)
            }
            .frame(height: 38)
            .overlay(alignment: .bottom) {
                if hasAppointment {
                    Circle()
                        .fill(isSelected ? Color.white : Theme.violet)
                        .frame(width: 5, height: 5)
                        .offset(y: -2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func shiftMonth(_ delta: Int) {
        month = cal.date(byAdding: .month, value: delta, to: month) ?? month
    }

    private func daysInMonth() -> [Date?] {
        let c = cal
        guard let interval = c.dateInterval(of: .month, for: month),
              let range = c.range(of: .day, in: .month, for: month) else { return [] }
        let firstWeekday = c.component(.weekday, from: interval.start)
        let offset = (firstWeekday - c.firstWeekday + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: offset)
        for d in range {
            if let date = c.date(byAdding: .day, value: d - 1, to: interval.start) {
                result.append(date)
            }
        }
        return result
    }

    // Details and booking

    private var bookingDate: Date? {
        let parts = slot.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: selected)
    }

    private var canBook: Bool {
        guard let date = bookingDate else { return false }
        return date > Date() && !types.isEmpty
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Selected Date: \(fmt(selected, "EEEE, d MMMM yyyy"))")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)

            let todays = store.appointmentsOn(selected)
            if todays.isEmpty {
                Text("No appointments on this day yet.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.ink.opacity(0.6))
            } else {
                ForEach(todays) { appointment in
                    appointmentRow(appointment)
                }
            }

            Text("Appointment Type")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.amethyst)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(AppointmentType.all, id: \.self) { type in
                    Button { toggle(type) } label: {
                        Chip(title: type, selected: types.contains(type), expand: true)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Time Slot")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.amethyst)

            HStack(spacing: 8) {
                ForEach(AppointmentType.slots, id: \.self) { s in
                    Button { slot = s } label: {
                        Chip(title: s, selected: slot == s, expand: true)
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField("Location", text: $location)
                .font(.system(size: 15))
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface.opacity(0.75)))

            Button(action: book) {
                Text("+ Book appointment on selected date")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canBook)
            .opacity(canBook ? 1 : 0.45)

            if !canBook {
                Text("Choose a date and time in the future to book.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink.opacity(0.55))
            }
        }
        .glassCard()
    }

    private func appointmentRow(_ appointment: Appointment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(fmt(appointment.date, "HH:mm")) · \(appointment.title)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.leading)
                Text(appointment.location)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 8) {
                Text(appointment.date < Date() ? "Past" : "Scheduled")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.surface.opacity(0.22)))
                Button {
                    store.deleteAppointment(appointment)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.9))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete appointment")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [Theme.amethyst, Theme.violet],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
    }

    private func toggle(_ type: String) {
        if types.contains(type) {
            if types.count > 1 { types.remove(type) }
        } else {
            types.insert(type)
        }
    }

    private func book() {
        guard let date = bookingDate else { return }
        let place = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let ordered = AppointmentType.all.filter { types.contains($0) }
        let appointment = Appointment(date: date, types: ordered, location: place.isEmpty ? "Clinic" : place)
        store.addAppointment(appointment)
    }
}

// MARK: - Journey

struct JourneyScreen: View {
    @EnvironmentObject private var store: Store
    @AppStorage("wellcy.diagnosedTS") private var diagnosedTS = Sample.diagnosed
    @AppStorage("wellcy.surgeryTS") private var surgeryTS = Sample.surgery
    @AppStorage("wellcy.lastTreatmentTS") private var lastTreatmentTS = Sample.lastTreatment
    @AppStorage("wellcy.familyName") private var familyName = Sample.familyName
    @AppStorage("wellcy.shareAppointments") private var shareAppointments = true
    @AppStorage("wellcy.shareMood") private var shareMood = true

    @State private var showImporter = false
    @State private var viewing: Report?
    @State private var showStory = false
    @State private var showLetter = false
    @State private var editingFamily = false
    @State private var familyDraft = ""
    @State private var letterPendingDeletion: Letter?
    @State private var showDeleteLetterConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: "Journey", subtitle: "Every step counts. Look how far you've come.")
                reportsCard
                storyCard
                sharingCard
                lettersSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf]) { result in
            if case .success(let url) = result {
                store.importReport(from: url)
            }
        }
        .sheet(item: $viewing) { report in
            PDFSheet(report: report)
        }
        .sheet(isPresented: $showStory) { StorySheet() }
        .sheet(isPresented: $showLetter) { LetterSheet() }
        .alert("Who do you share with?", isPresented: $editingFamily) {
            TextField("Name", text: $familyDraft)
            Button("Save") {
                familyName = familyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete this letter?",
            isPresented: $showDeleteLetterConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete letter", role: .destructive) {
                if let letterPendingDeletion {
                    store.deleteLetter(letterPendingDeletion)
                }
                letterPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                letterPendingDeletion = nil
            }
        } message: {
            Text("This letter will be removed from your journey.")
        }
    }

    // Reports

    private var reportsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reports collection")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(store.reports.count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.amethyst)
                Spacer()
                Button { showImporter = true } label: {
                    Text("+ Add report")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Theme.amethyst))
                }
                .buttonStyle(.plain)
            }

            if store.reports.isEmpty {
                Text("No reports yet. Add a PDF of your blood tests, scans or doctor's notes to keep everything in one place.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.ink.opacity(0.65))
            } else {
                ForEach(store.reports) { report in
                    HStack(spacing: 12) {
                        Text("PDF")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.amethyst)
                            .frame(width: 38, height: 38)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.orchid))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(report.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Text("Added \(fmt(report.date, "d MMM yyyy"))")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.ink.opacity(0.6))
                        }
                        Spacer()
                        Button { viewing = report } label: {
                            Text("View")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.amethyst)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(Theme.surface.opacity(0.85)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface.opacity(0.55)))
                    .contextMenu {
                        Button(role: .destructive) {
                            store.deleteReport(report)
                        } label: {
                            Label("Delete report", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .glassCard()
    }

    // My story

    private var storyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My story")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button { showStory = true } label: {
                    Text("Edit")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.amethyst)
                }
                .buttonStyle(.plain)
            }
            storyRow("Diagnosed", fmt(Date(timeIntervalSince1970: diagnosedTS), "MMM yyyy"), filled: true)
            storyRow("Surgery", fmt(Date(timeIntervalSince1970: surgeryTS), "MMM yyyy"), filled: true)
            storyRow("Last treatment day", fmt(Date(timeIntervalSince1970: lastTreatmentTS), "d MMM yyyy"), filled: true)
            storyRow("Today", "Getting stronger", filled: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func storyRow(_ title: String, _ detail: String, filled: Bool) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(filled ? Theme.violet : Color.clear)
                .overlay(Circle().strokeBorder(Theme.violet, lineWidth: 2))
                .frame(width: 12, height: 12)
            (Text(title).fontWeight(.semibold) + Text(" · ") + Text(detail))
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink)
        }
    }

    // Family sharing (stored on this device only, no account needed)

    private var sharingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                familyDraft = familyName
                editingFamily = true
            } label: {
                Text(familyName.isEmpty ? "Add a family contact" : "Shared with \(familyName) (family)")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            .buttonStyle(.plain)
            Toggle("Appointments", isOn: $shareAppointments)
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink)
            Toggle("Mood check-ins", isOn: $shareMood)
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink)
        }
        .glassCard()
    }

    // Letters

    private var lettersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Letters to future me")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("Open each letter when you're ready. Opened letters stay until you delete them.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink.opacity(0.65))
            }

            Button { showLetter = true } label: {
                Text("✉ Write a letter to future me")
            }
            .buttonStyle(PrimaryButtonStyle())

            ForEach(store.letters) { letter in
                let canOpen = Calendar.current.startOfDay(for: letter.opensOn)
                    <= Calendar.current.startOfDay(for: Date())

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(letter.isOpened
                                 ? "Opened letter"
                                 : (canOpen ? "Ready when you are" : "Sealed until \(fmt(letter.opensOn, "d MMM yyyy"))"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.amethyst)
                            Text("Written \(fmt(letter.created, "d MMM yyyy"))")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.ink.opacity(0.6))
                        }
                        Spacer(minLength: 4)
                        if letter.isOpened {
                            Button {
                                letterPendingDeletion = letter
                                showDeleteLetterConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.red)
                                    .frame(width: 36, height: 36)
                                    .background(Theme.surface.opacity(0.8), in: Circle())
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete opened letter")
                        }
                    }

                    if letter.isOpened {
                        Text(letter.text)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.ink.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if canOpen {
                        Text("Your chosen day has arrived. Open the letter whenever you feel ready.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.ink.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            store.openLetter(letter)
                        } label: {
                            Label("Open letter", systemImage: "envelope.open")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.amethyst)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(Theme.surface.opacity(0.8)))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("Your letter is sealed and will stay here until you open it.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.ink.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
            }
        }
    }
}

struct PDFSheet: View {
    let report: Report
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PDFKitView(url: Store.fileURL(for: report))
                .navigationTitle(report.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

struct StorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("wellcy.diagnosedTS") private var diagnosedTS = Sample.diagnosed
    @AppStorage("wellcy.surgeryTS") private var surgeryTS = Sample.surgery
    @AppStorage("wellcy.lastTreatmentTS") private var lastTreatmentTS = Sample.lastTreatment

    var body: some View {
        NavigationStack {
            Form {
                Section("Your key dates") {
                    DatePicker("Diagnosed", selection: dateBinding($diagnosedTS), displayedComponents: .date)
                    DatePicker("Surgery", selection: dateBinding($surgeryTS), displayedComponents: .date)
                    DatePicker("Last treatment day", selection: dateBinding($lastTreatmentTS), displayedComponents: .date)
                }
            }
            .navigationTitle("My story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct LetterSheet: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var opensOn = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView()
                VStack(alignment: .leading, spacing: 14) {
                    Text("Write to the person you will be. Your letter stays sealed until the day you choose.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.ink.opacity(0.75))

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $text)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                        if text.isEmpty {
                            Text("Dear future me...")
                                .foregroundStyle(Color.secondary)
                                .padding(.top, 16)
                                .padding(.leading, 13)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(minHeight: 220)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface.opacity(0.75)))

                    DatePicker("Open on", selection: $opensOn,
                               in: Date().addingTimeInterval(86400)...,
                               displayedComponents: .date)
                        .font(.system(size: 15, weight: .semibold))

                    Button {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        store.letters.insert(Letter(text: trimmed, created: Date(), opensOn: opensOn), at: 0)
                        dismiss()
                    } label: {
                        Text("Seal this letter")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Letter to future me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Help now

struct HelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("wellcy.careTeamPhone") private var careTeamPhone = ""
    @AppStorage("wellcy.careTeamPhoneCountryCode") private var careTeamCountryCode = "+39"
    @AppStorage("wellcy.careTeamPhoneCountryName") private var careTeamCountryName = "Italy"
    @State private var breathing = false
    private let timer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    private var emergencyNumber: String {
        switch Locale.current.region?.identifier {
        case "US", "CA": return "911"
        case "GB": return "999"
        case "AU": return "000"
        default: return "112"
        }
    }

    var body: some View {
        ZStack {
            BackgroundView()
            ScrollView {
                VStack(spacing: 18) {
                    Text("You are not alone")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 28)

                    Text("Take a slow breath. Whatever you are feeling right now is okay.")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.ink.opacity(0.75))
                        .multilineTextAlignment(.center)

                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Theme.violet, Theme.magenta.opacity(0.7)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 190, height: 190)
                            .scaleEffect(breathing ? 1.0 : 0.6)
                            .opacity(breathing ? 0.9 : 0.55)
                        Text(breathing ? "Breathe in" : "Breathe out")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white)
                    }
                    .frame(height: 200)

                    Button { call(emergencyNumber) } label: {
                        Text("Call emergency services (\(emergencyNumber))")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your care team")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Picker("Country code", selection: $careTeamCountryName) {
                            ForEach(PhoneCountry.all) { country in
                                Text("\(country.flag) \(country.name) (\(country.code))")
                                    .tag(country.name)
                            }
                        }
                        .onChange(of: careTeamCountryName) { _, name in
                            careTeamCountryCode = PhoneCountry.all.first(where: { $0.name == name })?.code ?? "+39"
                        }
                        TextField("Care team phone number", text: $careTeamPhone)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .onChange(of: careTeamPhone) { _, value in
                                let digits = value.filter(\.isNumber)
                                if digits != value {
                                    careTeamPhone = digits
                                }
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface.opacity(0.8)))
                        Button { call("\(careTeamCountryCode)\(careTeamPhone)") } label: {
                            Text("Call my care team")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(careTeamPhone.isEmpty)
                        .opacity(careTeamPhone.isEmpty ? 0.45 : 1)
                    }
                    .glassCard()

                    Text("If you are thinking about hurting yourself, please call your local emergency number or a crisis line in your country right now, or tell someone near you.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 6)

                    Button("Close") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            if careTeamPhone.hasPrefix("+") {
                let digits = careTeamPhone.filter(\.isNumber)
                let matchingCountry = PhoneCountry.all
                    .sorted { $0.code.count > $1.code.count }
                    .first { digits.hasPrefix($0.code.filter(\.isNumber)) }
                if let matchingCountry {
                    careTeamCountryCode = matchingCountry.code
                    careTeamCountryName = matchingCountry.name
                    careTeamPhone = String(digits.dropFirst(matchingCountry.code.filter(\.isNumber).count))
                } else {
                    careTeamPhone = digits
                }
            } else {
                careTeamPhone = careTeamPhone.filter(\.isNumber)
            }
            withAnimation(.easeInOut(duration: 4)) { breathing = true }
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 4)) { breathing.toggle() }
        }
    }

    private func call(_ number: String) {
        let digits = number.filter { "+0123456789".contains($0) }
        guard !digits.isEmpty, let url = URL(string: "tel://\(digits)") else { return }
        openURL(url)
    }
}

// MARK: - Ask Wellcy (offline guided helper)

struct ChatMessage: Identifiable {
    let id = UUID()
    let isUser: Bool
    let text: String
}

/// Simple offline helper. To use a real AI model later, replace `reply(to:)` with a call
/// to your own server. Never put an API key inside the app.
enum Assistant {
    static let suggestions = [
        "What should I ask at my next visit?",
        "I feel very tired",
        "I feel anxious",
        "When should I call my care team?"
    ]

    static func reply(to text: String) -> String {
        let t = text.lowercased()
        func has(_ words: [String]) -> Bool { words.contains { t.contains($0) } }

        if has(["suicide", "kill myself", "end my life", "hurt myself", "want to die"]) {
            return "I am really sorry you are hurting this much. You deserve support right now. Please call your local emergency number or a crisis line in your country, or tap Help now on the home screen. If you can, tell someone near you how you feel."
        }
        if has(["fever", "temperature", "chills"]) {
            return "A fever during treatment can be serious. If your temperature is 38 C (100.4 F) or higher, or you have chills and feel unwell, call your care team or emergency services right away. Do not wait for your next appointment."
        }
        if has(["short of breath", "cannot breathe", "can't breathe", "trouble breathing", "difficulty breathing", "chest pain", "bleeding", "faint"]) {
            return "Those symptoms can be urgent. Please call emergency services now."
        }
        if has(["when should i call", "when to call", "call my care team", "call my doctor"]) {
            return "Call your care team if you have a fever of 38 C (100.4 F) or higher, vomiting or diarrhoea that will not stop, you cannot keep fluids down, new pain, bleeding, or anything that worries you. If you are unsure, it is always okay to call. Ask them which number to use out of hours."
        }
        if has(["nausea", "vomit", "sick", "queasy"]) {
            return "Feeling sick is common during treatment, and there are medicines that help. Small plain meals and slow sips of fluid can be easier. Tell your care team, they can adjust your anti-sickness medicine. Call them if you cannot keep fluids down for 24 hours."
        }
        if has(["tired", "fatigue", "exhaust", "no energy"]) {
            return "Tiredness is one of the most common effects. Short rests, gentle walks and a steady routine can help. Log it in your Daily Check-in so you can show your doctor the pattern, and mention it at your next visit."
        }
        if has(["anxious", "anxiety", "worried", "scared", "afraid", "fear", "stress", "panic"]) {
            return "What you feel is understandable, and you are not alone. Try breathing in for 4 and out for 6, a few times. If the worry stays heavy, tell your care team. Many centres have counsellors for exactly this."
        }
        if has(["sleep", "insomnia", "cannot sleep", "can't sleep"]) {
            return "Try to keep wake and sleep times steady, dim screens an hour before bed, and write worries down earlier in the day. If poor sleep goes on for several nights, mention it to your care team."
        }
        if has(["appointment", "visit", "question", "doctor", "ask"]) {
            return "Before a visit: write your top three questions, list new symptoms with dates (your check-in log helps), and bring someone to listen and take notes if you can. Good questions: What should I expect in the next few weeks? Which symptoms mean I should call you? Who do I call out of hours?"
        }
        if ["hi", "hello", "hey", "hi!", "hello!"].contains(t) {
            return "Hello, I am glad you are here. How can I help today?"
        }
        return "I can explain things in plain language, help you prepare questions for visits, and share ideas for everyday comfort. I cannot give medical advice, so for anything about your treatment or symptoms please check with your care team."
    }
}

struct AskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var messages: [ChatMessage] = [
        ChatMessage(isUser: false,
                    text: "Hi, I am Wellcy. I can explain things in plain language and help you prepare questions for your care team. I give general information only, not medical advice.")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView()
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(messages) { message in
                                    bubble(message).id(message.id)
                                }
                                if messages.count == 1 {
                                    suggestionList
                                }
                            }
                            .padding(16)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: messages.count) { _, _ in
                            if let last = messages.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        TextField("Ask a question...", text: $input)
                            .padding(12)
                            .background(Capsule().fill(Theme.surface.opacity(0.85)))
                            .submitLabel(.send)
                            .onSubmit { send(input) }
                        Button { send(input) } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(Theme.amethyst)
                        }
                        .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(12)
                }
            }
            .navigationTitle("Ask Wellcy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Assistant.suggestions, id: \.self) { s in
                Button { send(s) } label: {
                    Text(s)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.amethyst)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Theme.surface.opacity(0.85)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 6)
    }

    private func bubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.isUser { Spacer(minLength: 40) }
            Text(message.text)
                .font(.system(size: 15))
                .foregroundStyle(message.isUser ? Color.white : Theme.ink)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(message.isUser ? Theme.amethyst : Color.white.opacity(0.85))
                )
            if !message.isUser { Spacer(minLength: 40) }
        }
    }

    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(ChatMessage(isUser: true, text: trimmed))
        messages.append(ChatMessage(isUser: false, text: Assistant.reply(to: trimmed)))
        input = ""
    }
}
