import SwiftUI
import AppKit

// MARK: - Theme

struct T {
    static let bg       = Color(hex: "0e0e0e")
    static let panel    = Color(hex: "161616")
    static let surface  = Color(hex: "1f1f1f")
    static let surface2 = Color(hex: "272727")
    static let border   = Color(hex: "333333")
    static let gold     = Color(hex: "e8c96a")
    static let goldDk   = Color(hex: "c9a84c")
    static let text     = Color(hex: "f5f0e8")
    static let textMid  = Color(hex: "b8b0a0")
    static let textDim  = Color(hex: "5a5650")
    static let ok       = Color(hex: "6ed68a")
    static let err      = Color(hex: "e06868")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(T.textMid)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(configuration.isPressed ? T.surface2 : Color.clear)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(T.border, lineWidth: 1))
    }
}

// MARK: - SelectableLogView

struct SelectableLogView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let sv = NSScrollView()
        let tv = NSTextView()
        tv.isEditable                         = false
        tv.isSelectable                       = true
        tv.backgroundColor                    = .clear
        tv.drawsBackground                    = false
        tv.textContainerInset                 = NSSize(width: 8, height: 8)
        tv.font                               = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        tv.textColor                          = NSColor(T.textMid)
        tv.isVerticallyResizable              = true
        tv.isHorizontallyResizable            = false
        tv.autoresizingMask                   = [.width]
        tv.textContainer?.widthTracksTextView = true
        sv.documentView                       = tv
        sv.hasVerticalScroller                = true
        sv.drawsBackground                    = false
        return sv
    }

    func updateNSView(_ sv: NSScrollView, context: Context) {
        guard let tv = sv.documentView as? NSTextView else { return }
        // Only update if text actually changed — avoids flicker on unrelated SwiftUI redraws
        guard tv.string != text else { return }
        // Preserve scroll position: only auto-scroll if already near bottom
        let visibleBottom = sv.contentView.bounds.maxY
        let totalHeight   = tv.frame.height
        let nearBottom    = totalHeight - visibleBottom < 60

        tv.string = text

        if nearBottom {
            tv.scrollToEndOfDocument(nil)
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    @ObservedObject var queue: TranscriptionQueue

    @State private var selectedModel    = whisperModels[0]
    @State private var selectedLanguage = languages.first { $0.id == "auto" } ?? languages[0]
    @State private var selectedOutput   = OutputMode.original
    @State private var selectedFormat   = "srt"
    @State private var outputDir        = FileManager.default.homeDirectoryForCurrentUser
                                            .appendingPathComponent("Downloads")
    @State private var isDragging       = false
    @State private var showAdvanced     = false
    @State private var advancedParams   = AdvancedParams.forLanguage("en")

    var body: some View {
        HStack(spacing: 0) {
            leftPanel
            Divider().background(T.border)
            rightPanel
        }
        .background(T.bg)
        .preferredColorScheme(.dark)
    }

    // MARK: Left Panel

    var leftPanel: some View {
        VStack(spacing: 0) {
            appHeader
            Divider().background(T.border)
            ScrollView { settingsSection }
            Divider().background(T.border)
            bottomBar
        }
        .frame(width: 280)
        .background(T.panel)
    }

    var appHeader: some View {
        HStack(spacing: 0) {
            Text("Whisper").font(.system(size: 18, weight: .light, design: .serif)).italic().foregroundColor(T.gold)
            Text("Transcribe").font(.system(size: 18, weight: .bold)).foregroundColor(T.text)
            Spacer()
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
    }

    var settingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: Model
            sectionHeader(tr("MODELLO", "MODEL"))
            Menu {
                ForEach(whisperModels) { m in
                    Button(action: { selectedModel = m }) {
                        Text("\(m.label)  ·  \(m.description)  ·  \(m.ramLabel)")
                    }
                }
            } label: {
                menuLabel("\(selectedModel.label)  ·  \(selectedModel.description)")
            }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden)
            .padding(.horizontal, 18).padding(.bottom, 8)

            // MARK: Language (spoken audio)
            sectionHeader(tr("LINGUA AUDIO", "AUDIO LANGUAGE"))
            Menu {
                ForEach(languages) { l in
                    Button(action: { selectedLanguage = l }) { Text(l.name) }
                }
            } label: {
                menuLabel(selectedLanguage.name)
            }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden)
            .padding(.horizontal, 18).padding(.bottom, 8)

            // MARK: Output language (transcribe vs translate-to-English)
            sectionHeader(tr("LINGUA OUTPUT", "OUTPUT LANGUAGE"))
            HStack(spacing: 6) {
                ForEach(OutputMode.allCases) { mode in
                    Button(action: { selectedOutput = mode }) {
                        Text(mode.label)
                            .font(.system(size: 10, weight: .bold))
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                            .background(selectedOutput == mode ? T.gold : T.surface2)
                            .foregroundColor(selectedOutput == mode ? .black : T.textMid)
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 4)
            Text(selectedOutput == .original
                 ? tr("Sottotitoli nella lingua parlata.", "Subtitles in the spoken language.")
                 : tr("Traduce i sottotitoli in inglese.", "Translates subtitles into English."))
                .font(.system(size: 9)).foregroundColor(T.textDim)
                .padding(.horizontal, 18).padding(.bottom, 4)

            // MARK: Format
            sectionHeader(tr("FORMATO OUTPUT", "OUTPUT FORMAT"))
            HStack(spacing: 6) {
                ForEach(outputFormats, id: \.self) { fmt in
                    Button(action: { selectedFormat = fmt }) {
                        Text(fmt.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                            .background(selectedFormat == fmt ? T.gold : T.surface2)
                            .foregroundColor(selectedFormat == fmt ? .black : T.textMid)
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 8)

            // MARK: Output folder
            sectionHeader(tr("CARTELLA OUTPUT", "OUTPUT FOLDER"))
            Button(action: pickOutputDir) {
                HStack {
                    Text(outputDir.lastPathComponent)
                        .font(.system(size: 11)).foregroundColor(T.text)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Image(systemName: "folder").font(.system(size: 11)).foregroundColor(T.gold)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(T.surface2).cornerRadius(6)
            }
            .buttonStyle(.plain).padding(.horizontal, 18).padding(.bottom, 8)
            .onChange(of: outputDir) { _, newDir in
                // Update all waiting jobs with the new output directory
                for job in queue.jobs where job.status == .waiting {
                    job.outputDir = newDir.standardizedFileURL
                }
            }

            // MARK: Advanced settings
            Button(action: { showAdvanced = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 11))
                    Text(tr("Impostazioni avanzate", "Advanced settings")).font(.system(size: 11))
                    Spacer()
                    if advancedParams.isModified {
                        Circle().fill(T.gold).frame(width: 6, height: 6)
                    }
                    Image(systemName: "chevron.right").font(.system(size: 10))
                }
                .foregroundColor(advancedParams.isModified ? T.gold : T.textDim)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(T.surface2).cornerRadius(6)
            }
            .buttonStyle(.plain).padding(.horizontal, 18).padding(.bottom, 20)
        }
        .sheet(isPresented: $showAdvanced) {
            AdvancedSettingsView(params: $advancedParams, languageID: selectedLanguage.id)
        }
        .onChange(of: selectedLanguage) { _, lang in
            if !advancedParams.isModified {
                advancedParams = AdvancedParams.forLanguage(lang.id)
            }
        }
    }

    func menuLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 11)).foregroundColor(T.text)
                .lineLimit(1).truncationMode(.middle)
            Spacer()
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 10)).foregroundColor(T.gold)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(T.surface2).cornerRadius(6)
        .contentShape(Rectangle())
    }

    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .bold)).foregroundColor(T.textDim).tracking(1.5)
            .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 4)
    }

    func pickOutputDir() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories  = true
        panel.canChooseFiles        = false
        panel.allowsMultipleSelection = false
        panel.prompt                = tr("Seleziona", "Select")
        // Ensure we can access the selected folder outside sandbox
        panel.allowedContentTypes   = []
        if panel.runModal() == .OK, let url = panel.url {
            // Resolve symlinks and get canonical path
            let resolved = url.resolvingSymlinksInPath()
            outputDir = resolved
        }
    }

    // MARK: Bottom Bar

    var bottomBar: some View {
        VStack(spacing: 8) {
            // Status
            HStack(spacing: 6) {
                Circle()
                    .fill(queue.envReady ? T.ok : T.gold)
                    .frame(width: 6, height: 6)
                Text(queue.envStatus)
                    .font(.system(size: 10)).foregroundColor(T.textDim)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 18)

            // Add files button
            Button(action: addFiles) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text(tr("Aggiungi file", "Add files"))
                }
                .font(.system(size: 12, weight: .semibold)).foregroundColor(T.gold)
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(T.surface).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(T.gold.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain).padding(.horizontal, 18)

            // Start/Stop
            if !queue.jobs.isEmpty {
                Button(action: { queue.isRunning ? queue.stopQueue() : queue.startQueue() }) {
                    HStack(spacing: 6) {
                        Image(systemName: queue.isRunning ? "stop.fill" : "play.fill")
                        Text(queue.isRunning ? tr("Ferma", "Stop") : tr("Avvia Coda", "Start Queue"))
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(queue.isRunning ? .white : .black)
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(queue.isRunning ? T.err : T.gold)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain).padding(.horizontal, 18)
            }
        }
        .padding(.vertical, 12)
        .background(T.panel)
    }

    func addFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        let types = ["mp4","mov","mkv","avi","m4v","mp3","m4a","wav","flac","aac","ogg","opus","aiff"]
        panel.allowedContentTypes = types.compactMap { UTType(filenameExtension: $0) }
        if panel.runModal() == .OK {
            queue.addJobs(panel.urls, outputDir: outputDir.standardizedFileURL,
                          language: selectedLanguage, model: selectedModel,
                          format: selectedFormat, outputMode: selectedOutput,
                          params: advancedParams)
        }
    }

    // MARK: Right Panel

    var rightPanel: some View {
        VStack(spacing: 0) {
            // Global progress bar
            if !queue.jobs.isEmpty {
                globalProgressBar
                Divider().background(T.border)
            }

            // Drop zone or job list
            if queue.jobs.isEmpty {
                dropZone
            } else {
                jobList
            }

            Divider().background(T.border)
            logPanel
        }
        .background(T.bg)
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            Task {
                var urls: [URL] = []
                for p in providers {
                    if let url = try? await p.loadItem(forTypeIdentifier: "public.file-url") as? URL {
                        urls.append(url)
                    } else if let data = try? await p.loadItem(forTypeIdentifier: "public.file-url") as? Data,
                              let url = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(url)
                    }
                }
                if !urls.isEmpty {
                    queue.addJobs(urls, outputDir: outputDir,
                                  language: selectedLanguage, model: selectedModel,
                                  format: selectedFormat, outputMode: selectedOutput,
                                  params: advancedParams)
                }
            }
            return true
        }
    }

    var globalProgressBar: some View {
        let done    = queue.jobs.filter { $0.status == .done || $0.status == .failed }.count
        let total   = queue.jobs.count
        let pct     = queue.globalProgress
        let allDone = done == total && total > 0

        return HStack(spacing: 10) {
            Text("\(done)/\(total) job").font(.system(size: 10, design: .monospaced)).foregroundColor(T.textDim)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(T.surface2).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(allDone ? T.ok : T.gold)
                        .frame(width: geo.size.width * pct, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: pct)
                }
            }
            .frame(height: 6)
            Text("\(Int(pct * 100))%").font(.system(size: 10, design: .monospaced)).foregroundColor(T.textDim)
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(T.panel)
    }

    var dropZone: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.badge.plus")
                .font(.system(size: 48)).foregroundColor(isDragging ? T.gold : T.textDim)
            Text(tr("Trascina qui i file audio o video", "Drag audio or video files here"))
                .font(.system(size: 14)).foregroundColor(T.textDim)
            Text(tr("mp4 · mov · mkv · mp3 · wav · m4a · flac · aac e altri", "mp4 · mov · mkv · mp3 · wav · m4a · flac · aac and more"))
                .font(.system(size: 11)).foregroundColor(T.textDim.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isDragging ? T.gold.opacity(0.05) : T.bg)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isDragging ? T.gold : T.border, lineWidth: isDragging ? 2 : 1)
                .padding(16)
        )
        .animation(.easeInOut(duration: 0.15), value: isDragging)
    }

    var jobList: some View {
        List {
            ForEach(queue.jobs) { job in
                JobRow(job: job) { queue.removeJob(job) }
                    .listRowBackground(T.surface.opacity(0.5))
                    .listRowSeparatorTint(T.border)
            }
        }
        .listStyle(.plain)
        .background(T.bg)
        .scrollContentBackground(.hidden)
    }

    var logPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("LOG").font(.system(size: 9, weight: .bold)).foregroundColor(T.textDim).tracking(1.5)
                Spacer()
                Button(tr("Copia", "Copy")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(queue.globalLog, forType: .string)
                }
                .buttonStyle(GhostButtonStyle())
                if !queue.jobs.isEmpty {
                    Button(tr("Pulisci completati", "Clear completed")) { queue.clearCompleted() }
                        .buttonStyle(GhostButtonStyle())
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(T.panel)

            SelectableLogView(text: queue.globalLog)
                .frame(height: 160)
                .background(T.surface.opacity(0.3))
        }
    }
}

// MARK: - JobRow

struct JobRow: View {
    @ObservedObject var job: TranscriptionJob
    let onRemove: () -> Void

    var statusColor: Color {
        switch job.status {
        case .waiting:  return T.textDim
        case .running:  return T.gold
        case .done:     return T.ok
        case .failed:   return T.err
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(job.fileName)
                    .font(.system(size: 11, weight: .medium)).foregroundColor(T.text)
                    .lineLimit(1).truncationMode(.middle)
                HStack(spacing: 6) {
                    Text(job.status.label).font(.system(size: 10)).foregroundColor(statusColor)
                    if !job.elapsed.isEmpty {
                        Text("·").foregroundColor(T.textDim)
                        Text(job.elapsed).font(.system(size: 10)).foregroundColor(T.textDim)
                    }
                }
            }

            Spacer()

            if job.status == .running {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(Int(job.progress * 100))%")
                        .font(.system(size: 10, design: .monospaced)).foregroundColor(T.gold)
                    ProgressView(value: job.progress)
                        .progressViewStyle(.linear).tint(T.gold).frame(width: 60)
                }
            } else if job.status == .done, let url = job.outputURL {
                Button(action: { NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "") }) {
                    Image(systemName: "arrow.down.circle").font(.system(size: 16)).foregroundColor(T.ok)
                }
                .buttonStyle(.plain)
            } else if job.status == .waiting {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle").font(.system(size: 14)).foregroundColor(T.textDim)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - UTType extension

import UniformTypeIdentifiers
extension UTType {
    init?(filenameExtension ext: String) {
        if let type = UTType(tag: ext, tagClass: .filenameExtension, conformingTo: nil) {
            self = type
        } else { return nil }
    }
}
