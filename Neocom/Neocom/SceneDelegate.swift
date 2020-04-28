//
//  SceneDelegate.swift
//  Neocom
//
//  Created by Artem Shimanski on 19.11.2019.
//  Copyright © 2019 Artem Shimanski. All rights reserved.
//

import UIKit
import SwiftUI
import CoreData
import Expressible
import EVEAPI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

	var window: UIWindow?

    private var currentActivities: [AnyUserActivityProvider] = []
    private var state: RestorableState?

	func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
		// Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
		// If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
		// This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).

		// Create the SwiftUI view that provides the window contents.
//        let contentView = ContentView()
		// Use a UIHostingController as window root view controller.
        
        let context = AppDelegate.sharedDelegate.persistentContainer.viewContext
        let rootModifier = ServicesViewModifier(managedObjectContext: AppDelegate.sharedDelegate.persistentContainer.viewContext,
                                                backgroundManagedObjectContext: AppDelegate.sharedDelegate.persistentContainer.newBackgroundContext(),
                                                sharedState: SharedState(managedObjectContext: AppDelegate.sharedDelegate.persistentContainer.viewContext))
        
		if let windowScene = scene as? UIWindowScene {
		    let window = UIWindow(windowScene: windowScene)
            
            if let activity = session.stateRestorationActivity, activity.activityType == NSUserActivityType.restorableState {
                state = (try? activity.restorableState(from: context)) ?? RestorableState()
            }
            else {
                state = RestorableState()
            }
            
            if let activity = connectionOptions.userActivities.first(where: {$0.activityType == NSUserActivityType.fitting}),
                let project = try? activity.fitting(from: AppDelegate.sharedDelegate.persistentContainer.viewContext) {
                
                if UIApplication.shared.supportsMultipleScenes {
                    let contentView = NavigationView {
                        FittingEditor(project: project).environmentObject(FittingAutosaver(project: project))
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                    .modifier(rootModifier)
                    .environmentObject(self.state!)
                    .onPreferenceChange(AppendPreferenceKey<AnyUserActivityProvider, AnyUserActivityProvider>.self) { [weak self] activities in
                        self?.currentActivities = activities
                    }
                    window.rootViewController = UIHostingController(rootView: contentView)
                }
                else {
                    let contentView = Main(restoredFitting: project)
                        .modifier(rootModifier)
                        .environmentObject(self.state!)
                        .onPreferenceChange(AppendPreferenceKey<AnyUserActivityProvider, AnyUserActivityProvider>.self) { [weak self] activities in
                            self?.currentActivities = activities
                    }

                    window.rootViewController = UIHostingController(rootView: contentView)
                }
                
            }
            else {
                let contentView = Main()
                    .modifier(rootModifier)
                    .environmentObject(self.state!)
                    .onPreferenceChange(AppendPreferenceKey<AnyUserActivityProvider, AnyUserActivityProvider>.self) { [weak self] activities in
                        self?.currentActivities = activities
                }

                window.rootViewController = UIHostingController(rootView: contentView)
            }

		    self.window = window
		    window.makeKeyAndVisible()
		}
	}

	func sceneDidDisconnect(_ scene: UIScene) {
		// Called as the scene is being released by the system.
		// This occurs shortly after the scene enters the background, or when its session is discarded.
		// Release any resources associated with this scene that can be re-created the next time the scene connects.
		// The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
	}

	func sceneDidBecomeActive(_ scene: UIScene) {
		// Called when the scene has moved from an inactive state to an active state.
		// Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
	}
    
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        scene.userActivity
    }

	func sceneWillResignActive(_ scene: UIScene) {
        scene.userActivity = state.flatMap{try? NSUserActivity(state: $0)}
	}

	func sceneWillEnterForeground(_ scene: UIScene) {
		// Called as the scene transitions from the background to the foreground.
		// Use this method to undo the changes made on entering the background.
	}

	func sceneDidEnterBackground(_ scene: UIScene) {
        AppDelegate.sharedDelegate.saveContext()
		// Called as the scene transitions from the foreground to the background.
		// Use this method to save data, release shared resources, and store enough scene-specific state information
		// to restore the scene back to its current state.
	}
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            if OAuth2.handleOpenURL(context.url, clientID: Config.current.esi.clientID, secretKey: Config.current.esi.secretKey, completionHandler: { (result) in
                
                let context = AppDelegate.sharedDelegate.persistentContainer.viewContext
                switch result {
                case let .success(token):
                    let data = try? JSONEncoder().encode(token)
                    let s = String(data: data!, encoding: .utf8)
                    print(s)
                    if let account = try? context.from(Account.self).filter(/\Account.characterID == token.characterID).first() {
                        account.oAuth2Token = token
                    }
                    else {
                        let account = Account(context: context)
                        account.oAuth2Token = token
                        account.uuid = UUID().uuidString
                    }
                    if context.hasChanges {
                        try? context.save()
                    }
                    
                case let .failure(error):
                    //                let controller = self.window?.rootViewController?.topMostPresentedViewController
                    //                controller?.present(UIAlertController(error: error), animated: true, completion: nil)
                    break
                }
            }) {
                //            if let controller = self.window?.rootViewController?.topMostPresentedViewController as? SFSafariViewController {
                //                controller.dismiss(animated: true, completion: nil)
                //            }
            }
            
        }
        print(URLContexts)
    }
}

