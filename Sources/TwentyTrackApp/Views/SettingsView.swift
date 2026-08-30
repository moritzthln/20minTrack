import Combine
import SwiftUI
import TwentyCore

/// Labels, check-in behavior, login item, data folder.
struct SettingsView: View {
    let preferences: Preferences

    @State private var labels: [TrackLabel] = []
    @State private var newLabelName = ""
    @State private var newLabelColor = "pink"
    @State private var chimeVolume = 0.5
    @State private var autoOpen = true
    @State private var trackingPaused = false
    @State private var suppressFocus = true
    @State private var fazitEnabled = true
    @State private var fazitMinute = 1290
    @State private var absences: [Absence] = []
    @State private var newAbsenceName = loc("Urlaub", "Vacation")
    @State private var newAbsenceStart = Date()
    @State private var newAbsenceEnd = Date()
    @State private var loginEnabled = false
    @State private var loginStatus = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                labelsSection
                checkinSection
                absenceSection
                generalSection
            }
            .padding(16)
        }
        .frame(width: 380, height: 560)
        .onAppear(perform: load)
        // Keep in sync when e.g. the popover menu toggles the pause.
        .onReceive(
            NotificationCenter.default.publisher(for: .trackerSettingsChanged)
        ) { _ in load() }
    }

    // MARK: - Labels

    private var labelsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(loc("Labels", "Labels"))
            ForEach(labels.filter { !$0.archived }) { label in
                labelRow(label)
            }
            HStack(spacing: 8) {
                colorMenu(selection: $newLabelColor)
                TextField(loc("Neues Label…", "New label…"), text: $newLabelName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addLabel)
                Button(action: addLabel) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .disabled(newLabelName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text(loc("Archivierte Labels verschwinden aus der Auswahl; alte Einträge behalten Name und Farbe.", "Archived labels disappear from the pickers; old entries keep their name and color."))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func labelRow(_ label: TrackLabel) -> some View {
        HStack(spacing: 8) {
            colorMenu(selection: Binding(
                get: { label.colorKey },
                set: { newKey in
                    var updated = label
                    updated.colorKey = newKey
                    persist(updated)
                }
            ))
            TextField(loc("Name", "Name"), text: Binding(
                get: { label.name },
                set: { newName in
                    var updated = label
                    updated.name = newName
                    // updateLabel ignores empty names, the draft keeps the
                    // typing state — clearing and retyping works smoothly.
                    persist(updated)
                }
            ))
            .textFieldStyle(.roundedBorder)
            goalField(for: label)
            Button {
                preferences.archiveLabel(id: label.id)
                load()
                notifyChanged()
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .help(loc("Label archivieren", "Archive label"))
            .disabled(labels.filter { !$0.archived }.count <= 1)
        }
    }

    private func colorMenu(selection: Binding<String>) -> some View {
        Menu {
            ForEach(TrackLabel.paletteKeys, id: \.self) { key in
                Button {
                    selection.wrappedValue = key
                } label: {
                    HStack {
                        Image(systemName: selection.wrappedValue == key ? "largecircle.fill.circle" : "circle.fill")
                        Text(key)
                    }
                    .foregroundStyle(LabelPalette.color(for: key))
                }
            }
        } label: {
            Circle()
                .fill(LabelPalette.color(for: selection.wrappedValue))
                .frame(width: 14, height: 14)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    /// Daily minimum goal as hours + minutes — both empty = no goal.
    private func goalField(for label: TrackLabel) -> some View {
        let goal = label.goalMinutes ?? 0
        return HStack(spacing: 3) {
            TextField("0", text: Binding(
                get: { label.goalMinutes.map { String($0 / 60) } ?? "" },
                set: { raw in
                    let hours = min(Int(raw.filter(\.isNumber)) ?? 0, 24)
                    setGoal(label, minutes: hours * 60 + goal % 60)
                }
            ))
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .frame(width: 34)
            Text("h")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("0", text: Binding(
                get: { label.goalMinutes.map { String($0 % 60) } ?? "" },
                set: { raw in
                    let minutes = min(Int(raw.filter(\.isNumber)) ?? 0, 59)
                    setGoal(label, minutes: (goal / 60) * 60 + minutes)
                }
            ))
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .frame(width: 34)
            Text("min")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .help(loc("Tagesziel (leer = kein Ziel) — Statistik zeigt ✓ bei Erreichen, Woche ×7", "Daily goal (empty = none) — statistics show ✓ when reached, week ×7"))
    }

    private func setGoal(_ label: TrackLabel, minutes: Int) {
        var updated = label
        updated.goalMinutes = minutes > 0 ? min(minutes, 1440) : nil
        persist(updated)
    }

    private func addLabel() {
        guard preferences.addLabel(name: newLabelName, colorKey: newLabelColor) != nil else { return }
        newLabelName = ""
        load()
        notifyChanged()
    }

    /// Persists rename/recolor and mirrors the typed value into the local
    /// draft. No notification and no disk-reload per keystroke — other
    /// views pick labels up on their next reload.
    private func persist(_ label: TrackLabel) {
        preferences.updateLabel(label)
        labels = labels.map { $0.id == label.id ? label : $0 }
    }

    // MARK: - Check-in

    private var checkinSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(loc("Check-in", "Check-in"))
            Toggle(loc("Check-in-Fenster automatisch öffnen", "Open check-in window automatically"), isOn: Binding(
                get: { autoOpen },
                set: { value in
                    autoOpen = value
                    preferences.autoOpenPopover = value
                    notifyChanged()
                }
            ))
            HStack {
                Text(loc("Ton", "Sound"))
                Slider(value: Binding(
                    get: { chimeVolume },
                    set: { value in
                        chimeVolume = value
                        preferences.chimeVolume = value
                    }
                ), in: 0...1)
                Button(loc("Test", "Test")) { SoundPlayer.playChime(volume: preferences.chimeVolume) }
                    .buttonStyle(PillButtonStyle())
            }
            Toggle(loc("Bei macOS-Fokus keine Meldungen", "No prompts during macOS Focus"), isOn: Binding(
                get: { suppressFocus },
                set: { value in
                    suppressFocus = value
                    preferences.suppressDuringFocus = value
                }
            ))
            HStack {
                Toggle(loc("Abends ans Tagesfazit erinnern", "Evening reminder for the daily review"), isOn: Binding(
                    get: { fazitEnabled },
                    set: { value in
                        fazitEnabled = value
                        preferences.fazitPromptEnabled = value
                    }
                ))
                Picker("", selection: Binding(
                    get: { fazitMinute },
                    set: { value in
                        fazitMinute = value
                        preferences.fazitPromptMinute = value
                    }
                )) {
                    ForEach(Array(stride(from: 18 * 60, through: 23 * 60 + 45, by: 15)), id: \.self) { minute in
                        Text(String(format: "%02d:%02d", minute / 60, minute % 60)).tag(minute)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .disabled(!fazitEnabled)
            }
            Toggle(loc("Tracking pausieren", "Pause tracking"), isOn: Binding(
                get: { trackingPaused },
                set: { value in
                    trackingPaused = value
                    preferences.trackingPaused = value
                    notifyChanged()
                }
            ))
        }
    }

    // MARK: - Absence

    private var absenceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(loc("Abwesenheit", "Absence"))
            ForEach(absences) { absence in
                HStack(spacing: 8) {
                    Text(absence.name)
                        .lineLimit(1)
                    Spacer()
                    Text(absenceRange(absence))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Button {
                        preferences.removeAbsence(id: absence.id)
                        load()
                        notifyChanged()
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                    .help(loc("Abwesenheit löschen", "Delete absence"))
                }
            }
            HStack(spacing: 6) {
                TextField(loc("Name", "Name"), text: $newAbsenceName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                DatePicker("", selection: $newAbsenceStart, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
                Text("–")
                DatePicker("", selection: $newAbsenceEnd, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
                Button {
                    // Localized fallback here — Core's own fallback is German.
                    let trimmed = newAbsenceName.trimmingCharacters(in: .whitespaces)
                    preferences.addAbsence(
                        name: trimmed.isEmpty ? loc("Abwesend", "Away") : trimmed,
                        startDay: newAbsenceStart, endDay: newAbsenceEnd
                    )
                    load()
                    notifyChanged()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
            }
            Text(loc("An diesen Tagen: keine Check-in-Fenster, Lücken zählen nicht als Ablenkung, und nach der Rückkehr wird die Abwesenheit nicht abgefragt.", "On these days: no check-in windows, gaps never count as distraction, and the return check-in skips the absence."))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func absenceRange(_ absence: Absence) -> String {
        let formatter = DateFormatter()
        formatter.locale = l10nLocale
        formatter.dateFormat = loc("d.M.", "M/d")
        return "\(formatter.string(from: absence.startDay)) – \(formatter.string(from: absence.endDay))"
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(loc("Allgemein", "General"))
            HStack(spacing: 8) {
                Toggle(loc("Beim Anmelden starten", "Launch at login"), isOn: Binding(
                    get: { loginEnabled },
                    set: { value in
                        LaunchAtLogin.setEnabled(value)
                        loginEnabled = LaunchAtLogin.isEnabled
                        loginStatus = LaunchAtLogin.statusDescription
                    }
                ))
                Text(loginStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button(loc("Datenordner im Finder zeigen", "Show data folder in Finder")) {
                NSWorkspace.shared.activateFileViewerSelecting([DayStore.defaultDirectory()])
            }
            .buttonStyle(PillButtonStyle())
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private func load() {
        labels = preferences.labels
        chimeVolume = preferences.chimeVolume
        autoOpen = preferences.autoOpenPopover
        trackingPaused = preferences.trackingPaused
        suppressFocus = preferences.suppressDuringFocus
        fazitEnabled = preferences.fazitPromptEnabled
        fazitMinute = preferences.fazitPromptMinute
        absences = preferences.absences
        loginEnabled = LaunchAtLogin.isEnabled
        loginStatus = LaunchAtLogin.statusDescription
    }

    private func notifyChanged() {
        NotificationCenter.default.post(name: .trackerSettingsChanged, object: nil)
    }
}
