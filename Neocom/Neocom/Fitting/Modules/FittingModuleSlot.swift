//
//  FittingModuleSlot.swift
//  Neocom
//
//  Created by Artem Shimanski on 2/24/20.
//  Copyright © 2020 Artem Shimanski. All rights reserved.
//

import SwiftUI
import Dgmpp

struct FittingModuleSlot: View {
    var slot: DGMModule.Slot
    var socket: Int
    var body: some View {
        HStack {
            slot.image.map{Icon($0)}
            Text("Add Module")
        }
    }
}

struct FittingModuleSlot_Previews: PreviewProvider {
    static var previews: some View {
        List {
            FittingModuleSlot(slot: .hi, socket: 0)
        }.listStyle(GroupedListStyle())
    }
}
