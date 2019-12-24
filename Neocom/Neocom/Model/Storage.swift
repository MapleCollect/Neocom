//
//  Storage.swift
//  Neocom
//
//  Created by Artem Shimanski on 19.11.2019.
//  Copyright © 2019 Artem Shimanski. All rights reserved.
//

import Foundation
import CoreData
import EVEAPI
import Expressible
import SwiftUI

class Storage: NSPersistentCloudKitContainer {
    init() {
        let storageModel = NSManagedObjectModel(contentsOf: Bundle.main.url(forResource: "Storage", withExtension: "momd")!)!
        let sdeModel = NSManagedObjectModel(contentsOf: Bundle.main.url(forResource: "SDE", withExtension: "momd")!)!
        let model = NSManagedObjectModel(byMerging: [storageModel, sdeModel])!
        super.init(name: "Neocom", managedObjectModel: model)
        let sde = NSPersistentStoreDescription(url: Bundle.main.url(forResource: "SDE", withExtension: "sqlite")!)
        sde.configuration = "SDE"
        sde.isReadOnly = true
        sde.shouldMigrateStoreAutomatically = false
        
        let storage = NSPersistentStoreDescription(url: URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!).appendingPathComponent("stora.sqlite"))
        storage.configuration = "Storage"
//        storage.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.shimanski.neocom")
        persistentStoreDescriptions = [sde, storage]
    }
}

extension NSManagedObjectContext {
	func newBackgroundContext() -> NSManagedObjectContext {
		let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
		context.parent = self
		return context
	}
}

extension SDEInvCategory {
	var image: Image {
		let image = icon?.image?.image ??
			(try? managedObjectContext?.fetch(SDEEveIcon.named(.defaultCategory)).first?.image?.image) ??
			UIImage()
		return Image(uiImage: image)
	}
}

extension SDEInvGroup {
    var image: Image {
        let image = icon?.image?.image ??
            (try? managedObjectContext?.fetch(SDEEveIcon.named(.defaultGroup)).first?.image?.image) ??
            UIImage()
        return Image(uiImage: image)
    }
}

extension SDEInvMarketGroup {
    var image: Image {
        let image = icon?.image?.image ??
            (try? managedObjectContext?.fetch(SDEEveIcon.named(.defaultGroup)).first?.image?.image) ??
            UIImage()
        return Image(uiImage: image)
    }
}

extension SDEInvType {
    var image: Image {
        let image = icon?.image?.image ??
            (try? managedObjectContext?.fetch(SDEEveIcon.named(.defaultType)).first?.image?.image) ??
            UIImage()
        return Image(uiImage: image)
    }
    
    class func dominix() -> NSFetchRequest<SDEInvType> {
        let request = NSFetchRequest<SDEInvType>(entityName: "InvType")
        request.predicate = (\SDEInvType.typeID == 645).predicate(for: .`self`)
        return request
    }
}

extension SDEEveIcon {
	class func named(_ name: Name) -> NSFetchRequest<SDEEveIcon> {
		let request = NSFetchRequest<SDEEveIcon>(entityName: "EveIcon")
		request.predicate = (\SDEEveIcon.iconFile == name.name).predicate(for: .`self`)
		request.fetchLimit = 1
		return request
	}
	
	enum Name {
		case defaultCategory
		case defaultGroup
		case defaultType
		case mastery(Int?)
		
		var name: String {
			switch self {
			case .defaultCategory, .defaultGroup:
				return "38_16_174"
			case .defaultType:
				return "7_64_15"
			case let .mastery(level):
				guard let level = level, (0...4).contains(level) else {return "79_64_1"}
				return "79_64_\(level + 2)"
			}
		}
	}
}

public class LoadoutDescription: NSObject {
	
}

public class ImplantSetDescription: NSObject {
	
}

public class FleetDescription: NSObject {
	
}

extension Account {
    
    convenience init(token: OAuth2Token, context: NSManagedObjectContext) {
        self.init(context: context)
        oAuth2Token = token
    }
    
    var oAuth2Token: OAuth2Token? {
        get {
            let scopes = (self.scopes as? Set<Scope>)?.compactMap {
                return $0.name
                } ?? []
            guard let accessToken = accessToken,
                let refreshToken = refreshToken,
                let tokenType = tokenType,
                let characterName = characterName,
                let realm = realm else {return nil}
            
            let token = OAuth2Token(accessToken: accessToken, refreshToken: refreshToken, tokenType: tokenType, expiresOn: expiresOn as Date? ?? Date.distantPast, characterID: characterID, characterName: characterName, realm: realm, scopes: scopes)
            return token
        }
        set {
            guard let managedObjectContext = managedObjectContext else {return}
            
            if let token = newValue {
                if accessToken != token.accessToken {accessToken = token.accessToken}
                if refreshToken != token.refreshToken {refreshToken = token.refreshToken}
                if tokenType != token.tokenType {tokenType = token.tokenType}
                if characterID != token.characterID {characterID = token.characterID}
                if characterName != token.characterName {characterName = token.characterName}
                if realm != token.realm {realm = token.realm}
                if expiresOn != token.expiresOn {expiresOn = token.expiresOn}
                let newScopes = Set<String>(token.scopes)
                
                let toInsert: Set<String>
                if var scopes = self.scopes as? Set<Scope> {
                    let toDelete = scopes.filter {
                        guard let name = $0.name else {return true}
                        return !newScopes.contains(name)
                    }
                    for scope in toDelete {
                        managedObjectContext.delete(scope)
                        scopes.remove(scope)
                    }
                    
                    toInsert = newScopes.symmetricDifference(scopes.compactMap {return $0.name})
                }
                else {
                    toInsert = newScopes
                }
                
                for name in toInsert {
                    let scope = Scope(context: managedObjectContext)
                    scope.name = name
                    scope.account = self
                }
            }
        }
    }
//
//    var activeSkillPlan: SkillPlan? {
//        if let skillPlan = (try? managedObjectContext?.from(SkillPlan.self).filter(\SkillPlan.account == self && \SkillPlan.active == true).first()) ?? nil {
//            return skillPlan
//        }
//        else if let skillPlan = skillPlans?.anyObject() as? SkillPlan {
//            skillPlan.active = true
//            return skillPlan
//        }
//        else if let managedObjectContext = managedObjectContext {
//            let skillPlan = SkillPlan(context: managedObjectContext)
//            skillPlan.active = true
//            skillPlan.account = self
//            skillPlan.name = NSLocalizedString("Default", comment: "")
//            return skillPlan
//        }
//        else {
//            return nil
//        }
//    }
}


enum DamageType {
    case em
    case thermal
    case kinetic
    case explosive
}

struct Damage {
    var em: Double = 0
    var thermal: Double = 0
    var kinetic: Double = 0
    var explosive: Double = 0
}