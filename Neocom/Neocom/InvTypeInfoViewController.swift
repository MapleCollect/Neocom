//
//  InvTypeInfoViewController.swift
//  Neocom
//
//  Created by Artem Shimanski on 21.09.2018.
//  Copyright © 2018 Artem Shimanski. All rights reserved.
//

import Foundation
import CoreData

class InvTypeInfoViewController: TreeViewController<InvTypeInfoPresenter, InvTypeInfoViewController.Input>, TreeView {
	enum Input {
		case type(SDEInvType)
		case typeID(Int)
		case objectID(NSManagedObjectID)
	}
	
}

