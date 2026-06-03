import SwiftUI
import AppKit

// MARK: - System Info

struct SystemInfo {
    static var isAppleSilicon: Bool {
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = withUnsafeBytes(of: &sysinfo.machine) { ptr in
            String(cString: ptr.baseAddress!.assumingMemoryBound(to: CChar.self))
        }
        return machine.hasPrefix("arm")
    }
    static var ramGB: Int {
        var size = UInt64(0); var len = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &size, &len, nil, 0)
        return Int(size / 1_073_741_824)
    }
    static var hasBrew: Bool {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].contains { FileManager.default.fileExists(atPath: $0) }
    }
    static var hasPython: Bool {
        ["/opt/homebrew/bin/python3", "/usr/local/bin/python3"].contains { FileManager.default.fileExists(atPath: $0) }
    }
    static var hasFfmpeg: Bool {
        ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"].contains { FileManager.default.fileExists(atPath: $0) }
    }
    static var hasMlxWhisper: Bool {
        FileManager.default.fileExists(atPath: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("whisper-env-mlx/bin/mlx_whisper").path)
    }
}

// MARK: - SetupView

struct SetupView: View {
    let onComplete: () -> Void
    @State private var isInstalling  = false
    @State private var installLog    = ""
    @State private var brewOK        = SystemInfo.hasBrew
    @State private var pythonOK      = SystemInfo.hasPython
    @State private var ffmpegOK      = SystemInfo.hasFfmpeg
    @State private var mlxOK         = SystemInfo.hasMlxWhisper

    var allReady: Bool { brewOK && pythonOK && ffmpegOK && mlxOK }

    var body: some View {
        ZStack { T.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header
                HStack {
                    HStack(spacing: 0) {
                        Text("Whisper").font(.system(size: 22, weight: .light, design: .serif)).italic().foregroundColor(T.gold)
                        Text("Transcribe").font(.system(size: 22, weight: .bold)).foregroundColor(T.text)
                    }
                    Spacer()
                    Text("Setup").font(.system(size: 12, design: .monospaced)).foregroundColor(T.textDim)
                }
                .padding(.horizontal, 28).padding(.vertical, 18)
                Divider().background(T.border)

                ScrollView {
                    VStack(spacing: 20) {
                        if !SystemInfo.isAppleSilicon {
                            blockedView
                        } else {
                            hardwareWarning
                            ramCard
                            depsSection
                            if !allReady { actionSection }
                            if !installLog.isEmpty { logSection }
                        }
                    }
                    .padding(28)
                }

                if SystemInfo.isAppleSilicon {
                    Divider().background(T.border)
                    VStack(spacing: 8) {
                        HStack {
                            if allReady {
                                Label(tr("Tutto pronto", "All set"), systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 12)).foregroundColor(T.ok)
                            } else {
                                Text(tr("Installa le dipendenze per continuare", "Install the dependencies to continue"))
                                    .font(.system(size: 12)).foregroundColor(T.textDim)
                            }
                            Spacer()
                            Button(tr("Aggiorna", "Refresh")) { checkAll() }.buttonStyle(GhostButtonStyle()).padding(.trailing, 8)
                            Button(action: onComplete) {
                                Text(allReady ? tr("Apri WhisperTranscribe", "Open WhisperTranscribe") : tr("Continua comunque", "Continue anyway"))
                                    .font(.system(size: 13, weight: .bold)).foregroundColor(.black)
                                    .padding(.horizontal, 20).padding(.vertical, 9)
                                    .background(allReady ? T.gold : T.surface2)
                                    .foregroundColor(allReady ? .black : T.textMid)
                                    .cornerRadius(8)
                            }.buttonStyle(.plain)
                        }
                        creditLine
                    }
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(T.panel)
                }
            }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 700, idealWidth: 900, maxWidth: .infinity,
               minHeight: 600, idealHeight: 760, maxHeight: .infinity)
    }

    var creditLine: some View {
        HStack(spacing: 4) {
            Spacer()
            Text("made by")
                .font(.system(size: 10)).foregroundColor(T.textDim)
            Link("@giacomoruvolo", destination: URL(string: "https://github.com/giacomoruvolo")!)
                .font(.system(size: 10, weight: .semibold)).foregroundColor(T.gold)
        }
    }

    var blockedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.octagon.fill").font(.system(size: 48)).foregroundColor(T.err)
            Text(tr("Apple Silicon richiesto", "Apple Silicon required")).font(.system(size: 20, weight: .bold)).foregroundColor(T.text)
            Text(tr("WhisperTranscribe richiede un Mac con chip Apple Silicon (M1, M2, M3 o M4).\nmlx-whisper gira esclusivamente su architettura ARM di Apple.",
                    "WhisperTranscribe requires a Mac with Apple Silicon (M1, M2, M3 or M4).\nmlx-whisper runs exclusively on Apple's ARM architecture."))
                .font(.system(size: 12)).foregroundColor(T.textMid).multilineTextAlignment(.center).lineSpacing(4)
        }
        .frame(maxWidth: .infinity).padding(32)
        .background(T.err.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(T.err.opacity(0.3), lineWidth: 1))
        .cornerRadius(12)
    }

    var hardwareWarning: some View {
        let ram = SystemInfo.ramGB
        let lowRam = ram < 16
        let color: Color = lowRam ? T.gold : T.ok
        return HStack(alignment: .top, spacing: 14) {
            Image(systemName: lowRam ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .font(.system(size: 20)).foregroundColor(color)
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("Requisiti hardware", "Hardware requirements"))
                    .font(.system(size: 13, weight: .bold)).foregroundColor(T.text)
                Text(tr(
                    "WhisperTranscribe richiede un Mac Apple Silicon (M1 o superiore). Per il modello large-v3 servono almeno 16 GB di RAM; con meno memoria usa i modelli medium, small o tiny per evitare rallentamenti o errori.",
                    "WhisperTranscribe requires an Apple Silicon Mac (M1 or newer). The large-v3 model needs at least 16 GB of RAM; with less memory, use the medium, small or tiny models to avoid slowdowns or errors."))
                    .font(.system(size: 11)).foregroundColor(T.textMid).lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(color.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color.opacity(0.3), lineWidth: 1))
        .cornerRadius(10)
    }

    var ramCard: some View {
        let ram = SystemInfo.ramGB
        let color: Color = ram >= 16 ? T.ok : ram >= 8 ? T.gold : T.err
        let msg = ram >= 16 ? tr("Ottimo per tutti i modelli", "Great for all models")
                : ram >= 8  ? tr("Usa modello medium o small", "Use the medium or small model")
                            : tr("Usa solo tiny", "Use tiny only")
        return HStack(spacing: 12) {
            // Block 1: RAM
            HStack(spacing: 16) {
                Image(systemName: "memorychip").font(.system(size: 22)).foregroundColor(color)
                VStack(alignment: .leading, spacing: 3) {
                    Text("RAM: \(ram) GB").font(.system(size: 13, weight: .semibold)).foregroundColor(T.text)
                    Text(msg).font(.system(size: 11)).foregroundColor(color)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(16).frame(maxHeight: .infinity).background(T.surface)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color.opacity(0.3), lineWidth: 1)).cornerRadius(10)

            // Block 2: model requirements
            VStack(alignment: .leading, spacing: 5) {
                Text(tr("REQUISITI MODELLI", "MODEL REQUIREMENTS"))
                    .font(.system(size: 8, weight: .bold)).foregroundColor(T.textDim).tracking(1.2)
                reqRow("large-v3", "≥ 16 GB")
                reqRow("medium", "≥ 8 GB")
                reqRow("tiny", tr("qualsiasi", "any"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16).frame(maxHeight: .infinity).background(T.surface)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(T.border, lineWidth: 1)).cornerRadius(10)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    func reqRow(_ model: String, _ req: String) -> some View {
        HStack {
            Text(model).font(.system(size: 10, design: .monospaced)).foregroundColor(T.textMid)
            Spacer()
            Text(req).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundColor(T.textDim)
        }
    }

    var depsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DIPENDENZE").font(.system(size: 9, weight: .bold)).foregroundColor(T.textDim).tracking(1.5)
            depRow("🍺", "Homebrew", "Gestore pacchetti macOS", brewOK)
            depRow("🐍", "Python 3", "Runtime Python", pythonOK)
            depRow("🎞️", "ffmpeg", "Decodifica audio/video", ffmpegOK)
            depRow("🤖", "mlx-whisper", "Motore AI di trascrizione", mlxOK)
        }
    }

    func depRow(_ icon: String, _ name: String, _ desc: String, _ ok: Bool) -> some View {
        HStack(spacing: 14) {
            Text(icon).font(.system(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 13, weight: .semibold)).foregroundColor(T.text)
                Text(desc).font(.system(size: 11)).foregroundColor(T.textDim)
            }
            Spacer()
            Image(systemName: ok ? "checkmark.circle.fill" : "circle")
                .foregroundColor(ok ? T.ok : T.textDim).font(.system(size: 18))
        }
        .padding(14).background(T.surface)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ok ? T.ok.opacity(0.2) : T.border, lineWidth: 1))
        .cornerRadius(8)
    }

    var actionSection: some View {
        VStack(spacing: 10) {
            if !brewOK {
                HStack(spacing: 14) {
                    Image(systemName: "terminal").font(.system(size: 18)).foregroundColor(T.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Installa Homebrew").font(.system(size: 12, weight: .semibold)).foregroundColor(T.text)
                        Text("Incolla nel Terminale").font(.system(size: 11)).foregroundColor(T.textDim)
                    }
                    Spacer()
                    Button("Copia comando") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(
                            #"/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)""#,
                            forType: .string)
                    }
                    .buttonStyle(GhostButtonStyle())
                }
                .padding(14).background(T.surface)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(T.gold.opacity(0.2), lineWidth: 1)).cornerRadius(8)
            }

            if brewOK && !pythonOK {
                HStack(spacing: 14) {
                    Image(systemName: "arrow.down.circle").font(.system(size: 18)).foregroundColor(T.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Installa Python").font(.system(size: 12, weight: .semibold)).foregroundColor(T.text)
                        Text("brew install python3").font(.system(size: 11, design: .monospaced)).foregroundColor(T.textDim)
                    }
                    Spacer()
                    Button("Copia") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("brew install python3", forType: .string)
                    }
                    .buttonStyle(GhostButtonStyle())
                }
                .padding(14).background(T.surface)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(T.gold.opacity(0.2), lineWidth: 1)).cornerRadius(8)
            }

            if brewOK && pythonOK {
                Button(action: installDeps) {
                    HStack(spacing: 8) {
                        if isInstalling {
                            ProgressView().scaleEffect(0.75).progressViewStyle(CircularProgressViewStyle(tint: .black))
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                        }
                        Text(isInstalling ? "Installazione in corso…" : "Installa dipendenze automaticamente")
                    }
                    .font(.system(size: 13, weight: .bold)).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(isInstalling ? T.goldDk : T.gold).cornerRadius(8)
                }
                .buttonStyle(.plain).disabled(isInstalling)
            }
        }
    }

    var logSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LOG").font(.system(size: 9, weight: .bold)).foregroundColor(T.textDim).tracking(1.5)
            ScrollView {
                Text(installLog).font(.system(size: 9, design: .monospaced)).foregroundColor(T.textMid)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(10)
            }
            .frame(height: 100).background(T.surface).cornerRadius(8)
        }
    }

    func checkAll() {
        brewOK   = SystemInfo.hasBrew
        pythonOK = SystemInfo.hasPython
        ffmpegOK = SystemInfo.hasFfmpeg
        mlxOK    = SystemInfo.hasMlxWhisper
    }

    func installDeps() {
        isInstalling = true
        Task {
            if !ffmpegOK {
                installLog += "→ Installazione ffmpeg...\n"
                let brew = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first { FileManager.default.fileExists(atPath: $0) } ?? "/opt/homebrew/bin/brew"
                _ = await runCmd([brew, "install", "ffmpeg"])
                await MainActor.run { ffmpegOK = SystemInfo.hasFfmpeg; installLog += ffmpegOK ? "✓ ffmpeg\n" : "✕ ffmpeg\n" }
            }
            if !mlxOK {
                installLog += "→ Creazione ambiente Python...\n"
                let venv = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("whisper-env-mlx").path
                let python = ["/opt/homebrew/bin/python3", "/usr/local/bin/python3"].first { FileManager.default.fileExists(atPath: $0) } ?? "python3"
                if !FileManager.default.fileExists(atPath: venv) {
                    _ = await runCmd([python, "-m", "venv", venv])
                }
                installLog += "→ Installazione mlx-whisper...\n"
                let pip = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("whisper-env-mlx/bin/pip3").path
                _ = await runCmd([pip, "install", "--upgrade", "mlx-whisper"])
                await MainActor.run { mlxOK = SystemInfo.hasMlxWhisper; installLog += mlxOK ? "✓ mlx-whisper\n" : "✕ mlx-whisper\n" }
            }
            await MainActor.run { isInstalling = false }
        }
    }

    private func runCmd(_ args: [String]) async -> Int32 {
        guard let exe = args.first else { return -1 }
        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: exe)
                proc.arguments = Array(args.dropFirst())
                var env = ProcessInfo.processInfo.environment
                env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
                proc.environment = env
                let pipe = Pipe()
                proc.standardOutput = pipe; proc.standardError = pipe
                pipe.fileHandleForReading.readabilityHandler = { fh in
                    if let str = String(data: fh.availableData, encoding: .utf8), !str.isEmpty {
                        Task { @MainActor in self.installLog += str }
                    }
                }
                guard (try? proc.run()) != nil else { cont.resume(returning: -1); return }
                proc.waitUntilExit()
                pipe.fileHandleForReading.readabilityHandler = nil
                cont.resume(returning: proc.terminationStatus)
            }
        }
    }
}
