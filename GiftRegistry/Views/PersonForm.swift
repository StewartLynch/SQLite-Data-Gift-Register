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


import SQLiteData
import SwiftUI

@MainActor
@Observable
class PersonFormModel {
    var person: Person.Draft
    var name:String
    var birthDate: Date?
    var notes: String
    var dateBinding: Binding<Date> {
        Binding {
            self.birthDate ?? Date.now
        } set: { setDate in
            self.birthDate = setDate
        }
    }
    @ObservationIgnored
    @Dependency(\.defaultDatabase) var database
    
    @ObservationIgnored
    @FetchAll(Gift.none) var gifts
    
    init(person: Person.Draft) {
        self.person = person
        name = person.name
        birthDate = person.birthDate
        notes = person.notes
        Task {
            await loadGifts()
        }
    }
    
    func loadGifts() async {
        await withErrorReporting {
            _ = try await $gifts.load(
                Gift.all
                    .order {
                        ($0.isPurchased.desc(), $0.name)
                    }
                    .where {
                        $0.personID.is(person.id)
                    },
                animation: .default
                )
        }
    }
    
    func addPersonButtonTapped() {
        person.name = name
        person.birthDate = birthDate
        person.notes = notes
        withErrorReporting {
            try database.write { db in
                try Person
                    .upsert { person }
                    .execute(db)
            }
        }
    }
}

struct PersonForm: View {
    @State private var model: PersonFormModel
    init(person: Person.Draft) {
        self._model = State(initialValue: PersonFormModel(person: person))
    }
    @Environment(\.dismiss) var dismiss

    var body: some View {
            Form {
                TextField("Name", text: $model.name)
                if model.birthDate != nil {
                    HStack {
                        DatePicker("Birthdate", selection: model.dateBinding, displayedComponents: .date)
                        Button {
                            model.birthDate = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                    }
                } else {
                    HStack {
                        Text("Birthdate")
                        Spacer()
                        Button("Add Birthdate") {
                            model.birthDate = Date.now
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                TextField("Notes", text: $model.notes, axis: .vertical)
                if model.person.id != nil {
                    Section  {
                        List {
                            ForEach(model.gifts) { gift in
                                HStack {
                                    Button {
                                        // purchaseButtonTapped
                                    } label: {
                                        Image(systemName: gift.isPurchased ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(gift.isPurchased ? .green : .secondary)
                                    }
                                    .buttonStyle(.plain)
                                    VStack(alignment: .leading) {
                                        Text(gift.name)
                                            .strikethrough(gift.isPurchased)
                                        if let price = gift.price {
                                            Text(price, format: .currency(code: "USD"))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Button {
                                        // EditButton Tapped
                                    } label: {
                                        Image(systemName: "pencil.circle")
                                            .foregroundStyle(.blue)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        // Delete Gift button Tapped
                                    }
                                }
                            }
                        }
                    } header:  {
                        HStack {
                            Text("Gifts")
                            Spacer()
                            Button {
                                // NewGiftButtonTapped
                            } label: {
                                Image(systemName: "plus.circle.fill")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction){
                    Button(role: .confirm) {
                        model.addPersonButtonTapped()
                        dismiss()
                    }
                }
                if model.person.id == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) {
                            dismiss()
                        }
                    }
                }
            }
    }
}

struct PersonFormPreview: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PersonForm(person: Person.Draft())
                .previewDisplayName("New Person")
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
    NavigationStack {
        PersonForm(person: Person.Draft(person))
    }
}
