//
//  TypeGroups.swift
//  Neocom
//
//  Created by Artem Shimanski on 26.11.2019.
//  Copyright © 2019 Artem Shimanski. All rights reserved.
//

import SwiftUI
import CoreData
import Expressible

struct TypeGroups: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    var category: SDEInvCategory
    
    private func groups() -> FetchedResultsController<SDEInvGroup> {
        let controller = managedObjectContext.from(SDEInvGroup.self)
            .filter(\SDEInvGroup.category == category)
            .sort(by: \SDEInvGroup.published, ascending: false)
            .sort(by: \SDEInvGroup.groupName, ascending: true)
            .fetchedResultsController(sectionName: \SDEInvGroup.published)
        return FetchedResultsController(controller)
    }
    
    var body: some View {
        FetchedResultsView(groups()) { groups in
            List {
                TypeGroupsContent(groups: groups)
            }.listStyle(GroupedListStyle()).navigationBarTitle(self.category.categoryName ?? "Unknown")
        }
    }
}

struct TypeGroupsContent: View {
    var groups: FetchedResultsController<SDEInvGroup>
    
    var body: some View {
        ForEach(groups.sections, id: \.name) { section in
            Section(header: section.name == "0" ? Text("UNPUBLISHED") : Text("PUBLISHED")) {
                ForEach(section.objects, id: \.objectID) { group in
                    NavigationLink(destination: Types(predicate: \SDEInvType.group == group).navigationBarTitle(group.groupName ?? "Unknown")) {
                        HStack {
                            Icon(group.image)
                            Text(group.groupName ?? "")
                        }
                    }
                }
            }
        }
    }
}

struct TypeGroups_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TypeGroups(category: try! AppDelegate.sharedDelegate.storageContainer.viewContext.from(SDEInvCategory.self).first()!)
        }.environment(\.managedObjectContext, AppDelegate.sharedDelegate.storageContainer.viewContext)
    }
}
