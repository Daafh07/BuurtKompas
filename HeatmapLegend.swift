import SwiftUI

struct HeatmapLegend: View {
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Dichtheid").font(.caption).foregroundStyle(.secondary)
                LinearGradient(
                    colors: [
                        Color(red: 0.00, green: 0.22, blue: 0.60),
                        Color(red: 0.00, green: 0.65, blue: 0.74),
                        Color(red: 0.40, green: 0.85, blue: 0.40),
                        Color(red: 0.98, green: 0.87, blue: 0.20),
                        Color(red: 0.95, green: 0.35, blue: 0.25)
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 10)
                .cornerRadius(6)
                HStack {
                    Text("Laag").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("Hoog").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(width: 180)
        }
    }
}
