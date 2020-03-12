//
//  DronesCountResource.swift
//  Neocom
//
//  Created by Artem Shimanski on 3/12/20.
//  Copyright © 2020 Artem Shimanski. All rights reserved.
//

import SwiftUI
import Dgmpp

struct DronesCountResource: View {
    @EnvironmentObject private var ship: DGMShip
    
    var body: some View {
        ShipResource(used: ship.usedDroneSquadron(.none), total: ship.totalDroneSquadron(.none), unit: .none, image: Image("drone"), style: .counter)
    }
}

struct DronesCountResource_Previews: PreviewProvider {
    static var previews: some View {
        DronesCountResource().environmentObject(DGMGang.testGang().pilots[0].ship!)
    }
}
