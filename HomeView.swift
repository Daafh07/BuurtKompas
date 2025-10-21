import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Welkom bij BuurtKompas").appTitle()

            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Laatste nieuws uit jouw gemeente:")
                        .font(.headline)
                    Text("• Nieuwe speeltuin aangelegd in de Vlindervalei.")
                    Text("• Gemeentestraat verplaatst naar een nieuwe locatie, Ijzerstraat 6.")
                    Text("• Gemeente Oosterhout benoemd tot 'Het beste opkomende stadje van Nederland'.")
                    Text("• Zwemmen bij de warande nu gratis mogelijk voor iedereen onder de 12 jaar!")
                }
            }

            Spacer(minLength: 0)
        }
        .appScaffold()
    }
}
