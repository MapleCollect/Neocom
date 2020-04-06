//
//  LoyaltyPointsLoader.swift
//  Neocom
//
//  Created by Artem Shimanski on 3/27/20.
//  Copyright © 2020 Artem Shimanski. All rights reserved.
//

import Foundation
import Combine
import EVEAPI
import CoreData
import Alamofire

class LoyaltyPointsLoader: ObservableObject {
    @Published var result: Result<(loyaltyPoints: ESI.LoyaltyPoints, contacts: [Int64: Contact]), AFError>?
    private var subscription: AnyCancellable?
    
    init(esi: ESI, characterID: Int64, managedObjectContext: NSManagedObjectContext) {
        subscription = esi.characters.characterID(Int(characterID)).loyalty().points().get().map{$0.value}.flatMap { loyaltyPoints in
            Contact.contacts(with: Set(loyaltyPoints.map{Int64($0.corporationID)}),
                             esi: esi,
                             characterID: characterID,
                             options: [.universe],
                             managedObjectContext: managedObjectContext)
                .map { (loyaltyPoints, $0) }
                .setFailureType(to: AFError.self)
        }
        .asResult()
        .receive(on: RunLoop.main)
        .sink { [weak self] result in
            self?.result = result
        }

    }
}

