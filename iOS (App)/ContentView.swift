import SwiftUI

struct ContentView: View {
    @State private var timeRemaining: Double = 0
    @State private var earnedToday: Double = 0
    @State private var totalTime: Double = 0
    @State private var isLoading = true

    let baseURL = "https://forward-gilly-webguardian-1b994c6d.koyeb.app"

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.12)
                    .ignoresSafeArea()

                VStack(spacing: 32) {

                    // header
                    VStack(spacing: 4) {
                        Text("وقت")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(.white)
                        Text("Waqt")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(4)
                    }
                    .padding(.top, 20)

                    // time ring
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 16)
                            .frame(width: 220, height: 220)

                        Circle()
                            .trim(from: 0, to: totalTime > 0 ? CGFloat(max(0, min(1, timeRemaining / totalTime))) : 0)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(red: 0.4, green: 0.8, blue: 0.6), Color(red: 0.2, green: 0.6, blue: 0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 16, lineCap: .round)
                            )
                            .frame(width: 220, height: 220)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.8), value: timeRemaining)

                        VStack(spacing: 4) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(formatMinutes(timeRemaining))
                                    .font(.system(size: 38, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("remaining")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                    }

//                    // earned badge
//                    HStack(spacing: 8) {
//                        Image(systemName: "plus.circle.fill")
//                            .foregroundColor(Color(red: 0.4, green: 0.8, blue: 0.6))
//                        Text("\(formatMinutes(earnedToday)) earned today")
//                            .font(.system(size: 15, weight: .medium))
//                            .foregroundColor(.white.opacity(0.7))
//                    }
//                    .padding(.horizontal, 20)
//                    .padding(.vertical, 10)
//                    .background(Color.white.opacity(0.06))
//                    .cornerRadius(20)
//
//                    Spacer()

                    // buttons
                    VStack(spacing: 12) {
                        NavigationLink(destination: ReadingView()) {
                            HStack {
                                Image(systemName: "book.fill")
                                Text("Start Reading")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.4, green: 0.8, blue: 0.6), Color(red: 0.2, green: 0.6, blue: 0.9)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                        }

                        NavigationLink(destination: SettingsView()) {
                            HStack {
                                Image(systemName: "gearshape.fill")
                                Text("Settings")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(14)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .onAppear {
                fetchTime()
                Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                    fetchTime()
                }
            }
        }
    }

    func formatMinutes(_ minutes: Double) -> String {
        let m = Int(minutes)
        if m >= 60 {
            return "\(m / 60)h \(m % 60)m"
        }
        return "\(m)m"
    }

    func fetchTime() {

        guard let url = URL(
            string: "\(baseURL)/time/remaining"
        ) else {
            return
        }

        var request = URLRequest(url: url)

        request.setValue(
            "REPLACE_WITH_ACTUAL_KEY", //add the real env key here, you can get the value from Koyeb
            forHTTPHeaderField: "x-api-key"
        )

        URLSession.shared.dataTask(with: request) { data, _, _ in

            guard
                let data = data,
                let json =
                    try? JSONSerialization.jsonObject(with: data)
                    as? [String: Any]
            else {
                return
            }

            DispatchQueue.main.async {

                timeRemaining =
                json["remaining"] as? Double ?? 0

                earnedToday =
                json["earned_minutes"] as? Double ?? 0

                totalTime =
                json["total"] as? Double ?? 0

                isLoading = false
            }

        }.resume()
    }
}


struct SettingsView: View {
    @State private var baseMinutes: String = ""
    @State private var conversionRate: String = ""
    @State private var pin: String = ""
    @State private var newPin: String = ""
    @State private var enteredPin: String = ""
    @State private var isUnlocked: Bool = false
    @State private var isLoading: Bool = true
    @State private var isSaving: Bool = false
    @State private var showSuccess: Bool = false
    @State private var pinError: Bool = false

    let baseURL = "https://forward-gilly-webguardian-1b994c6d.koyeb.app"

    var storedPin: String {
        UserDefaults.standard.string(forKey: "waqt_pin") ?? ""
    }

    var isPinSet: Bool {
        !storedPin.isEmpty
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.12)
                .ignoresSafeArea()

            if isPinSet && !isUnlocked {
                pinEntryView
            } else {
                settingsFormView
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { fetchSettings() }
    }

    // MARK: PIN Entry
    var pinEntryView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.4))

            Text("Enter PIN")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)

            // pin dots
            HStack(spacing: 16) {
                ForEach(0..<4) { i in
                    Circle()
                        .fill(i < enteredPin.count ? Color(red: 0.4, green: 0.8, blue: 0.6) : Color.white.opacity(0.15))
                        .frame(width: 16, height: 16)
                }
            }

            if pinError {
                Text("Incorrect PIN")
                    .foregroundColor(.red.opacity(0.8))
                    .font(.system(size: 14))
            }

            // numpad
            numPad(onTap: { digit in
                if enteredPin.count < 4 {
                    enteredPin += digit
                    if enteredPin.count == 4 {
                        if enteredPin == storedPin {
                            isUnlocked = true
                            pinError = false
                        } else {
                            pinError = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                enteredPin = ""
                            }
                        }
                    }
                }
            }, onDelete: {
                if !enteredPin.isEmpty { enteredPin.removeLast() }
            })

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: Settings Form
    var settingsFormView: some View {
        ScrollView {
            VStack(spacing: 20) {

                // time settings card
                settingsCard(title: "Daily Time") {
                    VStack(spacing: 16) {
                        settingsRow(
                            label: "Base minutes per day",
                            placeholder: "e.g. 60",
                            value: $baseMinutes,
                            keyboardType: .numberPad
                        )
                        Divider().background(Color.white.opacity(0.1))
                        settingsRow(
                            label: "Mins of watch per min of reading",
                            placeholder: "e.g. 10",
                            value: $conversionRate,
                            keyboardType: .decimalPad
                        )
                    }
                }

                // pin settings card
                settingsCard(title: "PIN Lock") {
                    VStack(spacing: 16) {
                        if isPinSet {
                            HStack {
                                Text("PIN is set")
                                    .foregroundColor(.white.opacity(0.6))
                                    .font(.system(size: 15))
                                Spacer()
                                Button("Remove PIN") {
                                    UserDefaults.standard.removeObject(forKey: "waqt_pin")
                                    newPin = ""
                                }
                                .foregroundColor(.red.opacity(0.8))
                                .font(.system(size: 14))
                            }
                        }

                        settingsRow(
                            label: isPinSet ? "Change PIN (4 digits)" : "Set PIN (optional, 4 digits)",
                            placeholder: "••••",
                            value: $newPin,
                            keyboardType: .numberPad,
                            isSecure: true
                        )
                    }
                }

                // save button
                Button {
                    saveSettings()
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView().tint(.black)
                        } else if showSuccess {
                            Image(systemName: "checkmark")
                            Text("Saved")
                        } else {
                            Text("Save Changes")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.4, green: 0.8, blue: 0.6), Color(red: 0.2, green: 0.6, blue: 0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                }
                .padding(.top, 4)
            }
            .padding(24)
        }
    }

    // MARK: Reusable Components
    func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)
                .textCase(.uppercase)
            content()
        }
        .padding(20)
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
    }

    func settingsRow(label: String, placeholder: String, value: Binding<String>, keyboardType: UIKeyboardType, isSecure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
            if isSecure {
                SecureField(placeholder, text: value)
                    .keyboardType(keyboardType)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
            } else {
                TextField(placeholder, text: value)
                    .keyboardType(keyboardType)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
            }
        }
    }

    func numPad(onTap: @escaping (String) -> Void, onDelete: @escaping () -> Void) -> some View {
        let digits = [["1","2","3"],["4","5","6"],["7","8","9"],["","0","⌫"]]
        return VStack(spacing: 12) {
            ForEach(digits, id: \.self) { row in
                HStack(spacing: 20) {
                    ForEach(row, id: \.self) { digit in
                        Button {
                            if digit == "⌫" { onDelete() }
                            else if digit != "" { onTap(digit) }
                        } label: {
                            Text(digit)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 72, height: 72)
                                .background(digit.isEmpty ? Color.clear : Color.white.opacity(0.08))
                                .cornerRadius(36)
                        }
                    }
                }
            }
        }
    }

    // MARK: API
    func fetchSettings() {
        guard let url = URL(string: "\(baseURL)/settings") else { return }
        var request = URLRequest(url: url)

        request.setValue(
            "REPLACE_WITH_ACTUAL_KEY", //Add real env key from Koyeb
            forHTTPHeaderField: "x-api-key"
        )

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            DispatchQueue.main.async {
                baseMinutes = "\(json["base_minutes"] as? Int ?? 60)"
                conversionRate = "\(json["conversion_rate"] as? Double ?? 10)"
                isLoading = false
            }
        }.resume()
    }

    func saveSettings() {
        guard let base = Double(baseMinutes), let rate = Double(conversionRate) else { return }
        isSaving = true

        // save PIN if entered
        if newPin.count == 4 {
            UserDefaults.standard.set(newPin, forKey: "waqt_pin")
            newPin = ""
        }

        guard let url = URL(string: "\(baseURL)/settings") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "baseMinutes": base,
            "conversionRate": rate
        ])
        request.setValue(
            "REPLACE_WITH_ACTUAL_KEY", //Add real env key from Koyeb
            forHTTPHeaderField: "x-api-key"
        )

        URLSession.shared.dataTask(with: request) { _, _, _ in
            DispatchQueue.main.async {
                isSaving = false
                showSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showSuccess = false
                }
            }
        }.resume()
    }
}
