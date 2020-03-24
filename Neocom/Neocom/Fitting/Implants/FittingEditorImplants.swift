//
//  FittingEditorImplants.swift
//  Neocom
//
//  Created by Artem Shimanski on 3/5/20.
//  Copyright © 2020 Artem Shimanski. All rights reserved.
//

import SwiftUI
import Dgmpp
import Expressible

struct FittingEditorImplants: View {
    @EnvironmentObject private var ship: DGMShip
    @Environment(\.managedObjectContext) var managedObjectContext
    @State private var selectedCategory: SDEDgmppItemCategory?
    @Environment(\.self) private var environment
    private let typePickerState = Cache<SDEDgmppItemCategory, TypePickerState>()
    
    private enum Row: Identifiable {
        case implant(DGMImplant, slot: Int)
        case booster(DGMBooster, slot: Int)
        case slot(Int)
        
        var id: AnyHashable {
            slot
        }
        
        var implant: DGMImplant? {
            switch self {
            case let .implant(implant, _):
                return implant
            default:
                return nil
            }
        }

        var booster: DGMBooster? {
            switch self {
            case let .booster(booster, _):
                return booster
            default:
                return nil
            }
        }
        
        var slot: Int {
            switch self {
            case let .implant(_, slot):
                return slot
            case let .booster(_, slot):
                return slot
            case let .slot(slot):
                return slot
            }
        }
    }
    
    private func typePicker(_ category: SDEDgmppItemCategory) -> some View {
        NavigationView {
            TypePicker(category: category) { (type) in
                do {
                    if category.category == SDEDgmppItemCategoryID.implant.rawValue {
                        let implant = try DGMImplant(typeID: DGMTypeID(type.typeID))
                        try (self.ship.parent as? DGMCharacter)?.add(implant)
                    }
                    else {
                        let booster = try DGMBooster(typeID: DGMTypeID(type.typeID))
                        try (self.ship.parent as? DGMCharacter)?.add(booster)
                    }
                }
                catch {
                }
                self.selectedCategory = nil
            }.navigationBarItems(leading: BarButtonItems.close {
                self.selectedCategory = nil
            })
        }.modifier(ServicesViewModifier(environment: self.environment))
            .environmentObject(typePickerState[category, default: TypePickerState()])
    }

    var body: some View {
        let pilot = ship.parent as? DGMCharacter
        let implants = Dictionary(pilot?.implants.map{($0.slot, $0)} ?? []) {a, _ in a}
        
        let implantRows: [Row] = stride(from: 1, through: 10, by: 1).map { i in
            implants[i].map{.implant($0, slot: i)} ?? .slot(i)
        }
        
        let boosterSlots = (try? managedObjectContext.from(SDEDgmppItemCategory.self).filter(/\SDEDgmppItemCategory.category == SDEDgmppItemCategoryID.booster.rawValue).fetch().map{Int($0.subcategory)})?.sorted() ?? [1,2,3,4]

        let boosters = Dictionary(pilot?.boosters.map{($0.slot, $0)} ?? []) {a, _ in a}
        let boosterRows: [Row] = boosterSlots.map { i in
            boosters[i].map{.booster($0, slot: i)} ?? .slot(i)
        }
        
        return List {
            Section(header: Text("IMPLANTS")) {
                ForEach(implantRows) { row in
                    if row.implant != nil {
                        FittingImplantCell(implant: row.implant!)
                    }
                    else {
                        Button (action: {self.selectedCategory = try? self.managedObjectContext.fetch(SDEDgmppItemCategory.category(categoryID: .implant, subcategory: row.slot, race: nil)).first}) {
                            FittingImplantSlot(slot: row.slot)
                        }.buttonStyle(PlainButtonStyle())
                    }
                }
            }
            Section(header: Text("BOOSTERS")) {
                ForEach(boosterRows) { row in
                    if row.booster != nil {
                        FittingBoosterCell(booster: row.booster!)
                    }
                    else {
                        Button (action: {self.selectedCategory = try? self.managedObjectContext.fetch(SDEDgmppItemCategory.category(categoryID: .booster, subcategory: row.slot, race: nil)).first}) {
                            FittingBoosterSlot(slot: row.slot)
                        }.buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }.listStyle(GroupedListStyle())
            .sheet(item: $selectedCategory) { category in
                self.typePicker(category)
        }

    }
}

struct FittingEditorImplants_Previews: PreviewProvider {
    static var previews: some View {
        let gang = DGMGang.testGang()
        
        return FittingEditorImplants()
            .environmentObject(gang)
            .environmentObject(gang.pilots[0].ship!)
            .environment(\.managedObjectContext, AppDelegate.sharedDelegate.persistentContainer.viewContext)
            .environment(\.backgroundManagedObjectContext, AppDelegate.sharedDelegate.persistentContainer.viewContext)
    }
}
