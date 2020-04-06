//
//  PlanetariesItem.swift
//  Neocom
//
//  Created by Artem Shimanski on 4/1/20.
//  Copyright © 2020 Artem Shimanski. All rights reserved.
//

import SwiftUI
import EVEAPI

struct PlanetariesItem: View {
    @Environment(\.account) private var account
    let require: [ESI.Scope] = [.esiPlanetsManagePlanetsV1]
    
    var body: some View {
        Group {
            if account?.verifyCredentials(require) == true {
                NavigationLink(destination: Planetaries()) {
                    Icon(Image("planets"))
                    Text("Planetaries")
                }
            }
        }
    }
}

struct PlanetariesItem_Previews: PreviewProvider {
    static var previews: some View {
        let account = AppDelegate.sharedDelegate.testingAccount
        let esi = account.map{ESI(token: $0.oAuth2Token!)} ?? ESI()
        
        return NavigationView {
            List {
                PlanetariesItem()
            }.listStyle(GroupedListStyle())
        }
        .environment(\.account, account)
        .environment(\.esi, esi)
        .environment(\.managedObjectContext, AppDelegate.sharedDelegate.persistentContainer.viewContext)
    }
}
