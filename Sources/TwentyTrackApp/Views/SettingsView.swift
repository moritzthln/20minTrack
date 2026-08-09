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
    @State private var loginEnabled = false
    @State private var loginStatus = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                labelsSection
                checkinSection
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
            sectionTitle("Labels")
            ForEach(labels.filter { !$0.archived }) { label in
                labelRow(label)
            }
            HStack(spacing: 8) {
                colorMenu(selection: $newLabelColor)
                TextField("Neues Label…", text: $newLabelName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addLabel)
                Button(action: addLabel) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .disabled(newLabelName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text("Archivierte Labels verschwinden aus der Auswahl; alte Einträge behalten Name und Farbe.")
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
            TextField("Name", text: Binding(
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
            Button {
                preferences.archiveLabel(id: label.id)
                load()
                notifyChanged()
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .help("Label archivieren")
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
            sectionTitle("Check-in")
            Toggle("Popover automatisch öffnen", isOn: Binding(
                get: { autoOpen },
                set: { value in
                    autoOpen = value
                    preferences.autoOpenPopover = value
                    notifyChanged()
                }
            ))
            HStack {
                Text("Ton")
                Slider(value: Binding(
                    get: { chimeVolume },
                    set: { value in
                        chimeVolume = value
                        preferences.chimeVolume = value
                    }
                ), in: 0...1)
                Button("Test") { SoundPlayer.playChime(volume: preferences.chimeVolume) }
                    .buttonStyle(PillButtonStyle())
            }
            Toggle("Tracking pausieren", isOn: Binding(
                get: { trackingPaused },
                set: { value in
                    trackingPaused = value
                    preferences.trackingPaused = value
                    notifyChanged()
                }
            ))
        }
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Allgemein")
            HStack(spacing: 8) {
                Toggle("Beim Anmelden starten", isOn: Binding(
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
            Button("Datenordner im Finder zeigen") {
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
        loginEnabled = LaunchAtLogin.isEnabled
        loginStatus = LaunchAtLogin.statusDescription
    }

    private func notifyChanged() {
        NotificationCenter.default.post(name: .trackerSettingsChanged, object: nil)
    }
}
