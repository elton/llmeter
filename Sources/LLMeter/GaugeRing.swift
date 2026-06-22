import SwiftUI
import LLMeterCore

struct GaugeRing: View {
    let percent: Double
    let severity: Severity

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: 6)
            Circle()
                .trim(from: 0, to: max(0, min(1, percent / 100)))
                .stroke(Color(severity: severity), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(percent))%")
                .font(.system(size: 15, weight: .bold, design: .rounded))
        }
        .frame(width: 58, height: 58)
    }
}
