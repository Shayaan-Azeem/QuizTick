import SwiftUI
import AVFoundation

class SoundPlayer {
    var audioPlayer: AVAudioPlayer?

    func playSound(named name: String) {
        guard let path = Bundle.main.path(forResource: name, ofType: nil) else {
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            audioPlayer?.play()
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    }
}

struct TimerView: View {
    @State private var numberOfMarks = ""
    @State private var selectedSubject: Subject = .standardIB
    @State private var timerValue = 0
    @State private var marksCompleted = 0
    @State private var isTimerRunning = false
    @State private var timer: Timer?
    @State private var isPaused = false
    @State private var isCustomSubjectSheetPresented = false
    @State private var customSubject = CustomSubject(title: "", timePerQuestion: 0)
    @State private var soundPlayer = SoundPlayer()

    struct CustomSubject {
        var title: String
        var timePerQuestion: TimeInterval
    }

    enum Subject: String, CaseIterable {
        case standardIB = "IB Standard"
        case satReadingWriting = "SAT Reading/Writing"
        case satMath = "SAT Math"
        case actEnglish = "ACT English"
        case actMath = "ACT Math"
        case actReading = "ACT Reading"
        case actScience = "ACT Science"
        case custom = "Custom"

        var timePerMark: TimeInterval {
            switch self {
            case .standardIB: return 1.5 * 60
            case .satReadingWriting: return 1 * 60 + 11
            case .satMath: return 1 * 60 + 35
            case .actEnglish: return 36
            case .actMath: return 1 * 60
            case .actReading, .actScience: return 52
            case .custom: return 0
            }
        }
    }

    var body: some View {
        TabView {
            TimerContentView(numberOfMarks: $numberOfMarks, selectedSubject: $selectedSubject, timerValue: $timerValue, marksCompleted: $marksCompleted, isTimerRunning: $isTimerRunning, timer: $timer, isPaused: $isPaused, isCustomSubjectSheetPresented: $isCustomSubjectSheetPresented, customSubject: $customSubject, soundPlayer: soundPlayer)
                .tabItem {
                    Image(systemName: "clock")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .padding()
                        .foregroundColor(Color.yellow) // Set the color of the icon to yellow
                        .background(Color.clear) // Background color is set to clear
                    Text("Timer")
                        .foregroundColor(Color.yellow) // Set the color of the text to yellow
                }
        }
        .sheet(isPresented: $isCustomSubjectSheetPresented) {
            CustomSubjectView(isSheetPresented: $isCustomSubjectSheetPresented, customSubject: $customSubject)
        }
    }
}

struct TimerContentView: View {
    @Binding var numberOfMarks: String
    @Binding var selectedSubject: TimerView.Subject
    @Binding var timerValue: Int
    @Binding var marksCompleted: Int
    @Binding var isTimerRunning: Bool
    @Binding var timer: Timer?
    @Binding var isPaused: Bool
    @Binding var isCustomSubjectSheetPresented: Bool
    @Binding var customSubject: TimerView.CustomSubject
    var soundPlayer: SoundPlayer

    var body: some View {
        VStack {
            Spacer()

            Text("\(formattedTime(timerValue))")
                .font(.system(size: 100)) // Adjust the size to your preference
                .fontWeight(.bold)
                .padding(-5)

            Picker("Select Subject", selection: $selectedSubject) {
                ForEach(TimerView.Subject.allCases, id: \.self) { subject in
                    Text(subject.rawValue)
                }
            }
            .onChange(of: selectedSubject) { newSubject in
                if newSubject == .custom {
                    isCustomSubjectSheetPresented = true
                }
            }
            .padding()
            .pickerStyle(MenuPickerStyle())
            .frame(width: 200)
            .accentColor(Color.yellow)

            TextField("#  of marks / questions", text: $numberOfMarks)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
                .frame(width: 300)
                .multilineTextAlignment(.center)


            HStack {
                Button(action: {
                    if isTimerRunning {
                        pauseTimer()
                    } else {
                        startTimer()
                    }
                }) {
                    Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .padding()
                        .background(Color.yellow)
                        .foregroundColor(Color.white)
                        .cornerRadius(10)
                }
                .disabled(numberOfMarks.isEmpty)

                if isPaused {
                    Button(action: {
                        // Add your save logic here
                    }) {
                        Text("Save")
                            .padding()
                            .background(Color.yellow)
                            .foregroundColor(Color.white)
                            .cornerRadius(10)
                    }
                }
            }

            Spacer()
        }
        .onAppear {
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
                withAnimation {
                    // Move the view up when the keyboard appears
                    // (Adjust based on your UI)
                }
            }

            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                withAnimation {
                    // Move the view back down when the keyboard disappears
                    // (Adjust based on your UI)
                }
            }
        }
    }

    private func startTimer() {
        guard let numberOfMarksInt = Int(numberOfMarks) else {
            return
        }

        if selectedSubject == .custom {
            timerValue = Int(customSubject.timePerQuestion) * numberOfMarksInt
        } else {
            timerValue = Int(selectedSubject.timePerMark) * numberOfMarksInt
        }

        isTimerRunning = true
        isPaused = false
        marksCompleted = 0

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if self.timerValue > 0 {
                self.timerValue -= 1
                // Check if a whole interval has passed
                if self.timerValue % (selectedSubject == .custom ? Int(customSubject.timePerQuestion) : Int(selectedSubject.timePerMark)) == 0 {
                    self.updateMarksCompleted()
                }
            } else {
                timer.invalidate()
                self.isTimerRunning = false
                self.isPaused = true

                // Play sound when the total timer ends
                soundPlayer.playSound(named: "Beep3.wav")
            }
        }
    }

    private func pauseTimer() {
        timer?.invalidate()
        isTimerRunning = false
        isPaused = true
    }

    private func updateMarksCompleted() {
        let timePerMark = selectedSubject == .custom ? Int(customSubject.timePerQuestion) : Int(selectedSubject.timePerMark)

        let elapsedTime = (selectedSubject == .custom ? Int(customSubject.timePerQuestion) : Int(selectedSubject.timePerMark)) - timerValue % timePerMark
        marksCompleted = elapsedTime > 0 ? (elapsedTime + timePerMark - 1) / timePerMark : 0

        // Play sound when marks completed increase
        if marksCompleted > 0 {
            soundPlayer.playSound(named: "Beep1.wav")
        }
    }

    private func formattedTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

struct CustomSubjectView: View {
    @Binding var isSheetPresented: Bool
    @Binding var customSubject: TimerView.CustomSubject
    @State private var customSubjectTitle = ""
    @State private var customSubjectTimePerQuestion = ""

    var body: some View {
        VStack {
            TextField("Custom Subject Title", text: $customSubjectTitle)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())

            TextField("Time Per Question (seconds)", text: $customSubjectTimePerQuestion)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)

            Button("Save Custom Subject") {
                if let timePerQuestion = Int(customSubjectTimePerQuestion) {
                    customSubject = TimerView.CustomSubject(title: customSubjectTitle, timePerQuestion: TimeInterval(timePerQuestion))
                }
                isSheetPresented = false
            }
            .padding()
            .background(Color.yellow)
            .foregroundColor(Color.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

@main
struct TimerApp: App {
    var body: some Scene {
        WindowGroup {
            TimerView()
        }
    }
}

