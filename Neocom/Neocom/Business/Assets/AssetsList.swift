//
//  AssetsList.swift
//  Neocom
//
//  Created by Artem Shimanski on 2/7/20.
//  Copyright © 2020 Artem Shimanski. All rights reserved.
//

import SwiftUI
import EVEAPI
import Expressible
import Combine
import Dgmpp

struct AssetsList: View {
    var assets: [AssetsData.Asset]
    var title: String
    var ship: AssetsData.Asset?
    
    @State private var selectedProject: FittingProject?
    @State private var projectLoading: AnyPublisher<Result<FittingProject, Error>, Never>?
    @Environment(\.managedObjectContext) private var managedObjectContext
    @Environment(\.account) private var account
    
    init(_ location: AssetsData.LocationGroup) {
        assets = location.assets
        title = location.location.solarSystem?.solarSystemName ?? location.location.name
    }

    init(_ asset: AssetsData.Asset) {
        assets = asset.nested
        title = asset.assetName ?? asset.typeName
        if asset.categoryID == SDECategoryID.ship.rawValue {
            ship = asset
        }
    }

    private var fittingButton: some View {
        Button("Fitting") {
            self.projectLoading = DGMSkillLevels.load(self.account, managedObjectContext: self.managedObjectContext).tryMap { try FittingProject(asset: self.ship!, skillLevels: $0) }
                .asResult()
                .receive(on: RunLoop.main)
                .eraseToAnyPublisher()
        }
    }

    var body: some View {
        Group {
            if ship != nil {
                List {
                    AssetsShipContent(ship: ship!)
                }.listStyle(GroupedListStyle())
                    .overlay(self.projectLoading != nil ? ActivityView() : nil)
                    .overlay(selectedProject.map{NavigationLink(destination: FittingEditor(project: $0), tag: $0, selection: $selectedProject, label: {EmptyView()})})
                    .onReceive(projectLoading ?? Empty().eraseToAnyPublisher()) { result in
                        self.projectLoading = nil
                        self.selectedProject = result.value
                }
                .navigationBarItems(trailing: fittingButton)
                
            }
            else {
                List {
                    AssetsListContent(assets: assets)
                }.listStyle(GroupedListStyle())
            }
        }
        .navigationBarTitle(title)
    }
}

struct AssetsListContent: View {
    @Environment(\.managedObjectContext) private var managedObjectContext
    var assets: [AssetsData.Asset]
    
    var body: some View {
        return ForEach(assets, id: \.underlyingAsset.itemID) { asset in
            Group {
                AssetCell(asset: asset)
            }
        }
    }
}

struct AssetsShipContent: View {
    @Environment(\.managedObjectContext) private var managedObjectContext
    var ship: AssetsData.Asset
    
    var body: some View {
        let map = Dictionary(grouping: ship.nested, by: {ItemFlag(flag: $0.underlyingAsset.locationFlag) ?? .cargo})
        let assets = map.sorted {$0.key.rawValue < $1.key.rawValue}
        return ForEach(assets, id: \.key) { i in
            Section(header: i.key.tableSectionHeader) {
                ForEach(i.value, id: \.underlyingAsset.itemID) { asset in
                    AssetCell(asset: asset)
                }
            }
        }
    }
}

struct AssetsList_Previews: PreviewProvider {
    
    static var previews: some View {
        let data = NSDataAsset(name: "dominixAsset")!.data
        let asset = try! JSONDecoder().decode(AssetsData.Asset.self, from: data)
        return AssetsList(asset)
            .environment(\.managedObjectContext, AppDelegate.sharedDelegate.persistentContainer.viewContext)
    }
}
