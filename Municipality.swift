//
//  Municipalities.swift
//  BuurtKompas
//
//  Lijst + helpers voor gemeenten (Noord-Brabant, 2025)
//

import Foundation

struct Municipality: Identifiable, Hashable {
    let id: String      // slug, bv. "tilburg"
    let name: String    // label, bv. "Tilburg"
    // Geen extra id-* computed properties! Identifiable gebruikt deze 'id'.
}

enum MunicipalitiesNB {
    /// Alfabetisch (fusies verwerkt t/m 2025)
    static let all: [Municipality] = [
        Municipality(id: "altena", name: "Altena"),
        Municipality(id: "alphen-chaam", name: "Alphen-Chaam"),
        Municipality(id: "asten", name: "Asten"),
        Municipality(id: "baarle-nassau", name: "Baarle-Nassau"),
        Municipality(id: "bergeijk", name: "Bergeijk"),
        Municipality(id: "bergen-op-zoom", name: "Bergen op Zoom"),
        Municipality(id: "bernheze", name: "Bernheze"),
        Municipality(id: "best", name: "Best"),
        Municipality(id: "bladel", name: "Bladel"),
        Municipality(id: "boekel", name: "Boekel"),
        Municipality(id: "boxtel", name: "Boxtel"),
        Municipality(id: "breda", name: "Breda"),
        Municipality(id: "cranendonck", name: "Cranendonck"),
        Municipality(id: "deurne", name: "Deurne"),
        Municipality(id: "dongen", name: "Dongen"),
        Municipality(id: "drimmelen", name: "Drimmelen"),
        Municipality(id: "eersel", name: "Eersel"),
        Municipality(id: "eindhoven", name: "Eindhoven"),
        Municipality(id: "etten-leur", name: "Etten-Leur"),
        Municipality(id: "geertruidenberg", name: "Geertruidenberg"),
        Municipality(id: "geldrop-mierlo", name: "Geldrop-Mierlo"),
        Municipality(id: "gemert-bakel", name: "Gemert-Bakel"),
        Municipality(id: "gilze-en-rijen", name: "Gilze en Rijen"),
        Municipality(id: "goirle", name: "Goirle"),
        Municipality(id: "halderberge", name: "Halderberge"),
        Municipality(id: "heeze-leende", name: "Heeze-Leende"),
        Municipality(id: "helmond", name: "Helmond"),
        Municipality(id: "heusden", name: "Heusden"),
        Municipality(id: "hilvarenbeek", name: "Hilvarenbeek"),
        Municipality(id: "laarbeek", name: "Laarbeek"),
        Municipality(id: "land-van-cuijk", name: "Land van Cuijk"),
        Municipality(id: "maashorst", name: "Maashorst"),
        Municipality(id: "meierijstad", name: "Meierijstad"),
        Municipality(id: "moerdijk", name: "Moerdijk"),
        Municipality(id: "nuenen-gerwen-nederwetten", name: "Nuenen, Gerwen en Nederwetten"),
        Municipality(id: "oirschot", name: "Oirschot"),
        Municipality(id: "oisterwijk", name: "Oisterwijk"),
        Municipality(id: "oosterhout", name: "Oosterhout"),
        Municipality(id: "oss", name: "Oss"),
        Municipality(id: "reusel-de-mierden", name: "Reusel-De Mierden"),
        Municipality(id: "roosendaal", name: "Roosendaal"),
        Municipality(id: "rucphen", name: "Rucphen"),
        Municipality(id: "s-hertogenbosch", name: "'s-Hertogenbosch"),
        Municipality(id: "someren", name: "Someren"),
        Municipality(id: "son-en-breugel", name: "Son en Breugel"),
        Municipality(id: "steenbergen", name: "Steenbergen"),
        Municipality(id: "tilburg", name: "Tilburg"),
        Municipality(id: "valkenswaard", name: "Valkenswaard"),
        Municipality(id: "veldhoven", name: "Veldhoven"),
        Municipality(id: "vught", name: "Vught"),
        Municipality(id: "waalre", name: "Waalre"),
        Municipality(id: "waalwijk", name: "Waalwijk"),
        Municipality(id: "woensdrecht", name: "Woensdrecht"),
        Municipality(id: "zundert", name: "Zundert"),
    ]

    static func label(for id: String) -> String? {
        all.first { $0.id == id }?.name
    }

    static func isValid(_ id: String) -> Bool {
        all.contains { $0.id == id }
    }
}
