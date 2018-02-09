//
//  NCTreeViewController.swift
//  Neocom
//
//  Created by Artem Shimanski on 07.07.17.
//  Copyright © 2017 Artem Shimanski. All rights reserved.
//

import UIKit
import CloudData

protocol NCSearchableViewController: UISearchResultsUpdating {
	var searchController: UISearchController? {get set}
}

extension NCSearchableViewController where Self: UITableViewController {
	func setupSearchController(searchResultsController: UIViewController) {
		searchController = UISearchController(searchResultsController: searchResultsController)
		searchController?.searchBar.searchBarStyle = UISearchBarStyle.default
		searchController?.searchResultsUpdater = self
		searchController?.searchBar.barStyle = UIBarStyle.black
		searchController?.searchBar.isTranslucent = false
		searchController?.hidesNavigationBarDuringPresentation = false
		tableView.backgroundView = UIView()
		tableView.tableHeaderView = searchController?.searchBar
		definesPresentationContext = true
	}
}

class NCTreeViewController: UITableViewController, TreeControllerDelegate, NCAPIController {
	
	var accountChangeObserver: NotificationObserver?
	var becomeActiveObserver: NotificationObserver?
	var refreshHandler: NCActionHandler<UIRefreshControl>?

	var treeController: TreeController?

	override func viewDidLoad() {
		super.viewDidLoad()
		tableView.backgroundColor = UIColor.background
		tableView.estimatedRowHeight = tableView.rowHeight
		tableView.rowHeight = UITableViewAutomaticDimension
		
		treeController = TreeController()
		treeController?.delegate = self
		treeController?.tableView = tableView
		
		tableView.delegate = treeController
		tableView.dataSource = treeController
		
		if let refreshControl = refreshControl {
			refreshHandler = NCActionHandler(refreshControl, for: .valueChanged) { [weak self] _ in
				self?.reload(cachePolicy: .reloadIgnoringLocalCacheData)
			}
		}
		
		becomeActiveObserver = NotificationCenter.default.addNotificationObserver(forName: .UIApplicationDidBecomeActive, object: nil, queue: nil) { [weak self] _ in
			self?.reloadIfNeeded()
		}
		
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		reloadIfNeeded()
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		if let context = NCCache.sharedCache?.viewContext, context.hasChanges {
			try? context.save()
		}
	}
	
	//MARK: - NCAPIController
	
	var accountChangeAction: AccountChangeAction = .none {
		didSet {
			switch accountChangeAction {
			case .none:
				accountChangeObserver = nil
			case .reload:
				accountChangeObserver = NotificationCenter.default.addNotificationObserver(forName: .NCCurrentAccountChanged, object: nil, queue: nil) { [weak self] _ in
					self?.reload()
				}
			case .update:
				accountChangeObserver = NotificationCenter.default.addNotificationObserver(forName: .NCCurrentAccountChanged, object: nil, queue: nil) { [weak self] _ in
					self?.updateContent {
					}
				}
			}
		}
	}
	
	var isLoading: Bool = false
	lazy var dataManager: NCDataManager = NCDataManager(account: NCAccount.current)
	
	func updateContent(completionHandler: @escaping () -> Void) {
		completionHandler()
	}
	
	func reload(cachePolicy: URLRequest.CachePolicy, completionHandler: @escaping ([NCCacheRecord]) -> Void ) {
		completionHandler([])
	}
	
	func didStartLoading() {
		tableView.backgroundView = nil
	}
	
	func didFailLoading(error: Error) {
		treeController?.content = nil
		tableView.backgroundView = NCTableViewBackgroundLabel(text: error.localizedDescription)
		if let refreshControl = refreshControl, refreshControl.isRefreshing {
			refreshControl.endRefreshing()
		}
	}
	
	func didFinishLoading() {
		if let refreshControl = refreshControl, refreshControl.isRefreshing {
			refreshControl.endRefreshing()
		}
	}

	var managedObjectsObserver: NCManagedObjectObserver?
	lazy var updateGate = NCGate()
	var updateWork: DispatchWorkItem?
	var expireDate: Date?
	
	//MARK: - TreeControllerDelegate
	
	func treeController(_ treeController: TreeController, didSelectCellWithNode node: TreeNode) {
		if (!isEditing && !tableView.allowsMultipleSelection) || (isEditing && !tableView.allowsMultipleSelectionDuringEditing) {
			treeController.deselectCell(for: node, animated: true)
			if let route = (node as? TreeNodeRoutable)?.route {
				route.perform(source: self, sender: treeController.cell(for: node))
			}
		}
		else {
			if isEditing && (self as TreeControllerDelegate).treeController?(treeController, editActionsForNode: node) == nil {
				treeController.deselectCell(for: node, animated: true)
				if let route = (node as? TreeNodeRoutable)?.route {
					route.perform(source: self, sender: treeController.cell(for: node))
				}
			}
		}
	}
	
	func treeController(_ treeController: TreeController, didDeselectCellWithNode node: TreeNode) {
	}
	
	func treeController(_ treeController: TreeController, accessoryButtonTappedWithNode node: TreeNode) {
		if let route = (node as? TreeNodeRoutable)?.accessoryButtonRoute {
			route.perform(source: self, sender: treeController.cell(for: node))
		}
	}
	
}

enum AccountChangeAction {
	case none
	case reload
	case update
}

protocol NCAPIController: class {
	func updateContent(completionHandler: @escaping () -> Void)
	func reload(cachePolicy: URLRequest.CachePolicy, completionHandler: @escaping ([NCCacheRecord]) -> Void )
	
	func didStartLoading()
	func didFailLoading(error: Error)
	func didFinishLoading()
	

	var accountChangeAction: AccountChangeAction {get set}
	var isLoading: Bool {get set}
	var dataManager: NCDataManager {get set}
	
	var managedObjectsObserver: NCManagedObjectObserver? {get set}
	var updateGate: NCGate {get}
	
	var expireDate: Date? {get set}
	var updateWork: DispatchWorkItem? {get set}
}

enum NCAPIControllerError: LocalizedError {
	case authorizationRequired
	case noResult(String?)
	
	var errorDescription: String? {
		switch self {
		case .authorizationRequired:
			return NSLocalizedString("Please Sign In", comment: "")
		case let .noResult(message):
			return message ?? NSLocalizedString("No Result", comment: "")
		}
	}
}

extension NCAPIController where Self: UIViewController {
	
	func reloadIfNeeded() {
		if let expireDate = expireDate, expireDate < Date() {
			reload()
		}
	}

	func reload() {
		self.reload(cachePolicy: .useProtocolCachePolicy)
	}

	fileprivate func delayedUpdate() {
		let date = Date()
		expireDate = managedObjectsObserver?.objects.flatMap {($0 as? NCCacheRecord)?.expireDate as Date?}.filter {$0 > date}.min()
		let progress = NCProgressHandler(viewController: self, totalUnitCount: 1)
		updateGate.perform {
			let group = DispatchGroup()
			group.enter()
			DispatchQueue.main.async {
				progress.progress.perform {
					self.updateContent {
						progress.finish()
						group.leave()
					}
				}
			}
			group.wait()
		}
		
	}
	
	func reload(cachePolicy: URLRequest.CachePolicy) {
		guard !isLoading else {return}

		didStartLoading()

		let account = NCAccount.current
		guard accountChangeAction != .reload || account != nil else {
			didFailLoading(error: NCAPIControllerError.authorizationRequired)
			return
		}
		
		isLoading = true
		
		dataManager = NCDataManager(account: account, cachePolicy: cachePolicy)
		managedObjectsObserver = nil
		
		
		let progress = NCProgressHandler(viewController: self, totalUnitCount: 2)
		progress.progress.perform {
			self.reload(cachePolicy: cachePolicy) { [weak self] records in
				guard let strongSelf = self else {
					progress.finish()
					return
				}
				
				let date = Date()
				strongSelf.expireDate = records.flatMap {$0.expireDate as Date?}.filter {$0 > date}.min()
				
				progress.progress.perform {
					strongSelf.updateContent {
						progress.finish()
						strongSelf.isLoading = false
						strongSelf.didFinishLoading()
					}
				}
				strongSelf.managedObjectsObserver = NCManagedObjectObserver(managedObjects: records) { [weak self] (_,_) in
					guard let strongSelf = self else {return}
					strongSelf.updateWork?.cancel()
					strongSelf.updateWork = DispatchWorkItem {
						self?.delayedUpdate()
						self?.updateWork = nil
					}
					DispatchQueue.main.async(execute: strongSelf.updateWork!)
				}
			}
		}
	}
}

extension NCAPIController where Self: NCTreeViewController {
	
	func reloadIfNeeded() {
		if treeController?.content == nil || (expireDate ?? Date.distantFuture) < Date() {
			reload()
		}
	}
}
