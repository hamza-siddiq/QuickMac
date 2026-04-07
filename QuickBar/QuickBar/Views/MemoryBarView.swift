import SwiftUI

struct MemoryBarView: View {
    let used: Double
    let total: Double
    let purgeable: Double
    let percent: Double

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text("\(used, specifier: "%.1f") / \(total, specifier: "%.1f") GB")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Spacer()

                if purgeable > 0.5 {
                    Text("~\(purgeable, specifier: "%.1f") GB can be freed")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.12))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(min(percent, 100) / 100))
                }
            }
            .frame(height: 4)
        }
    }
}
