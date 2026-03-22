//
//----------------------------------------------
// Original project: GiftRegistry
//
// Follow me on Mastodon: https://iosdev.space/@StewartLynch
// Follow me on Threads: https://www.threads.net/@stewartlynch
// Follow me on Bluesky: https://bsky.app/profile/stewartlynch.bsky.social
// Follow me on X: https://x.com/StewartLynch
// Follow me on LinkedIn: https://linkedin.com/in/StewartLynch
// Email: slynch@createchsol.com
// Subscribe on YouTube: https://youTube.com/@StewartLynch
// Buy me a ko-fi:  https://ko-fi.com/StewartLynch
//----------------------------------------------
// Copyright © 2026 CreaTECH Solutions (Stewart Lynch). All rights reserved.


import SwiftUI
import SQLiteData

@MainActor
@Observable
class GiftListViewModel {
    var personID: Person.ID
    
    init(personID: Person.ID) {
        self.personID = personID
        Task {
            await loadGiftsWithImageData()
        }
    }
    @Selection
    struct GiftWithImageData: Identifiable {
        let gift: Gift
        let giftImageData: Data?
        
        var id: Gift.ID { gift.id }
    }

    @ObservationIgnored
    @FetchAll(GiftWithImageData.none) var giftsWithImageData
    
    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database
    
    func loadGiftsWithImageData() async {
        await withErrorReporting {
            _ = try await $giftsWithImageData.load(
                    Gift
                        .group(by: \.id)
                        .order {
                            ($0.isPurchased.desc(), $0.name)
                        }
                        .where {
                            $0.personID.is(personID)
                        }
                        .leftJoin(GiftAsset.all) {
                            $0.id.eq($1.giftID)
                        }
                        .select {
                            GiftWithImageData.Columns(gift: $0, giftImageData: $1.giftImageData)
                        }, animation: .default
                )
        }
    }
    
    func deleteButtonTapped(_ gift: Gift) {
        withErrorReporting {
            try database.write { db in
                try Gift
                    .delete(gift)
                    .execute(db)
            }
        }
    }
    
    func purchaseButtonTapped(_ gift: Gift) {
        withErrorReporting {
            try database.write { db in
                try Gift
                    .find(gift.id)
                    .update {
                        $0.isPurchased = #bind(!gift.isPurchased)
                        $0.updatedAt = #bind(Date())
                    }
                    .execute(db)
            }
        }
    }
}

struct GiftListView: View {
    @State private var model: GiftListViewModel
    @State private var gift: Gift.Draft?
    init(personID: Person.ID) {
        self._model = State(initialValue: GiftListViewModel(personID: personID))
    }
    var body: some View {
        Section  {
            List {
                ForEach(model.giftsWithImageData) { giftWithImageData in
                    GiftRow(
                        imageData: giftWithImageData.giftImageData,
                        gift: giftWithImageData.gift,
                        model: model
                    )
                }
            }
        } header:  {
            HStack {
                Text("Gifts")
                Spacer()
                Button {
                    gift = Gift.Draft(personID: model.personID)
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
            .sheet(item: $gift) { gift in
                GiftForm(gift: gift, selectedOccasions: [])
                    .presentationSizing(.page)
            }
        }
    }
}

#Preview {
    let person = prepareDependencies {
         do {
             try $0.bootstrapDatabase()
             try $0.seedDatabaseForPreviews()
             return try $0.defaultDatabase.read { db in
                 try Person.find(UUID(0))
                     .fetchOne(db)!
             }
         } catch {
             fatalError("Failed to bootstrap database for previews: \(error)")
         }
     }
    Form {
        GiftListView(personID: person.id)
    }
}


struct GiftRow: View {
    let imageData: Data?
    let gift: Gift
    let model: GiftListViewModel
    @State private var selectedGift: Gift.Draft?
    @FetchAll(Occasion.none) var occasions
    init(imageData: Data?, gift: Gift, model: GiftListViewModel) {
        self.imageData = imageData
        self.gift = gift
        self.model = model
        self._occasions = FetchAll(
            Occasion
                .join(OccasionGift.all) { $0.id.eq($1.occasionID) }
                .where { $1.giftID.eq(gift.id) }
                .order { occasion, _ in
                    occasion.name
                }
                .select { occasion, _ in
                    Occasion.Columns(
                        id: occasion.id,
                        name: occasion.name,
                        hexColor: occasion.hexColor
                    )
                }
        )
    }
    var body: some View {
        HStack {
            Button {
                model.purchaseButtonTapped(gift)
            } label: {
                Image(systemName: gift.isPurchased ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(gift.isPurchased ? .green : .secondary)
            }
            .buttonStyle(.plain)
            if let imageData,
               let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(.circle)
            }
            VStack(alignment: .leading) {
                Text(gift.name)
                    .strikethrough(gift.isPurchased)
                if let price = gift.price {
                    Text(price, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let updatedAt = gift.updatedAt {
                    Text("Updated: \(updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !occasions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(occasions) { occasion in
                                Text(occasion.name)
                                    .font(.caption2)
                                    .padding(.vertical, 3)
                                    .padding(.horizontal, 8)
                                    .background(occasion.color, in: .capsule)
                                    .foregroundStyle(occasion.color.adaptedTextColor)
                            }
                        }
                    }
                }
            }
            Spacer()
            Button {
                // EditButton Tapped
                self.selectedGift = Gift.Draft(gift)
            } label: {
                Image(systemName: "pencil.circle")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                model.deleteButtonTapped(gift)
            }
        }
        .sheet(item: $selectedGift) { gift in
            GiftForm(gift: gift, selectedOccasions: occasions)
                .presentationSizing(.page)
        }
    }
}
