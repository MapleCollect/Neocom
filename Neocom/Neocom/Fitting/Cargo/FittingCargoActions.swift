//
//  FittingCargoActions.swift
//  Neocom
//
//  Created by Artem Shimanski on 4/17/20.
//  Copyright © 2020 Artem Shimanski. All rights reserved.
//

import SwiftUI
import Dgmpp



struct FittingCargoActions: View {
    @ObservedObject var ship: DGMShip
    @ObservedObject var cargo: DGMCargo
    var completion: () -> Void
    @Environment(\.managedObjectContext) private var managedObjectContext
    @State private var selectedType: SDEInvType?
    @Environment(\.self) private var environment
    @EnvironmentObject private var sharedState: SharedState

    @State private var qty = 0
    var body: some View {
        let type = cargo.type(from: managedObjectContext)
        let perItem = Double(cargo.volume) / Double(cargo.quantity)
        return List {
            Button(action: {self.selectedType = type}) {
                HStack {
                    type.map{Icon($0.image).cornerRadius(4)}
                    type?.typeName.map{Text($0)} ?? Text("Unknown")
                }
            }.buttonStyle(PlainButtonStyle())
            HStack {
                Text("Volume")
                Spacer()
                CargoVolume(ship: ship, cargo: cargo).foregroundColor(.secondary)
            }
            HStack {
                Text("Per Item")
                Spacer()
                Text(UnitFormatter.localizedString(from: perItem, unit: .cubicMeter, style: .long)).foregroundColor(.secondary)
            }
            HStack {
                Text("Quantity")
                Spacer()
                TextField("Quantity", value: $cargo.quantity, formatter: NumberFormatter())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .frame(width: 100)
                    .multilineTextAlignment(.center)
                Stepper("Quantity", value: $cargo.quantity).labelsHidden()
                Button("Max") {
                    let free = self.ship.cargoCapacity - self.ship.usedCargoCapacity + self.cargo.volume
                    let qty = (free / perItem).rounded(.down)
                    self.cargo.quantity = Int(max(qty, 1))
                }.buttonStyle(BorderlessButtonStyle())
            }
        }
        .listStyle(GroupedListStyle())
        .navigationBarTitle("Actions")
        .navigationBarItems(leading: BarButtonItems.close(completion), trailing: BarButtonItems.trash {
            self.completion()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.ship.remove(self.cargo)
            }
        })

        .sheet(item: $selectedType) { type in
            NavigationView {
                TypeInfo(type: type).navigationBarItems(leading: BarButtonItems.close {self.selectedType = nil})
            }
            .modifier(ServicesViewModifier(environment: self.environment, sharedState: self.sharedState))
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}

struct FittingCargoActions_Previews: PreviewProvider {
        static var previews: some View {
            let ship = DGMShip.testDominix()
            let cargo = ship.cargo[0]
            cargo.quantity = 10
            return FittingCargoActions(ship: ship, cargo: cargo) {}
                .environment(\.managedObjectContext, AppDelegate.sharedDelegate.persistentContainer.viewContext)
                .environment(\.backgroundManagedObjectContext, AppDelegate.sharedDelegate.persistentContainer.viewContext)
                .environmentObject(SharedState.testState())
            

            
        }
    }
