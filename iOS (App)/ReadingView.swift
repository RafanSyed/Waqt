import SwiftUI
import Speech
import AVFoundation

struct ReadingView: View {
    @State private var surahs: [Surah] = []
    @State private var selectedSurah: Surah? = nil
    @State private var currentAyahIndex: Int = 0
    @State private var ayahs: [Ayah] = []
    @State private var isLoadingSurahs = true
    @State private var isLoadingAyahs = false
    @State private var isRecording = false
    @State private var sessionMinutes: Double = 0
    @State private var sessionSeconds: Int = 0
    @State private var sessionTimer: Timer? = nil
    @State private var verifyingIndex: Int? = nil
    @State private var ayahResults: [Int: Bool] = [:]
    @State private var showSessionSummary = false

    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ar-SA"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest? = nil
    @State private var recognitionTask: SFSpeechRecognitionTask? = nil
    @State private var audioEngine = AVAudioEngine()
    @State private var currentTranscript = ""

    let baseURL = "http://localhost:3000"
    let indopakFont = "AlQuran IndoPak by QuranWBW"
    
    
    var currentAyah: Ayah? {
        guard !ayahs.isEmpty, currentAyahIndex < ayahs.count else { return nil }
        return ayahs[currentAyahIndex]
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.12)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // session bar
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(Color(red: 0.4, green: 0.8, blue: 0.6))
                    Text("Session: \(formatMinutes(sessionMinutes))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    if isRecording {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .opacity(0.8)
                            Text(formatSeconds(sessionSeconds))
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.04))

                if isLoadingSurahs {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                } else if selectedSurah == nil {
                    surahPickerView
                } else {
                    readingSessionView
                }
            }

            // session summary overlay
            if showSessionSummary {
                sessionSummaryOverlay
            }
        }
        .navigationTitle("Read")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { fetchSurahs() }
    }

    // MARK: Surah Picker
    var surahPickerView: some View {
        VStack(spacing: 16) {
            Text("Select a Surah")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .padding(.top, 24)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(surahs) { surah in
                        Button {
                            selectSurah(surah)
                        } label: {
                            HStack {
                                Text("\(surah.number)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .frame(width: 36, height: 36)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(10)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(surah.englishName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(surah.englishNameTranslation)
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.4))
                                }

                                Spacer()

                                Text(surah.name)
                                    .font(.custom(indopakFont, size: 20))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: Reading Session
    var readingSessionView: some View {
        VStack(spacing: 0) {

            // surah header
            if let surah = selectedSurah {
                HStack {
                    Button {
                        stopRecording()
                        selectedSurah = nil
                        ayahs = []
                        currentAyahIndex = 0
                        ayahResults = [:]
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Surahs")
                        }
                        .foregroundColor(Color(red: 0.4, green: 0.8, blue: 0.6))
                        .font(.system(size: 15))
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text(surah.name)
                            .font(.custom(indopakFont, size: 18))
                            .foregroundColor(.white)
                        Text(surah.englishName)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    Spacer()

                    Image(systemName: "chevron.left")
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.04))
            }

            if isLoadingAyahs {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            // bismillah header (except Surah 9)
                            if let surah = selectedSurah, surah.number != 9 {
                                Text("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")
                                    .font(.custom(indopakFont, size: 26))
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, 20)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white.opacity(0.03))
                            }

                            // all ayahs
                            VStack(spacing: 0) {
                                ForEach(Array(ayahs.enumerated()), id: \.element.id) { index, ayah in
                                    ayahRow(ayah: ayah, index: index)
                                        .id(index)
                                        .onTapGesture {
                                            if !isRecording {
                                                currentAyahIndex = index
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 120)
                        }
                    }
                    .onChange(of: currentAyahIndex) { newIndex in
                        withAnimation {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }

            // bottom bar
            bottomBar
        }
    }

    // MARK: Ayah Row
    func ayahRow(ayah: Ayah, index: Int) -> some View {
        let isActive = index == currentAyahIndex
        let isVerified = ayahResults[index] == true
        let isFailed = ayahResults[index] == false
        let isBeingVerified = verifyingIndex == index

        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Text(ayah.text)
                        .font(.custom(indopakFont, size: 24))
                        .foregroundColor(
                            isVerified ? Color(red: 0.4, green: 0.8, blue: 0.6) :
                            isFailed ? .orange :
                            isActive ? .white :
                            .white.opacity(0.5)
                        )
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(14)

                    // ayah number marker ۝
                    HStack(spacing: 6) {
                        if isBeingVerified {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                        }
                        if isVerified {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(red: 0.4, green: 0.8, blue: 0.6))
                                .font(.system(size: 14))
                        }
                        Text("﴿\(ayah.numberInSurah)﴾")
                            .font(.custom(indopakFont, size: 18))
                            .foregroundColor(
                                isActive ? Color(red: 0.4, green: 0.8, blue: 0.6) : .white.opacity(0.3)
                            )
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive ? Color.white.opacity(0.06) : Color.clear)
                    .animation(.easeInOut(duration: 0.3), value: isActive)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isActive ? Color(red: 0.4, green: 0.8, blue: 0.6).opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
                    .animation(.easeInOut(duration: 0.3), value: isActive)
            )

            // divider between ayahs
            if index < ayahs.count - 1 {
                Divider()
                    .background(Color.white.opacity(0.06))
                    .padding(.horizontal, 24)
            }
        }
    }

    // MARK: Bottom Bar
    var bottomBar: some View {
        VStack(spacing: 12) {
            // live transcript
            if !currentTranscript.isEmpty && isRecording {
                Text(currentTranscript)
                    .font(.custom(indopakFont, size: 16))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 20)
            }

            HStack(spacing: 16) {
                // skip ayah
                Button {
                    advanceAyah()
                } label: {
                    Text("Skip")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)
                }
                .disabled(!isRecording && ayahs.isEmpty)

                // record toggle
                Button {
                    isRecording ? stopRecording() : startRecording()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.fill")
                            .font(.system(size: 18))
                        Text(isRecording ? "Stop" : "Start Reciting")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        isRecording
                        ? LinearGradient(colors: [.red.opacity(0.9), .orange.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color(red: 0.4, green: 0.8, blue: 0.6), Color(red: 0.2, green: 0.6, blue: 0.9)], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(14)
                    .animation(.easeInOut(duration: 0.2), value: isRecording)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .padding(.top, 8)
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.12).ignoresSafeArea())
    }

    // MARK: Session Summary
    var sessionSummaryOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(Color(red: 0.4, green: 0.8, blue: 0.6))

                Text("Session Complete")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)

                VStack(spacing: 12) {
                    summaryRow(label: "Ayahs recited", value: "\(ayahResults.values.filter { $0 }.count)")
                    summaryRow(label: "Reading time", value: formatSeconds(sessionSeconds))
                    summaryRow(label: "Time earned", value: formatMinutes(sessionMinutes))
                }
                .padding(20)
                .background(Color.white.opacity(0.06))
                .cornerRadius(16)

                Button {
                    showSessionSummary = false
                    sessionSeconds = 0
                    sessionMinutes = 0
                    ayahResults = [:]
                    currentAyahIndex = 0
                } label: {
                    Text("Done")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.4, green: 0.8, blue: 0.6), Color(red: 0.2, green: 0.6, blue: 0.9)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                }
            }
            .padding(32)
            .background(Color(red: 0.05, green: 0.05, blue: 0.12))
            .cornerRadius(24)
            .padding(.horizontal, 24)
        }
    }

    func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.5))
                .font(.system(size: 15))
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .font(.system(size: 15, weight: .semibold))
        }
    }

    // MARK: Helpers
    func formatMinutes(_ minutes: Double) -> String {
        let m = Int(minutes)
        if m >= 60 { return "\(m / 60)h \(m % 60)m" }
        return "\(m)m"
    }

    func formatSeconds(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    func advanceAyah() {
        if currentAyahIndex < ayahs.count - 1 {
            currentAyahIndex += 1
        }
    }

    // MARK: Speech Recognition
    func startRecording() {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { return }
            DispatchQueue.main.async {
                do {
                    let audioSession = AVAudioSession.sharedInstance()
                    try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
                    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

                    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
                    guard let recognitionRequest = recognitionRequest else { return }
                    recognitionRequest.shouldReportPartialResults = true

                    var lastVerifiedTranscript = ""

                    recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
                        guard let result = result else { return }
                        let fullTranscript = result.bestTranscription.formattedString
                        currentTranscript = fullTranscript

                        // check if new content since last verify
                        let newContent = String(fullTranscript.dropFirst(lastVerifiedTranscript.count)).trimmingCharacters(in: .whitespaces)

                        if newContent.count > 10 {
                            // verify the current ayah with what we've heard
                            if verifyingIndex != currentAyahIndex {
                                verifyingIndex = currentAyahIndex
                                verifyLive(transcript: newContent) { matched in
                                    if matched {
                                        lastVerifiedTranscript = fullTranscript
                                        advanceAyah()
                                    }
                                    verifyingIndex = nil
                                }
                            }
                        }
                    }

                    let inputNode = audioEngine.inputNode
                    let format = inputNode.outputFormat(forBus: 0)
                    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                        recognitionRequest.append(buffer)
                    }

                    audioEngine.prepare()
                    try audioEngine.start()
                    isRecording = true

                    // start session timer
                    sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                        sessionSeconds += 1
                    }

                } catch {
                    print("Recording error: \(error)")
                }
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        currentTranscript = ""
        sessionTimer?.invalidate()
        sessionTimer = nil

        // calculate time earned from session length
        let earnedFromTime = Double(sessionSeconds) / 60.0
        sessionMinutes = earnedFromTime
        addTimeToBank(minutes: earnedFromTime)

        showSessionSummary = true
    }

    // MARK: Live Verify
    func verifyLive(transcript: String, completion: @escaping (Bool) -> Void) {
        guard let ayah = currentAyah, let surah = selectedSurah else {
            completion(false)
            return
        }

        guard let url = URL(string: "\(baseURL)/verify") else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "surah": surah.number,
            "ayah": ayah.numberInSurah,
            "transcript": transcript
        ])

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            DispatchQueue.main.async {
                let match = json["match"] as? Bool ?? false
                ayahResults[currentAyahIndex] = match
                completion(match)
            }
        }.resume()
    }

    func addTimeToBank(minutes: Double) {
        guard let url = URL(string: "\(baseURL)/time/add") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["minutes": minutes])
        URLSession.shared.dataTask(with: request).resume()
    }

    // MARK: Fetch
    func selectSurah(_ surah: Surah) {
        selectedSurah = surah
        isLoadingAyahs = true
        currentAyahIndex = 0
        ayahs = []
        ayahResults = [:]

        guard let url = URL(string: "https://api.alquran.cloud/v1/surah/\(surah.number)/quran-uthmani") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataObj = json["data"] as? [String: Any],
                  let ayahsArr = dataObj["ayahs"] as? [[String: Any]] else { return }
            DispatchQueue.main.async {
                ayahs = ayahsArr.compactMap { a in
                    guard let num = a["numberInSurah"] as? Int,
                          let text = a["text"] as? String else { return nil }
                    return Ayah(numberInSurah: num, text: text)
                }
                isLoadingAyahs = false
            }
        }.resume()
    }

    func fetchSurahs() {
        guard let url = URL(string: "https://api.alquran.cloud/v1/surah") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArr = json["data"] as? [[String: Any]] else { return }
            DispatchQueue.main.async {
                surahs = dataArr.compactMap { s in
                    guard let num = s["number"] as? Int,
                          let name = s["name"] as? String,
                          let englishName = s["englishName"] as? String,
                          let translation = s["englishNameTranslation"] as? String else { return nil }
                    return Surah(number: num, name: name, englishName: englishName, englishNameTranslation: translation)
                }
                isLoadingSurahs = false
            }
        }.resume()
    }
}

// MARK: Models
struct Surah: Identifiable {
    let id = UUID()
    let number: Int
    let name: String
    let englishName: String
    let englishNameTranslation: String
}

struct Ayah: Identifiable {
    let id = UUID()
    let numberInSurah: Int
    let text: String
}

struct VerifyResult {
    let match: Bool
    let similarity: Double
    let minutesAdded: Double?
}
