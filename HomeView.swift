import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Welkom bij BuurtKompas").appTitle()

            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Laatste nieuws uit jouw gemeente:")
                        .font(.headline)
                    Text("• Nieuwe groenvoorziening gepland in wijk Zuid.")
                    Text("• Afvalinzameling verplaatst naar dinsdag.")
                }
            }

            Spacer(minLength: 0)
        }
        .appScaffold()
    }
}
