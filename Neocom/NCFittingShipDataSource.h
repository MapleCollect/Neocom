//
//  NCFittingShipDataSource.h
//  Neocom
//
//  Created by Артем Шиманский on 28.01.14.
//  Copyright (c) 2014 Artem Shimanski. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NCTableViewController;
@class NCFittingShipViewController;
@class NCTask;
@interface NCFittingShipDataSource : NSObject<UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong, readonly) UIView* tableHeaderView;
@property (nonatomic, weak) UITableView* tableView;
@property (nonatomic, weak) NCFittingShipViewController* controller;
@property (nonatomic, weak) NCTableViewController* tableViewController;

- (void) reload;
- (NSString*) tableView:(UITableView *)tableView cellIdentifierForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void) tableView:(UITableView *)tableView configureCell:(UITableViewCell*) tableViewCell forRowAtIndexPath:(NSIndexPath*) indexPath;

@end
