//
//  NCDatabaseCertificateInfoViewController.swift
//  Neocom
//
//  Created by Artem Shimanski on 26.12.16.
//  Copyright © 2016 Artem Shimanski. All rights reserved.
//

import UIKit
import CoreData

class NCDatabaseCertSkillRow: NCTreeRow {
	//let title: String?
	let title: NSAttributedString?
	let image: UIImage?
	let object: Any?
	let tintColor: UIColor?
	let subtitle: String?
	
	init(skill: NCDBCertSkill, character: NCCharacter) {
		self.title = NSAttributedString(skillName: skill.type!.typeName!, level: Int(skill.skillLevel))
		
		let trainingTime: TimeInterval
		
		if let type = skill.type, let trainedSkill = character.skills[Int(type.typeID)], let trainedLevel = trainedSkill.level {
			if trainedLevel >= Int(skill.skillLevel) {
				self.image = UIImage(named: "skillRequirementMe")
				self.tintColor = UIColor.white
				trainingTime = 0
			}
			else {
				trainingTime = NCTrainingSkill(type: type, skill: trainedSkill, level: Int(skill.skillLevel))?.trainingTime(characterAttributes: character.attributes) ?? 0
				self.image = UIImage(named: "skillRequirementNotMe")
				self.tintColor = UIColor.lightText
			}
		}
		else {
			if let type = skill.type {
				trainingTime = NCTrainingSkill(type: type, level: Int(skill.skillLevel))?.trainingTime(characterAttributes: character.attributes) ?? 0
			}
			else {
				trainingTime = 0
			}
			//self.image = eveIcons["38_194"]?.image?.image
			self.image = UIImage(named: "skillRequirementNotInjected")
			self.tintColor = UIColor.lightText
		}
		self.object = skill.type?.objectID
		self.subtitle = trainingTime > 0 ? NCTimeIntervalFormatter.localizedString(from: trainingTime, precision: .seconds) : nil
		
		super.init(cellIdentifier: "Cell")
	}
	
	override func configure(cell: UITableViewCell) {
		let cell = cell as! NCDefaultTableViewCell
		cell.titleLabel?.attributedText = title
		cell.subtitleLabel?.text = subtitle
		cell.subtitleLabel?.textColor = self.tintColor
		cell.iconView?.image = image
		cell.iconView?.tintColor = self.tintColor
		cell.object = object
	}
	
	override var canExpand: Bool {
		return false
	}
}

class NCDatabaseCertTypeRow: NCTreeRow {
	let title: String?
	let image: UIImage?
	let object: Any?
	let subtitle: String?
	
	init(type: NCDBInvType, character: NCCharacter) {
		self.title = type.typeName
		
		let trainingQueue = NCTrainingQueue(character: character)
		trainingQueue.addRequiredSkills(for: type)
		let trainingTime = trainingQueue.trainingTime(characterAttributes: character.attributes)
		self.image = type.icon?.image?.image
		self.object = type.objectID
		self.subtitle = trainingTime > 0 ? NCTimeIntervalFormatter.localizedString(from: trainingTime, precision: .seconds) : nil
		super.init(cellIdentifier: "Cell")
	}
	
	override func configure(cell: UITableViewCell) {
		let cell = cell as! NCDefaultTableViewCell
		cell.titleLabel?.text = title
		cell.titleLabel?.textColor = UIColor.white
		cell.subtitleLabel?.text = subtitle
		cell.subtitleLabel?.textColor = UIColor.lightText
		cell.iconView?.image = image ?? NCDBEveIcon.defaultType.image?.image
		cell.object = object
	}
	
	override var canExpand: Bool {
		return false
	}
}


class NCDatabaseCertMasterySection: NCTreeSection {
	let trainingQueue: NCTrainingQueue
	let trainingTime: TimeInterval
	init(mastery: NCDBCertMastery, character: NCCharacter, children: [NCTreeNode]?) {
		trainingQueue = NCTrainingQueue(character: character)
		trainingQueue.add(mastery: mastery)
		trainingTime = trainingQueue.trainingTime(characterAttributes: character.attributes)
		let title = NSMutableAttributedString(string: String(format: NSLocalizedString("LEVEL %d", comment: ""), Int(mastery.level!.level) + 1), attributes: [NSForegroundColorAttributeName: UIColor.caption])
		if trainingTime > 0 {
			title.append(NSAttributedString(string: " (\(NCTimeIntervalFormatter.localizedString(from: trainingTime, precision: .seconds)))", attributes: [NSForegroundColorAttributeName: UIColor.white]))
		}
		
		super.init(cellIdentifier: "NCHeaderTableViewCell", attributedTitle: title, children: children)
	}
}

class NCDatabaseCertificateInfoViewController: UITableViewController, NCTreeControllerDelegate {
	var certificate: NCDBCertCertificate?
	var headerViewController: NCDatabaseCertificateInfoHeaderViewController?
	private var results: [[NCTreeSection]]?
	
	@IBOutlet var treeController: NCTreeController!
	@IBOutlet weak var segmentedControl: UISegmentedControl!
	override func viewDidLoad() {
		super.viewDidLoad()
		tableView.estimatedRowHeight = tableView.rowHeight
		tableView.rowHeight = UITableViewAutomaticDimension
		treeController.childrenKeyPath = "children"
		treeController.delegate = self
		
		if let certificate = certificate {
			let headerViewController = self.storyboard!.instantiateViewController(withIdentifier: "NCDatabaseCertificateInfoHeaderViewController") as! NCDatabaseCertificateInfoHeaderViewController
			headerViewController.certificate = certificate
			
			var frame = CGRect.zero
			frame.size = headerViewController.view.systemLayoutSizeFitting(CGSize(width: view.bounds.size.width, height:0), withHorizontalFittingPriority: UILayoutPriorityRequired, verticalFittingPriority: UILayoutPriorityFittingSizeLevel)
			headerViewController.view.frame = frame
			tableView.tableHeaderView = UIView(frame: frame)
			tableView.addSubview(headerViewController.view)
			addChildViewController(headerViewController)
			self.headerViewController = headerViewController
		}
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		if results == nil, let certificate = certificate {
			let progress = NCProgressHandler(viewController: self, totalUnitCount: 3)
			
			
			progress.progress.becomeCurrent(withPendingUnitCount: 1)
			NCCharacter.load(account: NCAccount.current) { character in
				NCDatabase.sharedDatabase?.performBackgroundTask { managedObjectContext in
					let certificate = try! managedObjectContext.existingObject(with: certificate.objectID) as! NCDBCertCertificate
					var masteries = [NCTreeSection]()
					for mastery in (certificate.masteries?.sortedArray(using: [NSSortDescriptor(key: "level.level", ascending: true)]) as? [NCDBCertMastery]) ?? [] {
						var rows = [NCDatabaseCertSkillRow]()
						for skill in mastery.skills?.sortedArray(using: [NSSortDescriptor(key: "type.typeName", ascending: true)]) as? [NCDBCertSkill] ?? [] {
							let row = NCDatabaseCertSkillRow(skill: skill, character: character)
							rows.append(row)
						}
						let section = NCDatabaseCertMasterySection(mastery: mastery, character: character, children: rows)
						section.expanded = section.trainingTime > 0
						masteries.append(section)
					}
					progress.progress.completedUnitCount += 1
					
					let request = NSFetchRequest<NCDBInvType>(entityName: "InvType")
					request.predicate = NSPredicate(format: "published = TRUE AND ANY certificates == %@", certificate)
					request.sortDescriptors = [NSSortDescriptor(key: "group.groupName", ascending: true), NSSortDescriptor(key: "typeName", ascending: true)]
					let controller = NSFetchedResultsController(fetchRequest: request, managedObjectContext: managedObjectContext, sectionNameKeyPath: "group.groupName", cacheName: nil)
					try? controller.performFetch()
					
					var types = [NCTreeSection]()
					
					for section in controller.sections ?? [] {
						var rows = [NCDatabaseCertTypeRow]()
						for type in section.objects as? [NCDBInvType] ?? [] {
							let row = NCDatabaseCertTypeRow(type: type, character: character)
							rows.append(row)
						}
						let title = "\(section.name) (\(rows.count))"
						let section = NCTreeSection(cellIdentifier: "NCHeaderTableViewCell", nodeIdentifier: nil, title: title.uppercased(), children: rows)
						section.expanded = false
						types.append(section)
					}
					progress.progress.completedUnitCount += 1
					
					DispatchQueue.main.async {
						self.results = [masteries, types]
						self.treeController.content = self.results?[self.segmentedControl.selectedSegmentIndex]
						self.treeController.reloadData()
						self.tableView.backgroundView = self.results?[self.segmentedControl.selectedSegmentIndex].count == 0 ? NCTableViewBackgroundLabel(text: NSLocalizedString("No Results", comment: "")) : nil
						progress.finih()
					}
				}
			}
			progress.progress.resignCurrent()
		}
	}
	
	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		if let headerViewController = headerViewController {
			DispatchQueue.main.async {
				var frame = CGRect.zero
				frame.size = headerViewController.view.systemLayoutSizeFitting(CGSize(width: size.width, height:0), withHorizontalFittingPriority: UILayoutPriorityRequired, verticalFittingPriority: UILayoutPriorityFittingSizeLevel)
				headerViewController.view.frame = frame
				self.tableView.tableHeaderView?.frame = frame
				self.tableView.tableHeaderView = self.tableView.tableHeaderView
			}
		}
	}
	
	@IBAction func onChangeSection(_ sender: Any) {
		self.treeController.content = results?[segmentedControl.selectedSegmentIndex]
		self.treeController.reloadData()
		self.tableView.backgroundView = results?[segmentedControl.selectedSegmentIndex].count == 0 ? NCTableViewBackgroundLabel(text: NSLocalizedString("No Results", comment: "")) : nil
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "NCDatabaseTypeInfoViewController" {
			let controller = segue.destination as? NCDatabaseTypeInfoViewController
			let object = (sender as! NCDefaultTableViewCell).object as! NSManagedObjectID
			controller?.type = (try? NCDatabase.sharedDatabase?.viewContext.existingObject(with: object)) as? NCDBInvType
		}
	}
	
	// MARK: NCTreeControllerDelegate
	
	func treeController(_ treeController: NCTreeController, cellIdentifierForItem item: AnyObject) -> String {
		return (item as! NCTreeNode).cellIdentifier
	}
	
	func treeController(_ treeController: NCTreeController, configureCell cell: UITableViewCell, withItem item: AnyObject) {
		(item as! NCTreeNode).configure(cell: cell)
	}
	
	func treeController(_ treeController: NCTreeController, isItemExpanded item: AnyObject) -> Bool {
		return (item as? NCTreeSection)?.expanded ?? true
	}
	
	func treeController(_ treeController: NCTreeController, didExpandCell cell: UITableViewCell, withItem item: AnyObject) {
		(item as? NCTreeSection)?.expanded = true
	}
	
	func treeController(_ treeController: NCTreeController, didCollapseCell cell: UITableViewCell, withItem item: AnyObject) {
		(item as? NCTreeSection)?.expanded = false
	}
}
