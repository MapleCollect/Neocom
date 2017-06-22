//
//  NCWHViewController.swift
//  Neocom
//
//  Created by Artem Shimanski on 22.06.17.
//  Copyright © 2017 Artem Shimanski. All rights reserved.
//

import UIKit
import CoreData

class NCWHGroupRow: FetchedResultsObjectNode<NCDBWhType> {
	
	required init(object: NCDBWhType) {
		super.init(object: object)
		cellIdentifier =  object.maxStableMass > 0 ? Prototype.NCDefaultTableViewCell.default.reuseIdentifier : Prototype.NCDefaultTableViewCell.compact.reuseIdentifier
	}
	
	lazy var subtitle: String = {
		let formatter = NCRangeFormatter(unit: .kilogram, style: .full)
		return formatter.string(for: self.object.maxJumpMass, maximum: self.object.maxStableMass)
	}()
	
	override func configure(cell: UITableViewCell) {
		guard let cell = cell as? NCDefaultTableViewCell else {return}
		cell.titleLabel?.text = object.type?.typeName
		cell.iconView?.image = object.type?.icon?.image?.image ?? NCDBEveIcon.defaultType.image?.image
		cell.accessoryType = .disclosureIndicator
		if object.maxStableMass > 0 {
			cell.subtitleLabel?.text = subtitle
		}

	}
}

class NCWHViewController: UITableViewController, UISearchResultsUpdating, TreeControllerDelegate {
	@IBOutlet var treeController: TreeController!
	var isSearchResultsController = false
	
	override func viewDidLoad() {
		super.viewDidLoad()
		tableView.estimatedRowHeight = tableView.rowHeight
		tableView.rowHeight = UITableViewAutomaticDimension
		
		tableView.register([Prototype.NCHeaderTableViewCell.default,
		                    Prototype.NCDefaultTableViewCell.default,
		                    Prototype.NCDefaultTableViewCell.compact
		                    ])
		treeController.delegate = self
		
		if !isSearchResultsController {
			setupSearchController()
		}
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		if treeController.content == nil {
			reloadData()
		}
	}
	
	override func didReceiveMemoryWarning() {
		if !isViewLoaded || view.window == nil {
			treeController.content = nil
		}
	}
	
	//MARK: - TreeControllerDelegate
	
	func treeController(_ treeController: TreeController, didSelectCellWithNode node: TreeNode) {
		guard let row = node as? NCWHGroupRow else {return}
		guard let type = row.object.type else {return}
		Router.Database.TypeInfo(type).perform(source: self, view: treeController.cell(for: node))
	}
	
	
	//MARK: UISearchResultsUpdating
	
	func updateSearchResults(for searchController: UISearchController) {
		let predicate: NSPredicate
		guard let controller = searchController.searchResultsController as? NCWHViewController else {return}
		if let text = searchController.searchBar.text, text.characters.count > 0 {
			predicate = NSPredicate(format: "type.typeName CONTAINS[C] %@", text)
		}
		else {
			predicate = NSPredicate(value: false)
		}
		controller.predicate = predicate
		controller.reloadData()
	}
	
	//MARK: Private
	
	private var searchController: UISearchController?
	private var predicate: NSPredicate?
	
	private func reloadData() {
		let request = NSFetchRequest<NCDBWhType>(entityName: "WhType")
		request.sortDescriptors = [NSSortDescriptor(key: "targetSystemClass", ascending: true), NSSortDescriptor(key: "type.typeName", ascending: true)]
		request.predicate = predicate
		let results = NSFetchedResultsController(fetchRequest: request, managedObjectContext: NCDatabase.sharedDatabase!.viewContext, sectionNameKeyPath: "targetSystemClassDisplayName", cacheName: nil)
		
		try? results.performFetch()
		
		treeController.content = FetchedResultsNode(resultsController: results, sectionNode: NCDefaultFetchedResultsSectionNode<NCDBWhType>.self, objectNode: NCWHGroupRow.self)
	}
	
	private func setupSearchController() {
		searchController = UISearchController(searchResultsController: self.storyboard?.instantiateViewController(withIdentifier: "NCWHViewController"))
		(searchController?.searchResultsController as! NCWHViewController).isSearchResultsController = true
		searchController?.searchBar.searchBarStyle = UISearchBarStyle.default
		searchController?.searchResultsUpdater = self
		searchController?.searchBar.barStyle = UIBarStyle.black
		searchController?.hidesNavigationBarDuringPresentation = false
		tableView.backgroundView = UIView()
		tableView.tableHeaderView = searchController?.searchBar
		definesPresentationContext = true
		
	}
}
