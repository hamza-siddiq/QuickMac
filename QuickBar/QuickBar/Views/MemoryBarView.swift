import SwiftUI

struct MemoryBarView: View {
    let used: Double
    let total: Double
    let purgeable: Double
    let percent: Double

    var body: some View {
        VStack(spacing: 6) {
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
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor).opacity(0.3))
                        .frame(height: 3)

                    Rectangle()
                        .fill(Color(nsColor: .secondaryLabelColor).opacity(0.5))
                        .frame(width: geometry.size.width * CGFloat(min(percent, 100) / 100), height: 3)
                }
                .clipShape(RoundedRectangle(cornerRadius: 1.5))
            }
            .frame(height: 3)
        }
    }
}
