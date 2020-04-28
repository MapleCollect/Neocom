//
//  FittingItem.swift
//  Neocom
//
//  Created by Artem Shimanski on 4/11/20.
//  Copyright © 2020 Artem Shimanski. All rights reserved.
//

import SwiftUI

struct FittingItem: View {
    @EnvironmentObject private var restorableState: RestorableState
    
    var body: some View {
        NavigationLink(destination: Loadouts(), tag: RestorableState.Navigation(rawValue: "fitting"), selection: $restorableState.main) {
//        NavigationLink(destination: Loadouts()) {
            Icon(Image("fitting"))
            Text("Fitting")
        }
    }
}

struct FittingItem_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            List {
                FittingItem()
            }.listStyle(GroupedListStyle())
        }
    }
}
