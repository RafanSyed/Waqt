import SwiftUI
import Speech
import AVFoundation

struct ReadingView: View {

    // MARK: State

    @State private var surahs: [Surah] = []
    @State private var selectedSurah: Surah? = nil
    @State private var selectedPage: Int? = nil
    @State private var availablePages: [Int] = []
    @State private var pageAyahs: [Ayah] = []

    @State private var isLoadingSurahs = true
    @State private var isLoadingPages = false
    @State private var isLoadingPageContent = false

    @State private var isRecording = false
    @State private var currentTranscript = ""
    @Environment(\.dismiss) var dismiss

    @State private var showSessionSummary = false
    @State private var verifySuccess = false
    @State private var similarityScore: Double = 0
    @State private var earnedMinutes: Double = 0
    @State private var speechSeconds: Double = 0
    @State private var recordingStartTime: Date? = nil
    @State private var isVerifying = false

    @State private var speechRecognizer =
    SFSpeechRecognizer(locale: Locale(identifier: "ar-SA"))

    @State private var recognitionRequest:
    SFSpeechAudioBufferRecognitionRequest?

    @State private var recognitionTask:
    SFSpeechRecognitionTask?

    @State private var audioEngine = AVAudioEngine()

    let baseURL =
    "https://forward-gilly-webguardian-1b994c6d.koyeb.app"

    let indopakFont = "AlQuranIndoPakbyQuranWBW"

    var body: some View {

        ZStack {

            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.05, blue: 0.08),
                    Color(red: 0.07, green: 0.10, blue: 0.14)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if isLoadingSurahs {

                ProgressView()
                    .tint(.white)

            } else if selectedSurah == nil {

                surahPickerView

            } else if selectedPage == nil {

                pagePickerView

            } else {

                mushafView
            }

            if showSessionSummary {
                summaryOverlay
            }

            if isVerifying {
                verifyingOverlay
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            fetchSurahs()
        }
    }
}

// MARK: Surah Picker

extension ReadingView {

    var surahPickerView: some View {

        VStack(alignment: .leading, spacing: 0) {

            HStack {

                Button {

                    dismiss()

                } label: {

                    HStack(spacing: 5) {

                        Image(systemName: "chevron.left")

                        Text("Home")
                    }
                    .foregroundColor(.green)
                }

                Spacer()

                Text("Read Quran")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Color.clear.frame(width: 55)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 20)

            Text("Choose a Surah")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.bottom, 18)

            ScrollView {

                LazyVStack(spacing: 12) {

                    ForEach(surahs) { surah in

                        Button {

                            selectSurah(surah)

                        } label: {

                            HStack(spacing: 14) {

                                ZStack {

                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white.opacity(0.08))
                                        .frame(width: 50, height: 50)

                                    Text("\(surah.number)")
                                        .foregroundColor(.white)
                                        .font(
                                            .system(
                                                size: 15,
                                                weight: .bold
                                            )
                                        )
                                }

                                VStack(
                                    alignment: .leading,
                                    spacing: 4
                                ) {

                                    Text(surah.englishName)
                                        .foregroundColor(.white)
                                        .font(
                                            .system(
                                                size: 17,
                                                weight: .semibold
                                            )
                                        )

                                    Text(surah.englishNameTranslation)
                                        .foregroundColor(
                                            .white.opacity(0.45)
                                        )
                                        .font(.system(size: 13))
                                }

                                Spacer()

                                Text(surah.name)
                                    .font(
                                        .custom(
                                            indopakFont,
                                            size: 28
                                        )
                                    )
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(Color.white.opacity(0.05))
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: Page Picker

extension ReadingView {

    var pagePickerView: some View {

        VStack(alignment: .leading, spacing: 0) {

            HStack {

                Button {

                    selectedSurah = nil
                    availablePages = []

                } label: {

                    HStack(spacing: 5) {

                        Image(systemName: "chevron.left")

                        Text("Back")
                    }
                    .foregroundColor(.green)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            if let surah = selectedSurah {

                VStack(alignment: .leading, spacing: 8) {

                    Text(surah.name)
                        .font(.custom(indopakFont, size: 42))
                        .foregroundColor(.white)

                    Text(surah.englishName)
                        .foregroundColor(.white.opacity(0.7))
                        .font(
                            .system(
                                size: 18,
                                weight: .semibold
                            )
                        )

                    Text("Choose a page to recite")
                        .foregroundColor(.white.opacity(0.4))
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 22)
            }

            if isLoadingPages {

                Spacer()

                ProgressView()
                    .tint(.white)

                Spacer()

            } else {

                ScrollView {

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ],
                        spacing: 14
                    ) {

                        ForEach(availablePages, id: \.self) { page in

                            Button {

                                loadPage(page)

                            } label: {

                                VStack(spacing: 10) {

                                    Text("Page")
                                        .foregroundColor(
                                            .white.opacity(0.5)
                                        )
                                        .font(.system(size: 12))

                                    Text("\(page)")
                                        .foregroundColor(.white)
                                        .font(
                                            .system(
                                                size: 28,
                                                weight: .bold
                                            )
                                        )
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 110)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(
                                            Color.white.opacity(0.06)
                                        )
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: Mushaf View

// MARK: Mushaf View

extension ReadingView {

    var mushafView: some View {

        VStack(spacing: 0) {

            // TOP SECTION
            VStack(alignment: .leading, spacing: 10) {

                HStack {

                    Button {

                        stopRecording()

                        selectedPage = nil
                        pageAyahs = []
                        currentTranscript = ""

                    } label: {

                        HStack(spacing: 5) {

                            Image(systemName: "chevron.left")
                            Text("Pages")
                        }
                        .foregroundColor(.green)
                    }

                    Spacer()
                }

                if let surah = selectedSurah {

                    VStack(alignment: .leading, spacing: 4) {

                        Text(surah.name)
                            .font(.custom(indopakFont, size: 40))
                            .foregroundColor(.white)

                        Text(surah.englishName)
                            .foregroundColor(.white.opacity(0.7))
                            .font(.system(size: 18, weight: .semibold))

                        if let page = selectedPage {

                            Text("Page \(page)")
                                .foregroundColor(.green.opacity(0.9))
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 14)

            // PAGE CONTENT
            if isLoadingPageContent {

                Spacer()

                ProgressView()
                    .tint(.white)

                Spacer()

            } else {

                ScrollView {

                    VStack(spacing: 0) {

                        VStack(alignment: .trailing, spacing: 0) {

                            if let surah = selectedSurah,
                               surah.number != 9 {

                                Text("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")
                                    .font(.custom(indopakFont, size: 36))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.bottom, 26)
                            }

                            VStack(alignment: .trailing, spacing: 18) {

                                ForEach(Array(pageAyahs.enumerated()), id: \.element.id) { index, ayah in

                                    let previousSurah =
                                    index > 0
                                    ? pageAyahs[index - 1].surahNumber
                                    : selectedSurah?.number

                                    let isNewSurah =
                                    ayah.surahNumber != previousSurah

                                    VStack(alignment: .trailing, spacing: 14) {

                                        if isNewSurah {

                                            VStack(spacing: 10) {

                                                Text(ayah.surahName)
                                                    .font(.custom(indopakFont, size: 38))
                                                    .foregroundColor(.green)

                                                if ayah.surahNumber != 9 {

                                                    Text("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")
                                                        .font(.custom(indopakFont, size: 32))
                                                        .foregroundColor(.cyan)
                                                }
                                            }
                                            .padding(.vertical, 10)
                                        }

                                        Text("\(ayah.text) ﴿\(ayah.numberInSurah)﴾")
                                            .font(.custom(indopakFont, size: 33))
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.trailing)
                                            .lineSpacing(18)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(26)
                        .background(
                            RoundedRectangle(cornerRadius: 30)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.12, green: 0.14, blue: 0.18),
                                            Color(red: 0.09, green: 0.11, blue: 0.14)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)

                        Spacer(minLength: 160)
                    }
                }
            }

            bottomBar
        }
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: Bottom Bar

extension ReadingView {

    var bottomBar: some View {

        VStack(spacing: 14) {

            if !currentTranscript.isEmpty {

                VStack(
                    alignment: .trailing,
                    spacing: 10
                ) {

                    Text("Live Transcript")
                        .foregroundColor(
                            .white.opacity(0.45)
                        )
                        .font(
                            .system(
                                size: 12,
                                weight: .semibold
                            )
                        )

                    Text(currentTranscript)
                        .font(
                            .custom(
                                indopakFont,
                                size: 15
                            )
                        )
                        .foregroundColor(
                            .white.opacity(0.8)
                        )
                        .multilineTextAlignment(.trailing)
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .trailing
                )
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.05))
                )
                .padding(.horizontal, 18)
            }

            HStack(spacing: 14) {

                Button {

                    currentTranscript = ""

                } label: {

                    Text("Reset")
                        .foregroundColor(
                            .white.opacity(0.75)
                        )
                        .frame(width: 95, height: 58)
                        .background(
                            Color.white.opacity(0.08)
                        )
                        .cornerRadius(16)
                }

                Button {

                    if isRecording {
                        stopRecordingAndVerify()
                    } else {
                        startRecording()
                    }

                } label: {

                    HStack(spacing: 10) {

                        Image(
                            systemName:
                            isRecording
                            ? "stop.fill"
                            : "mic.fill"
                        )

                        Text(
                            isRecording
                            ? "Stop & Verify"
                            : "Start Reciting"
                        )
                        .fontWeight(.bold)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        LinearGradient(
                            colors:
                            isRecording
                            ? [.red, .orange]
                            : [.green, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(18)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .padding(.top, 12)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.001),
                    Color.black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: Summary

extension ReadingView {

    var summaryOverlay: some View {

        ZStack {

            Color.black.opacity(0.78)
                .ignoresSafeArea()

            VStack(spacing: 22) {

                Image(
                    systemName:
                    verifySuccess
                    ? "checkmark.circle.fill"
                    : "xmark.circle.fill"
                )
                .font(.system(size: 64))
                .foregroundColor(
                    verifySuccess
                    ? .green
                    : .red
                )

                Text(
                    verifySuccess
                    ? "Verification Successful"
                    : "Verification Failed"
                )
                .font(
                    .system(
                        size: 25,
                        weight: .bold
                    )
                )
                .foregroundColor(.white)

                VStack(spacing: 16) {

                    summaryRow(
                        label: "Similarity",
                        value:
                        "\(Int(similarityScore * 100))%"
                    )

                    summaryRow(
                        label: "Speech Time",
                        value:
                        "\(Int(speechSeconds))s"
                    )

                    if verifySuccess {

                        summaryRow(
                            label: "Minutes Earned",
                            value:
                            String(
                                format: "+%.1f min",
                                earnedMinutes
                            )
                        )
                    }
                }
                .padding(20)
                .background(
                    Color.white.opacity(0.06)
                )
                .cornerRadius(20)

                Button {

                    showSessionSummary = false
                    currentTranscript = ""

                } label: {

                    Text("Done")
                        .foregroundColor(.black)
                        .font(
                            .system(
                                size: 17,
                                weight: .bold
                            )
                        )
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
            .background(
                Color(
                    red: 0.08,
                    green: 0.08,
                    blue: 0.12
                )
            )
            .cornerRadius(30)
            .padding(.horizontal, 28)
        }
    }

    var verifyingOverlay: some View {

        ZStack {

            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 18) {

                ProgressView()
                    .tint(.white)

                Text("Verifying your recitation...")
                    .foregroundColor(.white)
                    .font(
                        .system(
                            size: 16,
                            weight: .medium
                        )
                    )
            }
        }
    }

    func summaryRow(
        label: String,
        value: String
    ) -> some View {

        HStack {

            Text(label)
                .foregroundColor(
                    .white.opacity(0.55)
                )

            Spacer()

            Text(value)
                .foregroundColor(.white)
                .fontWeight(.semibold)
        }
    }
}

// MARK: Recording

extension ReadingView {

    func startRecording() {

        currentTranscript = ""
        speechSeconds = 0

        SFSpeechRecognizer.requestAuthorization { status in

            guard status == .authorized else {
                return
            }

            DispatchQueue.main.async {

                do {

                    let audioSession =
                    AVAudioSession.sharedInstance()

                    try audioSession.setCategory(
                        .record,
                        mode: .measurement,
                        options: .duckOthers
                    )

                    try audioSession.setActive(
                        true,
                        options:
                        .notifyOthersOnDeactivation
                    )

                    recognitionRequest =
                    SFSpeechAudioBufferRecognitionRequest()

                    guard let recognitionRequest =
                    recognitionRequest else {
                        return
                    }

                    recognitionRequest
                        .shouldReportPartialResults = true

                    recognitionTask =
                    speechRecognizer?.recognitionTask(
                        with: recognitionRequest
                    ) { result, error in

                        guard let result = result else {
                            return
                        }

                        DispatchQueue.main.async {

                            currentTranscript =
                            result
                                .bestTranscription
                                .formattedString
                        }
                    }

                    let inputNode =
                    audioEngine.inputNode

                    inputNode.removeTap(onBus: 0)

                    let format =
                    inputNode.outputFormat(forBus: 0)

                    inputNode.installTap(
                        onBus: 0,
                        bufferSize: 1024,
                        format: format
                    ) { buffer, _ in

                        recognitionRequest.append(buffer)
                    }

                    audioEngine.prepare()

                    try audioEngine.start()

                    recordingStartTime = Date()

                    isRecording = true

                } catch {

                    print(
                        "Recording failed: \(error)"
                    )
                }
            }
        }
    }

    func stopRecording() {

        guard isRecording else {
            return
        }

        audioEngine.stop()

        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()

        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil

        isRecording = false
    }

    func stopRecordingAndVerify() {

        let elapsed =
        recordingStartTime.map {
            Date().timeIntervalSince($0)
        } ?? 0

        speechSeconds = elapsed

        stopRecording()

        guard
            let page = selectedPage,
            !currentTranscript.isEmpty
        else {
            return
        }

        isVerifying = true

        guard let url =
        URL(string: "\(baseURL)/verify")
        else {
            return
        }

        var request = URLRequest(url: url)

        request.httpMethod = "POST"

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        request.httpBody =
        try? JSONSerialization.data(
            withJSONObject: [
                "page": page,
                "transcript": currentTranscript,
                "speechSeconds": speechSeconds
            ]
        )

        URLSession.shared.dataTask(
            with: request
        ) { data, _, _ in

            guard
                let data = data,
                let json =
                try? JSONSerialization.jsonObject(
                    with: data
                ) as? [String: Any]
            else {

                DispatchQueue.main.async {
                    isVerifying = false
                }

                return
            }

            DispatchQueue.main.async {

                isVerifying = false

                verifySuccess =
                json["verified"] as? Bool ?? false

                similarityScore =
                json["similarity"] as? Double ?? 0

                earnedMinutes =
                json["minutesEarned"] as? Double ?? 0

                showSessionSummary = true
            }
        }
        .resume()
    }
}

// MARK: Fetching

extension ReadingView {

    func selectSurah(_ surah: Surah) {

        selectedSurah = surah

        isLoadingPages = true

        availablePages = []

        guard let url = URL(
            string:
            "https://api.alquran.cloud/v1/surah/\(surah.number)/quran-uthmani"
        ) else {
            return
        }

        URLSession.shared.dataTask(
            with: url
        ) { data, _, _ in

            guard
                let data = data,
                let json =
                try? JSONSerialization
                    .jsonObject(with: data)
                    as? [String: Any],
                let dataObj =
                json["data"] as? [String: Any],
                let ayahsArr =
                dataObj["ayahs"] as? [[String: Any]]
            else {
                return
            }

            let pages = Set(
                ayahsArr.compactMap {
                    $0["page"] as? Int
                }
            )

            DispatchQueue.main.async {

                availablePages =
                Array(pages).sorted()

                isLoadingPages = false
            }
        }
        .resume()
    }

    func loadPage(_ page: Int) {

        selectedPage = page

        isLoadingPageContent = true

        pageAyahs = []

        guard let url = URL(
            string:
            "https://api.alquran.cloud/v1/page/\(page)/quran-uthmani"
        ) else {
            return
        }

        URLSession.shared.dataTask(
            with: url
        ) { data, _, _ in

            guard
                let data = data,
                let json =
                try? JSONSerialization
                    .jsonObject(with: data)
                    as? [String: Any],
                let dataObj =
                json["data"] as? [String: Any],
                let ayahsArr =
                dataObj["ayahs"] as? [[String: Any]]
            else {
                return
            }

            DispatchQueue.main.async {

                pageAyahs =
                ayahsArr.compactMap { a in

                    guard
                        let num =
                        a["numberInSurah"] as? Int,
                        let text =
                        a["text"] as? String
                    else {
                        return nil
                    }

                    let surahObj =
                    a["surah"] as? [String: Any]

                    let surahNumber =
                    surahObj?["number"] as? Int ?? 0

                    let surahName =
                    surahObj?["name"] as? String ?? ""

                    return Ayah(
                        numberInSurah: num,
                        text: text,
                        surahNumber: surahNumber,
                        surahName: surahName
                    )
                }

                isLoadingPageContent = false
            }
        }
        .resume()
    }

    func fetchSurahs() {

        guard let url = URL(
            string:
            "https://api.alquran.cloud/v1/surah"
        ) else {
            return
        }

        URLSession.shared.dataTask(
            with: url
        ) { data, _, _ in

            guard
                let data = data,
                let json =
                try? JSONSerialization
                    .jsonObject(with: data)
                    as? [String: Any],
                let dataArr =
                json["data"] as? [[String: Any]]
            else {
                return
            }

            DispatchQueue.main.async {

                surahs =
                dataArr.compactMap { s in

                    guard
                        let number =
                        s["number"] as? Int,
                        let name =
                        s["name"] as? String,
                        let englishName =
                        s["englishName"] as? String,
                        let translation =
                        s["englishNameTranslation"]
                        as? String
                    else {
                        return nil
                    }

                    return Surah(
                        number: number,
                        name: name,
                        englishName: englishName,
                        englishNameTranslation:
                        translation
                    )
                }

                isLoadingSurahs = false
            }
        }
        .resume()
    }
}

// MARK: Helpers

extension ReadingView {

    var fullPageText: String {

        pageAyahs
            .map {
                "\($0.text) ﴿\($0.numberInSurah)﴾"
            }
            .joined(separator: " ")
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
    let surahNumber: Int
    let surahName: String
}
