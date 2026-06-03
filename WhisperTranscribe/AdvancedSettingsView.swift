import SwiftUI

// MARK: - AdvancedSettingsView

struct AdvancedSettingsView: View {
    @Binding var params: AdvancedParams
    let languageID: String
    @Environment(\.dismiss) var dismiss

    @State private var confirmed    = false
    @State private var confirmText  = ""
    @State private var showBanner   = true

    var body: some View {
        ZStack {
            T.bg.ignoresSafeArea()
            if !confirmed {
                confirmGate
            } else {
                mainContent
            }
        }
        .preferredColorScheme(.dark)
        .frame(width: 560, height: confirmed ? 700 : 420)
    }

    // MARK: Confirm Gate

    var confirmGate: some View {
        VStack(spacing: 28) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52)).foregroundColor(T.gold)

            VStack(spacing: 10) {
                Text("Zona Avanzata")
                    .font(.system(size: 22, weight: .bold)).foregroundColor(T.text)
                Text("Modificare questi parametri può causare trascrizioni errate, ripetizioni o risultati inattesi.\n\nQueste impostazioni sono pensate per utenti esperti che conoscono il funzionamento di Whisper.\n\nSe non sei sicuro, chiudi questa schermata e usa i valori predefiniti.")
                    .font(.system(size: 12)).foregroundColor(T.textMid)
                    .multilineTextAlignment(.center).lineSpacing(4)
            }

            VStack(spacing: 8) {
                Text("Digita CONFERMO per continuare")
                    .font(.system(size: 11, weight: .semibold)).foregroundColor(T.textDim)
                TextField("", text: $confirmText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(T.gold)
                    .multilineTextAlignment(.center)
                    .padding(10)
                    .background(T.surface2)
                    .cornerRadius(8)
                    .frame(width: 200)
            }

            HStack(spacing: 12) {
                Button("Annulla") { dismiss() }
                    .buttonStyle(GhostButtonStyle())
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { confirmed = true } }) {
                    Text("Continua")
                        .font(.system(size: 13, weight: .bold)).foregroundColor(.black)
                        .padding(.horizontal, 28).padding(.vertical, 10)
                        .background(confirmText.uppercased() == "CONFERMO" ? T.gold : T.surface2)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(confirmText.uppercased() != "CONFERMO")
            }
        }
        .padding(40)
    }

    // MARK: Main Content

    var mainContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Impostazioni Avanzate")
                        .font(.system(size: 16, weight: .bold)).foregroundColor(T.text)
                    Text("Modifica i parametri di trascrizione")
                        .font(.system(size: 11)).foregroundColor(T.textDim)
                }
                Spacer()
                if params.isModified {
                    Text("MODIFICATO")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(T.gold).tracking(1.5)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(T.gold.opacity(0.1)).cornerRadius(4)
                }
            }
            .padding(.horizontal, 24).padding(.vertical, 16)

            Divider().background(T.border)

            ScrollView {
                VStack(spacing: 18) {
                    if showBanner { disclaimerBanner }
                    temperatureCard
                    conditionCard
                    noSpeechCard
                    compressionCard
                    bestOfCard
                    promptCard
                    resetButton
                }
                .padding(22)
            }

            Divider().background(T.border)

            // Bottom bar
            HStack {
                if params.isModified {
                    Label("Parametri personalizzati attivi", systemImage: "slider.horizontal.3")
                        .font(.system(size: 11)).foregroundColor(T.gold)
                } else {
                    Label("Valori ottimizzati per la lingua", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11)).foregroundColor(T.ok)
                }
                Spacer()
                Button("Chiudi") { dismiss() }.buttonStyle(GhostButtonStyle())
                Button(action: { dismiss() }) {
                    Text("Applica")
                        .font(.system(size: 13, weight: .bold)).foregroundColor(.black)
                        .padding(.horizontal, 20).padding(.vertical, 8)
                        .background(T.gold).cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24).padding(.vertical, 14)
            .background(T.panel)
        }
    }

    // MARK: Disclaimer

    var disclaimerBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(T.gold).font(.system(size: 14))
                Text("Valori non ottimali possono peggiorare la qualità")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(T.text)
                Spacer()
                Button(action: { withAnimation { showBanner = false } }) {
                    Image(systemName: "xmark").font(.system(size: 10)).foregroundColor(T.textDim)
                }.buttonStyle(.plain)
            }
            Button(action: { params = AdvancedParams.forLanguage(languageID) }) {
                Label("Ripristina valori ottimizzati per la lingua corrente", systemImage: "sparkles")
                    .font(.system(size: 11)).foregroundColor(T.gold)
            }.buttonStyle(.plain)
        }
        .padding(14)
        .background(T.gold.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(T.gold.opacity(0.25), lineWidth: 1))
        .cornerRadius(10)
    }

    // MARK: Parameter Cards

    var temperatureCard: some View {
        paramCard(icon: "thermometer.medium", title: "Temperature",
                  value: String(format: "%.2f", params.temperature),
                  valueColor: tempColor) {
            Slider(value: $params.temperature, in: 0...1, step: 0.05).tint(tempColor)
            scaleLabels(["0.0", "0.5", "1.0"])
            guides([
                ("0.0",     "Greedy — deterministico, stabile. Consigliato per italiano.", T.ok),
                ("0.1–0.3", "Buon equilibrio stabilità/flessibilità. Default inglese = 0.2", T.gold),
                ("0.4–0.7", "Più variabile. Può gestire audio rumoroso ma rischia ripetizioni.", T.gold.opacity(0.7)),
                ("0.8–1.0", "Alta variabilità. Rischio elevato di allucinazioni.", T.err),
            ])
        }
    }

    var tempColor: Color {
        switch params.temperature {
        case 0..<0.35: return T.ok
        case 0.35..<0.6: return T.gold
        default: return T.err
        }
    }

    var conditionCard: some View {
        paramCard(icon: "link", title: "Condition on Previous Text",
                  value: params.conditionOnPrevious ? "Attivo" : "Disattivo",
                  valueColor: params.conditionOnPrevious ? T.ok : T.textDim) {
            Toggle("", isOn: $params.conditionOnPrevious)
                .toggleStyle(SwitchToggleStyle(tint: T.gold)).labelsHidden()
            guides([
                ("Attivo",   "Usa il testo precedente come contesto. Migliora coerenza. Consigliato per italiano.", T.ok),
                ("Disattivo","Ogni segmento è indipendente. Evita propagazione errori. Default per inglese.", T.gold),
            ])
        }
    }

    var noSpeechCard: some View {
        paramCard(icon: "waveform.slash", title: "No Speech Threshold",
                  value: String(format: "%.2f", params.noSpeechThreshold),
                  valueColor: T.textMid) {
            Slider(value: $params.noSpeechThreshold, in: 0...1, step: 0.05).tint(T.gold)
            scaleLabels(["0.0", "0.5", "1.0"])
            guides([
                ("< 0.4",   "Trascrive tutto, anche i silenzi. Rischio testo inventato.", T.err),
                ("0.5–0.6", "Default — buon equilibrio per la maggior parte degli audio.", T.ok),
                ("0.7–0.8", "Più selettivo. Utile per audio con rumore di fondo o italiano.", T.gold),
                ("> 0.9",   "Molto selettivo — può saltare parti di parlato reale.", T.err),
            ])
        }
    }

    var compressionCard: some View {
        paramCard(icon: "rectangle.compress.vertical", title: "Compression Ratio Threshold",
                  value: String(format: "%.1f", params.compressionRatioThreshold),
                  valueColor: T.textMid) {
            Slider(value: $params.compressionRatioThreshold, in: 1...4, step: 0.1).tint(T.gold)
            scaleLabels(["1.0", "2.5", "4.0"])
            guides([
                ("< 1.5",   "Rifiuta troppi segmenti — potrebbe saltare parti valide.", T.err),
                ("2.0–2.5", "Default (2.4) — rileva e scarta loop di ripetizioni.", T.ok),
                ("3.0–4.0", "Permette più ripetizioni. Solo per audio tecnico con terminologia ripetuta.", T.gold),
            ])
        }
    }

    var bestOfCard: some View {
        paramCard(icon: "list.number", title: "Best Of (campionamenti)",
                  value: "\(params.bestOf)", valueColor: T.textMid) {
            HStack(spacing: 10) {
                ForEach([1, 3, 5, 8], id: \.self) { val in
                    Button(action: { params.bestOf = val }) {
                        Text("\(val)")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .frame(width: 48, height: 34)
                            .background(params.bestOf == val ? T.gold : T.surface2)
                            .foregroundColor(params.bestOf == val ? .black : T.textMid)
                            .cornerRadius(6)
                    }.buttonStyle(.plain)
                }
            }
            guides([
                ("1", "Veloce, un solo campionamento. Meno accurato.", T.gold),
                ("5", "Default — buon equilibrio velocità/qualità.", T.ok),
                ("8", "Più lento ma accurato per audio difficile. Nessun effetto con temperature=0.", T.gold),
            ])
        }
    }

    var promptCard: some View {
        paramCard(icon: "text.bubble", title: "Prompt iniziale (opzionale)",
                  value: params.initialPrompt.isEmpty ? "Vuoto" : "\(params.initialPrompt.count) car.",
                  valueColor: params.initialPrompt.isEmpty ? T.textDim : T.gold) {
            TextEditor(text: $params.initialPrompt)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(T.text)
                .scrollContentBackground(.hidden)
                .background(T.surface2)
                .frame(height: 56)
                .cornerRadius(6)
                .padding(4).background(T.surface2).cornerRadius(6)
            guides([
                ("Vuoto",   "Nessun contesto iniziale — comportamento standard.", T.ok),
                ("Esempio", "Inserisci nomi propri o terminologia specifica. Es: \"nomi propri, città, sigle\"", T.gold),
                ("Attenzione", "Un prompt sbagliato può peggiorare la trascrizione.", T.err),
            ])
        }
    }

    var resetButton: some View {
        Button(action: { params = AdvancedParams.forLanguage(languageID) }) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.counterclockwise")
                Text("Ripristina valori ottimizzati per la lingua")
            }
            .font(.system(size: 12, weight: .medium)).foregroundColor(T.textMid)
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(T.surface2).cornerRadius(8)
        }.buttonStyle(.plain)
    }

    // MARK: Helpers

    func paramCard(icon: String, title: String, value: String, valueColor: Color,
                   @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon).font(.system(size: 13)).foregroundColor(T.gold).frame(width: 20)
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(T.text)
                Spacer()
                Text(value).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(valueColor)
            }
            content()
        }
        .padding(16)
        .background(T.surface)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(T.border, lineWidth: 1))
        .cornerRadius(10)
    }

    func scaleLabels(_ labels: [String]) -> some View {
        HStack {
            ForEach(labels, id: \.self) { l in
                if l != labels.first { Spacer() }
                Text(l).font(.system(size: 10, design: .monospaced)).foregroundColor(T.textDim)
            }
        }
    }

    func guides(_ items: [(String, String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(items, id: \.0) { label, desc, color in
                HStack(alignment: .top, spacing: 8) {
                    Text(label)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(color).frame(minWidth: 58, alignment: .leading)
                    Text(desc).font(.system(size: 10)).foregroundColor(T.textDim).lineSpacing(2)
                }
            }
        }
        .padding(10).background(T.bg).cornerRadius(6)
    }
}
