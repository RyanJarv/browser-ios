/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit

import Storage

class HistoryPanel: SiteTableViewController {
    private let NumSections = 4
    private var sectionStart = [Int: Int]()

    override func reloadData() {
        let opts = QueryOptions()
        opts.sort = .LastVisit
        profile.history.get(opts, complete: { (data: Cursor) -> Void in
            self.refreshControl?.endRefreshing()
            self.sectionStart = [Int: Int]()
            self.data = data
            self.tableView.reloadData()
        })
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAtIndexPath: indexPath)
        let offset = sectionStart[indexPath.section]!
        if let site = data[indexPath.row + offset] as? Site {
            cell.textLabel?.text = site.title
            cell.detailTextLabel?.text = site.url
            if let img = site.icon? {
                let imgURL = NSURL(string: img.url)
                cell.imageView?.sd_setImageWithURL(imgURL, placeholderImage: self.profile.favicons.defaultIcon)
            } else {
                cell.imageView?.image = self.profile.favicons.defaultIcon
            }
        }

        return cell
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let offset = sectionStart[indexPath.section]!
        if let site = data[indexPath.row + offset] as? Site {
            if let url = NSURL(string: site.url) {
                homePanelDelegate?.homePanel(didSubmitURL: url)
                return
            }
        }
        println("Could not click on history row")
    }

    // Functions that deal with showing header rows
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return NumSections
    }

    override func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let cell = super.tableView(tableView, viewForHeaderInSection: section) as UITableViewHeaderFooterView!
        switch section {
        case 0: cell.textLabel.text = "Today"
        case 1: cell.textLabel.text = "Yesterday"
        case 2: cell.textLabel.text = "Last week"
        case 3: cell.textLabel.text = "Last month"
        default:
            assertionFailure("Invalid history section \(section)")
        }

        return cell
    }

    lazy private var today: NSDate = {
        var today = NSDate()
        var calendar = NSCalendar(calendarIdentifier: NSGregorianCalendar)!
        let nowComponents = calendar.components(NSCalendarUnit.YearCalendarUnit | NSCalendarUnit.MonthCalendarUnit | NSCalendarUnit.DayCalendarUnit, fromDate:today)
        return calendar.dateFromComponents(nowComponents)!
    }()

    lazy private var yesterday: NSDate = {
        var today = NSDate()
        var calendar = NSCalendar(calendarIdentifier: NSGregorianCalendar)!
        let nowComponents = calendar.components(NSCalendarUnit.YearCalendarUnit | NSCalendarUnit.MonthCalendarUnit | NSCalendarUnit.DayCalendarUnit, fromDate:today)
        nowComponents.day--
        return calendar.dateFromComponents(nowComponents)!
    }()

    lazy private var thisweek: NSDate = {
        var today = NSDate()
        var calendar = NSCalendar(calendarIdentifier: NSGregorianCalendar)!
        let nowComponents = calendar.components(NSCalendarUnit.YearCalendarUnit | NSCalendarUnit.MonthCalendarUnit | NSCalendarUnit.DayCalendarUnit, fromDate:today)
        nowComponents.day -= 7
        return calendar.dateFromComponents(nowComponents)!
    }()

    private func isInSection(date: NSDate, section: Int) -> Bool {
        let now = NSDate()
        switch section {
        case 0:
            return date.timeIntervalSince1970 > today.timeIntervalSince1970
        case 1:
            return date.timeIntervalSince1970 > yesterday.timeIntervalSince1970
        case 2:
            return date.timeIntervalSince1970 > thisweek.timeIntervalSince1970
        default:
            return true
        }
    }

    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if let current = sectionStart[section] {
            if let next = sectionStart[section+1] {
                if current == next {
                    // If this points to the same element as the next one, its empty. Don't show it.
                    return 0
                }
            }
        } else {
            // This may not be filled in yet (for instance, if the number of rows in data is zero). If it is,
            // just return zero.
            return 0
        }

        // Return the default height for header rows
        return super.tableView(tableView, heightForHeaderInSection: section)
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let size = sectionStart[section] {
            if let nextSize = sectionStart[section+1] {
                return nextSize - size
            }
        }

        var searchingSection = 0
        sectionStart[searchingSection] = 0

        // Loop over all the data. Record the start of each "section" of our list.
        for i in 0..<data.count {
            if var site = data[i] as? Site {
                if !isInSection(site.latestVisit!.date, section: searchingSection) {
                    searchingSection++
                    sectionStart[searchingSection] = i
                }

                if searchingSection == NumSections {
                    break
                }
            }
        }

        // Now fill in any sections that weren't found with data.count.
        // Note, we actually fill in one past the end of the list to make finding the length
        // of a section easier.
        searchingSection++
        for i in searchingSection...NumSections {
            sectionStart[i] = data.count
        }

        // This function wants the size of a section, so return the distance between two adjacent ones
        return sectionStart[section+1]! - sectionStart[section]!
    }
}
