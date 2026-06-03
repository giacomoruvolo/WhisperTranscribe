import Foundation
import Combine

// MARK: - Models

enum JobStatus: String {
    case waiting  = "In attesa"
    case running  = "In corso"
    case done     = "Completato"
    case failed   = "Errore"

    var label: String {
        switch self {
        case .waiting: return tr("In attesa", "Waiting")
        case .running: return tr("In corso", "Running")
        case .done:    return tr("Completato", "Done")
        case .failed:  return tr("Errore", "Error")
        }
    }
}

struct WhisperModel: Identifiable, Hashable {
    let id: String
    let label: String
    let description: String
    let ramGB: Int
    var mlxPath: String { "mlx-community/\(id)" }
    var ramLabel: String { "≥ \(ramGB) GB RAM" }
}

let whisperModels: [WhisperModel] = [
    WhisperModel(id: "whisper-large-v3-mlx", label: "large-v3", description: tr("Massima qualità", "Best quality"),  ramGB: 16),
    WhisperModel(id: "whisper-large-v2-mlx", label: "large-v2", description: tr("Ottima qualità", "Great quality"),   ramGB: 16),
    WhisperModel(id: "whisper-medium-mlx",   label: "medium",   description: tr("Bilanciato", "Balanced"),       ramGB: 8),
    WhisperModel(id: "whisper-small-mlx",    label: "small",    description: tr("Veloce", "Fast"),           ramGB: 8),
    WhisperModel(id: "whisper-tiny",         label: "tiny",     description: tr("Velocissimo", "Fastest"),      ramGB: 8),
]

struct Language: Identifiable, Hashable {
    let id: String
    let name: String
}

let languages: [Language] = [
    Language(id: "en",   name: tr("Inglese", "English")),
    Language(id: "it",   name: tr("Italiano", "Italian")),
    Language(id: "fr",   name: tr("Francese", "French")),
    Language(id: "de",   name: tr("Tedesco", "German")),
    Language(id: "es",   name: tr("Spagnolo", "Spanish")),
    Language(id: "pt",   name: tr("Portoghese", "Portuguese")),
    Language(id: "ja",   name: tr("Giapponese", "Japanese")),
    Language(id: "zh",   name: tr("Cinese", "Chinese")),
    Language(id: "ar",   name: tr("Arabo", "Arabic")),
    Language(id: "ru",   name: tr("Russo", "Russian")),
    Language(id: "auto", name: "Auto-detect"),
]

// Whisper task: keep the spoken language, or translate to English.
enum OutputMode: String, CaseIterable, Identifiable {
    case original  // --task transcribe  → subtitles in the spoken language
    case english   // --task translate   → subtitles translated to English

    var id: String { rawValue }
    var whisperTask: String { self == .original ? "transcribe" : "translate" }
    var label: String { self == .original ? tr("Lingua originale", "Original language") : tr("Inglese", "English") }
    var shortLabel: String { self == .original ? tr("Originale", "Original") : "EN" }
}

let outputFormats = ["srt", "vtt", "txt", "json"]

// MARK: - Timestamp parser

func parseTimestamp(_ s: String) -> Double? {
    let clean = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
    let parts = clean.components(separatedBy: ":")
    switch parts.count {
    case 3:
        guard let h = Double(parts[0]), let m = Double(parts[1]), let sec = Double(parts[2]) else { return nil }
        return h * 3600 + m * 60 + sec
    case 2:
        guard let m = Double(parts[0]), let sec = Double(parts[1]) else { return nil }
        return m * 60 + sec
    default: return nil
    }
}

// MARK: - Advanced Params

struct AdvancedParams {
    var temperature: Double               = 0.0
    var conditionOnPrevious: Bool         = true
    var noSpeechThreshold: Double         = 0.6
    var compressionRatioThreshold: Double = 2.4
    var bestOf: Int                       = 5
    var initialPrompt: String             = ""

    static func forLanguage(_ langID: String) -> AdvancedParams {
        var p = AdvancedParams()
        if langID == "it" {
            p.temperature         = 0.0
            p.conditionOnPrevious = true
            p.noSpeechThreshold   = 0.8
        } else {
            p.temperature         = 0.2
            p.conditionOnPrevious = false
            p.noSpeechThreshold   = 0.6
        }
        return p
    }

    var isModified: Bool {
        temperature != 0.0 || !conditionOnPrevious ||
        noSpeechThreshold != 0.6 || compressionRatioThreshold != 2.4 ||
        bestOf != 5 || !initialPrompt.isEmpty
    }
}

// MARK: - Job

class TranscriptionJob: ObservableObject, Identifiable, @unchecked Sendable {
    let id = UUID()
    let videoURL: URL
    var outputDir: URL
    let language: Language
    let model: WhisperModel
    let format: String
    let outputMode: OutputMode
    let params: AdvancedParams

    @Published var status: JobStatus = .waiting
    @Published var logText: String   = ""
    @Published var outputURL: URL?
    @Published var elapsed: String   = ""
    @Published var progress: Double  = 0.0

    weak var queue: TranscriptionQueue?
    private var startTime: Date?

    init(videoURL: URL, outputDir: URL, language: Language, model: WhisperModel,
         format: String, outputMode: OutputMode, params: AdvancedParams) {
        self.videoURL   = videoURL
        self.outputDir  = outputDir
        self.language   = language
        self.model      = model
        self.format     = format
        self.outputMode = outputMode
        self.params     = params
    }

    var fileName: String { videoURL.lastPathComponent }

    func markStarted() {
        startTime = Date()
        status    = .running
        progress  = 0
    }

    func markDone(success: Bool) {
        status   = success ? .done : .failed
        progress = success ? 1.0 : progress
        if let s = startTime {
            let secs = Int(Date().timeIntervalSince(s))
            elapsed = "\(secs / 60)m \(secs % 60)s"
        }
    }

    func appendLog(_ line: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let q = self.queue else { return }
            // Always update job-level log immediately
            self.logText = self.logText.isEmpty ? line : self.logText + "\n" + line
            // Buffer global log updates and flush every 0.3s to prevent flicker
            let entry = "[\(self.fileName)]  \(line)"
            q.logBuffer.append(entry)
            if q.logFlushTimer == nil {
                q.logFlushTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                    DispatchQueue.main.async {
                        guard !q.logBuffer.isEmpty else { return }
                        let newLines = q.logBuffer.joined(separator: "\n")
                        q.logBuffer.removeAll()
                        q.logFlushTimer = nil
                        q.globalLog = q.globalLog.isEmpty ? newLines : q.globalLog + "\n" + newLines
                        let lines = q.globalLog.components(separatedBy: "\n")
                        if lines.count > 450 {
                            q.globalLog = lines.suffix(400).joined(separator: "\n")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Queue

class TranscriptionQueue: ObservableObject, @unchecked Sendable {
    @Published var jobs: [TranscriptionJob]  = []
    @Published var isRunning                 = false
    @Published var statusMessage             = tr("Aggiungi file per iniziare", "Add files to start")
    @Published var envStatus                 = tr("Verifica ambiente...", "Checking environment...")
    @Published var envReady                  = false
    @Published var globalProgress: Double    = 0
    @Published var globalLog: String         = ""
    var currentJobDuration: Double?          = nil
    private var userStopped: Bool            = false
    var logBuffer: [String]                  = []
    var logFlushTimer: Timer?                = nil

    private let venvPath: URL
    private var currentProcess: Process?

    init() {
        venvPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("whisper-env-mlx")
        Task { await checkEnvironment() }
    }

    // MARK: Environment

    func checkEnvironment() async {
        let mlxBin   = venvPath.appendingPathComponent("bin/mlx_whisper")
        let ffmpegOK = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]
            .contains { FileManager.default.fileExists(atPath: $0) }
        let mlxOK = FileManager.default.fileExists(atPath: mlxBin.path)
        await MainActor.run {
            if ffmpegOK && mlxOK {
                self.envStatus = tr("Ambiente pronto", "Environment ready"); self.envReady = true
            } else {
                var m: [String] = []
                if !ffmpegOK { m.append("ffmpeg") }
                if !mlxOK    { m.append("mlx-whisper") }
                self.envStatus = m.joined(separator: ", ") + tr(" mancante", " missing")
                self.envReady  = false
            }
        }
    }

    func setupEnvironment() async {
        await MainActor.run { envStatus = tr("Configurazione...", "Configuring...") }
        let ffmpegOK = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]
            .contains { FileManager.default.fileExists(atPath: $0) }
        if !ffmpegOK { await runCmd(["/opt/homebrew/bin/brew", "install", "ffmpeg"]) }
        if !FileManager.default.fileExists(atPath: venvPath.path) {
            await runCmd([findPython(), "-m", "venv", venvPath.path])
        }
        let pip = venvPath.appendingPathComponent("bin/pip3").path
        if !FileManager.default.fileExists(atPath: venvPath.appendingPathComponent("bin/mlx_whisper").path) {
            await runCmd([pip, "install", "mlx-whisper"])
        }
        await checkEnvironment()
    }

    private func findPython() -> String {
        ["/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3"]
            .first { FileManager.default.fileExists(atPath: $0) } ?? "python3"
    }

    private func makeEnv() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
        env["PYTHONUNBUFFERED"] = "1"
        return env
    }

    @discardableResult
    private func runCmd(_ args: [String]) async -> Int32 {
        guard let exe = args.first else { return -1 }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: exe)
        proc.arguments     = Array(args.dropFirst())
        proc.environment   = makeEnv()
        try? proc.run(); proc.waitUntilExit()
        return proc.terminationStatus
    }

    // MARK: Queue management

    func addJobs(_ urls: [URL], outputDir: URL, language: Language,
                 model: WhisperModel, format: String, outputMode: OutputMode,
                 params: AdvancedParams) {
        let exts: Set<String> = ["mp4","mov","mkv","avi","m4v","webm","flv","wmv","mpg","mpeg",
                                  "mp3","m4a","aac","wav","flac","ogg","opus","wma","aiff","aif"]
        let valid = urls.filter { exts.contains($0.pathExtension.lowercased()) }
        guard !valid.isEmpty else { return }
        let newJobs = valid.map {
            TranscriptionJob(videoURL: $0, outputDir: outputDir,
                             language: language, model: model,
                             format: format, outputMode: outputMode, params: params)
        }
        newJobs.forEach { $0.queue = self }
        jobs.append(contentsOf: newJobs)
        statusMessage = tr("\(jobs.count) file in coda  ·  premi Avvia", "\(jobs.count) files queued  ·  press Start")
        recalcProgress()
    }

    func removeJob(_ job: TranscriptionJob) {
        guard job.status == .waiting else { return }
        jobs.removeAll { $0.id == job.id }
        recalcProgress()
    }

    func clearCompleted() {
        jobs.removeAll { $0.status == .done || $0.status == .failed }
        recalcProgress()
    }

    func recalcProgress() {
        guard !jobs.isEmpty else { globalProgress = 0; return }
        let done    = Double(jobs.filter { $0.status == .done || $0.status == .failed }.count)
        let running = jobs.filter { $0.status == .running }.map { $0.progress }.reduce(0, +)
        globalProgress = (done + running) / Double(jobs.count)
    }

    func stopQueue() {
        userStopped = true
        // SIGTERM the current process
        currentProcess?.terminate()
        // Hard-kill any orphan mlx_whisper instances as fallback
        let killer = Process()
        killer.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        killer.arguments     = ["-9", "-f", "mlx_whisper"]
        try? killer.run()
        killer.waitUntilExit()

        currentProcess = nil
        for job in jobs where job.status == .running { job.markDone(success: false) }
        isRunning     = false
        statusMessage = tr("Interrotto", "Stopped")
    }

    func startQueue() {
        guard !isRunning else { return }
        let pending = jobs.filter { $0.status == .waiting }
        guard !pending.isEmpty else { return }
        userStopped = false
        isRunning = true
        Task { await runQueue(pending: pending) }
        Task {
            while isRunning {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run { self.recalcProgress() }
            }
        }
    }

    private func runQueue(pending: [TranscriptionJob]) async {
        if !envReady { await setupEnvironment() }
        let total = pending.count
        for (i, job) in pending.enumerated() {
            if userStopped { break }
            await MainActor.run { statusMessage = tr("Trascrizione \(i+1)/\(total): \(job.fileName)", "Transcribing \(i+1)/\(total): \(job.fileName)") }
            await transcribeLocal(job: job)
            await MainActor.run { recalcProgress() }
            if userStopped { break }
        }
        let ok  = jobs.filter { $0.status == .done  }.count
        let err = jobs.filter { $0.status == .failed }.count
        await MainActor.run {
            isRunning     = false
            statusMessage = tr("✓ \(ok) completati\(err > 0 ? "  ·  ✕ \(err) errori" : "")",
                               "✓ \(ok) done\(err > 0 ? "  ·  ✕ \(err) errors" : "")")
        }
        notify(ok: ok, err: err)
    }

    // MARK: - Local Transcription

    private func videoDuration(_ url: URL) -> Double? {
        let ffprobe = ["/opt/homebrew/bin/ffprobe", "/usr/local/bin/ffprobe"]
            .first { FileManager.default.fileExists(atPath: $0) } ?? "ffprobe"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: ffprobe)
        proc.arguments     = ["-v", "quiet", "-print_format", "json", "-show_format", url.path]
        proc.environment   = makeEnv()
        let pipe = Pipe()
        proc.standardOutput = pipe; proc.standardError = Pipe()
        guard (try? proc.run()) != nil else { return nil }
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let json   = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let format = json["format"] as? [String: Any],
              let durStr = format["duration"] as? String,
              let dur    = Double(durStr) else { return nil }
        return dur
    }

    private func transcribeLocal(job: TranscriptionJob) async {
        let duration = await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                cont.resume(returning: self.videoDuration(job.videoURL))
            }
        }
        await MainActor.run { job.markStarted(); self.currentJobDuration = duration }

        let mlxBin = venvPath.appendingPathComponent("bin/mlx_whisper").path
        let params = job.params
        // Log output dir so user can debug path issues
        job.appendLog("📁 Output: \(job.outputDir.path)")
        var args = [
            job.videoURL.path,
            "--model", job.model.mlxPath,
            "--task", job.outputMode.whisperTask,
            "--output-format", job.format,
            "--output-dir", job.outputDir.path,
            "--condition-on-previous-text", params.conditionOnPrevious ? "True" : "False",
            "--temperature", String(format: "%.2f", params.temperature),
            "--no-speech-threshold", String(format: "%.2f", params.noSpeechThreshold),
            "--compression-ratio-threshold", String(format: "%.1f", params.compressionRatioThreshold),
            "--best-of", "\(params.bestOf)",
        ]
        if !params.initialPrompt.isEmpty { args += ["--initial-prompt", params.initialPrompt] }
        if job.language.id != "auto"     { args += ["--language", job.language.id] }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: mlxBin)
        proc.arguments     = args
        proc.environment   = makeEnv()
        await MainActor.run { self.currentProcess = proc }

        let pipe = Pipe()
        proc.standardOutput = pipe; proc.standardError = pipe

        let handle = pipe.fileHandleForReading
        let jobDuration = duration
        let readQueue = DispatchQueue(label: "com.whisper.read", qos: .userInitiated)
        var lineBuf = ""

        handle.readabilityHandler = { fh in
            let data = fh.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            readQueue.async {
                for ch in str {
                    if ch == "\n" || ch == "\r" {
                        let line = lineBuf.trimmingCharacters(in: .whitespaces)
                        if !line.isEmpty {
                            if line.contains("-->"),
                               let open  = line.firstIndex(of: "["),
                               let close = line.firstIndex(of: "]") {
                                let ts    = String(line[line.index(after: open)..<close])
                                let parts = ts.components(separatedBy: " --> ")
                                if let endStr = parts.last, let endSecs = parseTimestamp(endStr) {
                                    DispatchQueue.main.async { [weak self] in
                                        guard let self else { return }
                                        let pct: Double
                                        if let dur = jobDuration, dur > 0 {
                                            pct = min(0.97, endSecs / dur)
                                        } else {
                                            let cur = job.progress < 0.05 ? 0.0 : job.progress
                                            pct = min(0.97, cur + max(0.005, (1.0 - cur) * 0.02))
                                        }
                                        job.progress = pct
                                        let done = Double(self.jobs.filter {
                                            $0.status == .done || $0.status == .failed
                                        }.count)
                                        self.globalProgress = (done + pct) / Double(self.jobs.count)
                                    }
                                }
                            }
                            job.appendLog(line)
                        }
                        lineBuf = ""
                    } else { lineBuf.append(ch) }
                }
            }
        }

        do { try proc.run() } catch {
            handle.readabilityHandler = nil
            await MainActor.run {
                job.appendLog("❌ \(error.localizedDescription)")
                job.markDone(success: false)
            }
            return
        }

        proc.waitUntilExit()
        handle.readabilityHandler = nil
        if !lineBuf.trimmingCharacters(in: .whitespaces).isEmpty { job.appendLog(lineBuf) }

        let outURL = job.outputDir
            .appendingPathComponent(job.videoURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension(job.format)
        await MainActor.run {
            job.outputURL = FileManager.default.fileExists(atPath: outURL.path) ? outURL : nil
            job.markDone(success: proc.terminationStatus == 0)
        }
    }

    private func notify(ok: Int, err: Int) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e",
            "display notification \"Completati \(ok) job\" with title \"WhisperTranscribe\""]
        try? proc.run()
    }
}
