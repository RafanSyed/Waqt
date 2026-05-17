import SwiftUI
import Speech
import AVFoundation

struct ReadingView: View {

    // MARK: State

    @State private var surahs: [Surah] = []
    @State private var selectedSurah: Surah? = nil

    @State private var ayahs: [Ayah] = []

    @State private var isLoadingSurahs = true
    @State private var isLoadingAyahs = false

    @State private var startAyahIndex: Int? = nil
    @State private var endAyahIndex: Int? = nil

    @State private var isRecording = false
    @State private var currentTranscript = ""

    @State private var speechSeconds: Double = 0
    @State private var showSessionSummary = false

    @State private var verifySuccess = false
    @State private var similarityScore: Double = 0

    @State private var earnedMinutes: Double = 0

    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ar-SA"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?

    @State private var audioEngine = AVAudioEngine()

    let baseURL = "http://forward-gilly-webguardian-1b994c6d.koyeb.app"
    let indopakFont = "AlQuranIndoPakbyQuranWBW"

    var body: some View {

        ZStack {

            Color.black
                .ignoresSafeArea()

            if isLoadingSurahs {

                ProgressView()
                    .tint(.white)

            } else if selectedSurah == nil {

                surahPickerView

            } else {

                mushafView
            }

            if showSessionSummary {
                summaryOverlay
            }
        }
        .navigationTitle("Read")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fetchSurahs()
        }
    }
}

// MARK: Surah Picker

extension ReadingView {

    var surahPickerView: some View {

        VStack(spacing: 0) {

            Text("Select a Surah")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 20)
                .padding(.bottom, 16)

            ScrollView {

                LazyVStack(spacing: 10) {

                    ForEach(surahs) { surah in

                        Button {

                            selectSurah(surah)

                        } label: {

                            HStack {

                                ZStack {

                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(0.08))
                                        .frame(width: 42, height: 42)

                                    Text("\(surah.number)")
                                        .foregroundColor(.white.opacity(0.7))
                                        .font(.system(size: 14, weight: .semibold))
                                }

                                VStack(alignment: .leading, spacing: 3) {

                                    Text(surah.englishName)
                                        .foregroundColor(.white)
                                        .font(.system(size: 15, weight: .semibold))

                                    Text(surah.englishNameTranslation)
                                        .foregroundColor(.white.opacity(0.4))
                                        .font(.system(size: 12))
                                }

                                Spacer()

                                Text(surah.name)
                                    .font(.custom(indopakFont, size: 24))
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                        }
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: Mushaf View

extension ReadingView {

    var mushafView: some View {

        VStack(spacing: 0) {

            topBar

            if isLoadingAyahs {

                Spacer()

                ProgressView()
                    .tint(.white)

                Spacer()

            } else {

                ScrollViewReader { proxy in

                    ScrollView {

                        VStack(spacing: 0) {

                            if let surah = selectedSurah,
                               surah.number != 9 {

                                Text("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")
                                    .font(.custom(indopakFont, size: 32))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 28)
                            }

                            LazyVStack(spacing: 0) {

                                ForEach(Array(ayahs.enumerated()), id: \.element.id) { index, ayah in

                                    ayahView(ayah: ayah, index: index)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 140)
                        }
                    }
                }
            }

            bottomBar
        }
    }

    var topBar: some View {

        HStack {

            Button {

                stopRecording()

                selectedSurah = nil
                ayahs = []

                startAyahIndex = nil
                endAyahIndex = nil

            } label: {

                HStack(spacing: 5) {

                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .foregroundColor(.green)
            }

            Spacer()

            if let surah = selectedSurah {

                VStack(spacing: 3) {

                    Text(surah.name)
                        .font(.custom(indopakFont, size: 22))
                        .foregroundColor(.white)

                    Text(surah.englishName)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()

            Color.clear
                .frame(width: 50)
        }
        .padding()
        .background(Color.white.opacity(0.03))
    }
}

// MARK: Ayah View

extension ReadingView {

    func ayahView(ayah: Ayah, index: Int) -> some View {

        let isStart = startAyahIndex == index
        let isEnd = endAyahIndex == index

        return VStack(spacing: 0) {

            Button {

                handleAyahTap(index: index)

            } label: {

                VStack(alignment: .trailing, spacing: 10) {

                    Text(ayah.text)
                        .font(.custom(indopakFont, size: 30))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(18)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    HStack(spacing: 8) {

                        if isStart {

                            Text("START")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.green)
                                .cornerRadius(8)
                        }

                        if isEnd {

                            Text("END")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .cornerRadius(8)
                        }

                        Text("﴿\(ayah.numberInSurah)﴾")
                            .font(.custom(indopakFont, size: 18))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            isStart
                            ? Color.green.opacity(0.15)
                            : isEnd
                            ? Color.orange.opacity(0.15)
                            : Color.clear
                        )
                )
            }

            Divider()
                .background(Color.white.opacity(0.08))
        }
    }
}

// MARK: Bottom Bar

extension ReadingView {

    var bottomBar: some View {

        VStack(spacing: 14) {

            if !currentTranscript.isEmpty {

                Text(currentTranscript)
                    .font(.custom(indopakFont, size: 16))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 20)
            }

            HStack(spacing: 14) {

                Button {

                    clearSelection()

                } label: {

                    Text("Reset")
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 90, height: 56)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(14)
                }

                Button {

                    if isRecording {
                        stopRecordingAndVerify()
                    } else {
                        startRecording()
                    }

                } label: {

                    HStack(spacing: 10) {

                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")

                        Text(isRecording ? "Stop & Verify" : "Start Reciting")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: isRecording
                            ? [.red, .orange]
                            : [.green, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                }
                .disabled(startAyahIndex == nil)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
        }
        .padding(.top, 10)
        .background(Color.black)
    }
}

// MARK: Summary Overlay

extension ReadingView {

    var summaryOverlay: some View {

        ZStack {

            Color.black.opacity(0.75)
                .ignoresSafeArea()

            VStack(spacing: 22) {

                Image(systemName: verifySuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 62))
                    .foregroundColor(
                        verifySuccess
                        ? .green
                        : .red
                    )

                Text(verifySuccess ? "Verification Successful" : "Verification Failed")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundColor(.white)

                VStack(spacing: 16) {

                    summaryRow(
                        label: "Similarity",
                        value: "\(Int(similarityScore * 100))%"
                    )

                    summaryRow(
                        label: "Speech Time",
                        value: "\(Int(speechSeconds)) sec"
                    )

                    summaryRow(
                        label: "Minutes Earned",
                        value: String(format: "%.1f", earnedMinutes)
                    )
                }
                .padding(20)
                .background(Color.white.opacity(0.06))
                .cornerRadius(18)

                Button {

                    showSessionSummary = false

                } label: {

                    Text("Done")
                        .foregroundColor(.black)
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [.green, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                }
            }
            .padding(28)
            .background(Color(red: 0.08, green: 0.08, blue: 0.12))
            .cornerRadius(28)
            .padding(.horizontal, 28)
        }
    }

    func summaryRow(label: String, value: String) -> some View {

        HStack {

            Text(label)
                .foregroundColor(.white.opacity(0.55))

            Spacer()

            Text(value)
                .foregroundColor(.white)
                .fontWeight(.semibold)
        }
    }
}

// MARK: Logic

extension ReadingView {

    func handleAyahTap(index: Int) {

        if !isRecording {

            startAyahIndex = index
            endAyahIndex = nil

        } else {

            if index >= (startAyahIndex ?? 0) {
                endAyahIndex = index
            }
        }
    }

    func clearSelection() {

        startAyahIndex = nil
        endAyahIndex = nil

        currentTranscript = ""
    }
}

// MARK: Recording

extension ReadingView {

    func startRecording() {

        SFSpeechRecognizer.requestAuthorization { status in

            guard status == .authorized else { return }

            DispatchQueue.main.async {

                do {

                    let audioSession = AVAudioSession.sharedInstance()

                    try audioSession.setCategory(
                        .record,
                        mode: .measurement,
                        options: .duckOthers
                    )

                    try audioSession.setActive(
                        true,
                        options: .notifyOthersOnDeactivation
                    )

                    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

                    guard let recognitionRequest = recognitionRequest else {
                        return
                    }

                    recognitionRequest.shouldReportPartialResults = true

                    speechSeconds = 0

                    recognitionTask = speechRecognizer?.recognitionTask(
                        with: recognitionRequest
                    ) { result, error in

                        guard let result = result else { return }

                        currentTranscript = result.bestTranscription.formattedString

                        let segments = result.bestTranscription.segments

                        if let last = segments.last {

                            speechSeconds = last.timestamp + last.duration
                        }
                    }

                    let inputNode = audioEngine.inputNode

                    let recordingFormat = inputNode.outputFormat(forBus: 0)

                    inputNode.installTap(
                        onBus: 0,
                        bufferSize: 1024,
                        format: recordingFormat
                    ) { buffer, _ in

                        recognitionRequest.append(buffer)
                    }

                    audioEngine.prepare()

                    try audioEngine.start()

                    isRecording = true

                } catch {

                    print("Recording failed: \(error)")
                }
            }
        }
    }

    func stopRecording() {

        audioEngine.stop()

        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()

        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil

        isRecording = false
    }

    func stopRecordingAndVerify() {

        stopRecording()

        guard
            let start = startAyahIndex,
            let end = endAyahIndex,
            let surah = selectedSurah
        else {
            return
        }

        guard let url = URL(string: "\(baseURL)/verify/range") else {
            return
        }

        var request = URLRequest(url: url)

        request.httpMethod = "POST"

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        request.httpBody = try? JSONSerialization.data(
            withJSONObject: [
                "surah": surah.number,
                "startAyah": start + 1,
                "endAyah": end + 1,
                "transcript": currentTranscript
            ]
        )

        URLSession.shared.dataTask(with: request) { data, _, _ in

            guard
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data)
                    as? [String: Any]
            else {
                return
            }

            DispatchQueue.main.async {

                verifySuccess = json["match"] as? Bool ?? false

                similarityScore = json["similarity"] as? Double ?? 0

                earnedMinutes = verifySuccess
                    ? (speechSeconds / 60.0)
                    : 0

                if verifySuccess {
                    addTimeToBank(minutes: earnedMinutes)
                }

                showSessionSummary = true
            }

        }.resume()
    }
}

// MARK: Backend

extension ReadingView {

    func addTimeToBank(minutes: Double) {

        guard let url = URL(string: "\(baseURL)/time/add") else {
            return
        }

        var request = URLRequest(url: url)

        request.httpMethod = "POST"

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        request.httpBody = try? JSONSerialization.data(
            withJSONObject: [
                "minutes": minutes
            ]
        )

        URLSession.shared.dataTask(with: request).resume()
    }
}

// MARK: Fetch

extension ReadingView {

    func selectSurah(_ surah: Surah) {

        selectedSurah = surah

        isLoadingAyahs = true

        startAyahIndex = nil
        endAyahIndex = nil

        currentTranscript = ""

        guard let url = URL(
            string: "https://api.alquran.cloud/v1/surah/\(surah.number)/quran-uthmani"
        ) else {
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in

            guard
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data)
                    as? [String: Any],
                let dataObj = json["data"] as? [String: Any],
                let ayahsArr = dataObj["ayahs"] as? [[String: Any]]
            else {
                return
            }

            DispatchQueue.main.async {

                ayahs = ayahsArr.compactMap { ayah in

                    guard
                        let num = ayah["numberInSurah"] as? Int,
                        let text = ayah["text"] as? String
                    else {
                        return nil
                    }

                    return Ayah(
                        numberInSurah: num,
                        text: text
                    )
                }

                isLoadingAyahs = false
            }

        }.resume()
    }

    func fetchSurahs() {

        guard let url = URL(
            string: "https://api.alquran.cloud/v1/surah"
        ) else {
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in

            guard
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data)
                    as? [String: Any],
                let dataArr = json["data"] as? [[String: Any]]
            else {
                return
            }

            DispatchQueue.main.async {

                surahs = dataArr.compactMap { s in

                    guard
                        let number = s["number"] as? Int,
                        let name = s["name"] as? String,
                        let englishName = s["englishName"] as? String,
                        let translation = s["englishNameTranslation"] as? String
                    else {
                        return nil
                    }

                    return Surah(
                        number: number,
                        name: name,
                        englishName: englishName,
                        englishNameTranslation: translation
                    )
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
