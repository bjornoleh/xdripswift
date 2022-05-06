//
//  TreatmentsViewController.swift
//  xdrip
//
//  Created by Eduardo Pietre on 23/12/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import Foundation
import UIKit


class TreatmentsViewController : UIViewController {
	
	// MARK: - private properties
	
	/// TreatmentCollection is used to get and sort data.
	private var treatmentCollection: TreatmentCollection?
	
	/// reference to coreDataManager
	private var coreDataManager: CoreDataManager!
	
	/// reference to treatmentEntryAccessor
	private var treatmentEntryAccessor: TreatmentEntryAccessor!
	
	// Outlets
	@IBOutlet weak var titleNavigation: UINavigationItem!
    
	@IBOutlet weak var tableView: UITableView!
	
    // MARK: - View Life Cycle
    
	override func viewWillAppear(_ animated: Bool) {
        
		super.viewWillAppear(animated)
		
		// Fixes dark mode issues
		if let navigationBar = navigationController?.navigationBar {
			navigationBar.barStyle = UIBarStyle.blackTranslucent
			navigationBar.barTintColor  = UIColor.black
			navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.white]
		}
		
		self.titleNavigation.title = Texts_TreatmentsView.treatmentsTitle
        
        // add observer for nightScoutTreatmentsUpdateCounter, to reload the screen whenever the value changes
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nightScoutTreatmentsUpdateCounter.rawValue, options: .new, context: nil)
        

        
	}
	

	/// Override prepare for segue, we must call configure on the TreatmentsInsertViewController.
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
		// Check if is the segueIdentifier to TreatmentsInsert.
		guard let segueIndentifier = segue.identifier, segueIndentifier == TreatmentsViewController.SegueIdentifiers.TreatmentsToNewTreatmentsSegue.rawValue else {
			return
		}
		
		// Cast the destination to TreatmentsInsertViewController (if possible).
		// And assures the destination and coreData are valid.
		guard let insertViewController = segue.destination as? TreatmentsInsertViewController else {

			fatalError("In TreatmentsInsertViewController, prepare for segue, viewcontroller is not TreatmentsInsertViewController" )
		}

		// Configure insertViewController with CoreData instance and complete handler.
        insertViewController.configure(treatMentEntryToUpdate: sender as? TreatmentEntry, coreDataManager: coreDataManager, completionHandler: {
            self.reload()
        })
        
	}
	
	
	// MARK: - public functions
	
	/// Configure will be called before this view is presented for the user.
	public func configure(coreDataManager: CoreDataManager) {
        
		// initalize private properties
		self.coreDataManager = coreDataManager
		self.treatmentEntryAccessor = TreatmentEntryAccessor(coreDataManager: coreDataManager)
	
		self.reload()
        
	}
	

	// MARK: - private functions
	
	/// Reloads treatmentCollection and calls reloadData on tableView.
	private func reload() {
        
        self.treatmentCollection = TreatmentCollection(treatments: treatmentEntryAccessor.getLatestTreatments(howOld: TimeInterval(days: 100)).filter( {!$0.treatmentdeleted} ))

		self.tableView.reloadData()
        
	}
    
    // MARK: - overriden functions

    /// when one of the observed settings get changed, possible actions to take
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if let keyPath = keyPath {
            if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
                
                switch keyPathEnum {
                    
                case UserDefaults.Key.nightScoutTreatmentsUpdateCounter :
                    // Reloads data and table.
                    self.reload()
                    
                default:
                    break
                }
            }
        }
    }

}


/// defines perform segue identifiers used within TreatmentsViewController
extension TreatmentsViewController {
	
	public enum SegueIdentifiers:String {
        
		/// to go from TreatmentsViewController to TreatmentsInsertViewController
		case TreatmentsToNewTreatmentsSegue = "TreatmentsToNewTreatmentsSegue"
        
	}
	
}

// MARK: - conform to UITableViewDelegate and UITableViewDataSource

extension TreatmentsViewController: UITableViewDelegate, UITableViewDataSource {
	
	func numberOfSections(in tableView: UITableView) -> Int {
		return self.treatmentCollection?.dateOnlys().count ?? 0
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		guard let treatmentCollection = treatmentCollection else {
			return 0
		}
		// Gets the treatments given the section as the date index.
		let treatments = treatmentCollection.treatmentsForDateOnlyAt(section)
		return treatments.count
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		guard let cell = tableView.dequeueReusableCell(withIdentifier: "TreatmentsCell", for: indexPath) as? TreatmentTableViewCell, let treatmentCollection = treatmentCollection else {
			fatalError("Unexpected Table View Cell")
		}
		
		let treatment = treatmentCollection.getTreatment(dateIndex: indexPath.section, treatmentIndex: indexPath.row)
		cell.setupWithTreatment(treatment)
		
		return cell
	}
	
	func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return true
	}
	
	func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		if (editingStyle == .delete) {
            
			guard let treatmentCollection = treatmentCollection else {
				return
			}

			// Get the treatment the user wants to delete.
			let treatment = treatmentCollection.getTreatment(dateIndex: indexPath.section, treatmentIndex: indexPath.row)
			
			// set treatmentDelete to true in coredata.
            treatment.treatmentdeleted = true
            
            // set uploaded to false, so that at next nightscout sync, the treatment will be deleted at NightScout
            treatment.uploaded = false
			
            coreDataManager.saveChanges()
            
            // trigger nightscoutsync
            UserDefaults.standard.nightScoutSyncTreatmentsRequired = true
            
			// Reloads data and table.
			self.reload()
            
		}
	}
	
	func tableView( _ tableView : UITableView,  titleForHeaderInSection section: Int) -> String? {
		
		guard let treatmentCollection = treatmentCollection else {
			return ""
		}
		
		// Title will be the date formatted.
		let date = treatmentCollection.dateOnlyAt(section).date

		let formatter = DateFormatter()
		formatter.dateFormat = "dd/MM/yyyy"

		return formatter.string(from: date)
	}
	
	func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
		guard let titleView = view as? UITableViewHeaderFooterView else {
			return
		}
		
		// Header background color
		titleView.tintColor = UIColor.gray
		
		// Set textcolor to white and increase font
		if let textLabel = titleView.textLabel {
			textLabel.textColor = UIColor.white
			textLabel.font = textLabel.font.withSize(18)
		}
	}

	func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return 40.0
	}
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        self.performSegue(withIdentifier: TreatmentsViewController.SegueIdentifiers.TreatmentsToNewTreatmentsSegue.rawValue, sender: treatmentCollection?.getTreatment(dateIndex: indexPath.section, treatmentIndex: indexPath.row))
        
    }
    
}
