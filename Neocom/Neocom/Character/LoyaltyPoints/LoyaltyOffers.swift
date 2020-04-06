//
//  LoyaltyOffers.swift
//  Neocom
//
//  Created by Artem Shimanski on 3/27/20.
//  Copyright © 2020 Artem Shimanski. All rights reserved.
//

import SwiftUI
import EVEAPI
import Alamofire

struct LoyaltyOffers: View {
    var corporationID: Int
    @Environment(\.managedObjectContext) private var managedObjectContext
    @Environment(\.esi) private var esi
    @Environment(\.account) private var account
    @ObservedObject private var loyaltyOffers = Lazy<LoyaltyOffersLoader>()

    var body: some View {
        
        let result = account.map { account in
            self.loyaltyOffers.get(initial: LoyaltyOffersLoader(esi: esi, corporationID: Int64(corporationID), managedObjectContext: managedObjectContext))
        }
        let loyaltyOffers = result?.result?.value
        let error = result?.result?.error
        return Group {
            if loyaltyOffers != nil {
                LoyaltyOffersCategories(categories: loyaltyOffers!)
            }
            else {
                Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all)
            }
        }
        .overlay(result == nil ? Text(RuntimeError.noAccount).padding() : nil)
        .overlay(error.map{Text($0)})
        .overlay(loyaltyOffers?.isEmpty == true ? Text(RuntimeError.noResult).padding() : nil)
    }
}

struct LoyaltyOffersCategories: View {
    var categories: [LoyaltyOffersLoader.Category]
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    var body: some View {
        List(categories) { category in
            NavigationLink(destination: LoyaltyOffersGroups(category: category)) {
                CategoryCell(category: self.managedObjectContext.object(with: category.id) as! SDEInvCategory)
            }
        }.listStyle(GroupedListStyle())
    }
}

struct LoyaltyOffersGroups: View {
    var category: LoyaltyOffersLoader.Category
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    var body: some View {
        List(category.groups) { group in
            NavigationLink(destination: LoyaltyOffersTypes(group: group)) {
                GroupCell(group: self.managedObjectContext.object(with: group.id) as! SDEInvGroup)
            }
        }.listStyle(GroupedListStyle())
            .navigationBarTitle(category.name)
    }
}

struct LoyaltyOffersTypes: View {
    var group: LoyaltyOffersLoader.Category.Group
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    var body: some View {
        List(group.types) { type in
            NavigationLink(destination: TypeInfo(type: self.managedObjectContext.object(with: type.id) as! SDEInvType)) {
                VStack(alignment: .leading) {
                    TypeCell(type: self.managedObjectContext.object(with: type.id) as! SDEInvType)
                    VStack(alignment: .leading, spacing: 2) {
                        if type.offer.quantity > 1 {
                            HStack {
                                Text("Quantity:")
                                Text(UnitFormatter.localizedString(from: type.offer.quantity, unit: .none, style: .long))
                            }
                        }
                        HStack {
                            Text("Cost:")
                            Text(UnitFormatter.localizedString(from: type.offer.lpCost, unit: .loyaltyPoints, style: .long))
                            if type.offer.iskCost > 0 {
                                Text(UnitFormatter.localizedString(from: type.offer.iskCost, unit: .isk, style: .long))
                            }
                        }
                        ForEach(type.offer.requiredItems, id: \.typeID) {
                            LoyaltyOfferRequirement(requirement: $0)
                        }
                    }.modifier(SecondaryLabelModifier())
                }
            }.buttonStyle(PlainButtonStyle())
        }.listStyle(GroupedListStyle())
            .navigationBarTitle(group.name)
    }
}

struct LoyaltyOffers_Previews: PreviewProvider {
    static var previews: some View {
        let account = AppDelegate.sharedDelegate.testingAccount
        let esi = account.map{ESI(token: $0.oAuth2Token!)} ?? ESI()

        return NavigationView {
            LoyaltyOffers(corporationID: 1000049)
        }.environment(\.managedObjectContext, AppDelegate.sharedDelegate.persistentContainer.viewContext)
            .environment(\.account, account)
            .environment(\.esi, esi)
    }
}
