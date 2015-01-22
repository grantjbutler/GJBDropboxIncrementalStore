//
//  ListsTableViewController.m
//  GJBDropboxIncrementalStore
//
//  Created by Grant Butler on 1/17/15.
//  Copyright (c) 2015 Grant Butler. All rights reserved.
//

#import "ListsTableViewController.h"
#import "ListTableViewController.h"
#import "List.h"

@interface ListsTableViewController () <NSFetchedResultsControllerDelegate>

@property (nonatomic) NSFetchedResultsController *fetchedResultsController;

@end

@implementation ListsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
	[self setupFetchedResultsController];
	
	self.navigationItem.leftBarButtonItem = self.editButtonItem;
}

- (void)setupFetchedResultsController {
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"List" inManagedObjectContext:self.context];
	[fetchRequest setEntity:entity];
	[fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
	
	self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.context sectionNameKeyPath:nil cacheName:nil];
	self.fetchedResultsController.delegate = self;
	
	NSError *error;
	if (![self.fetchedResultsController performFetch:&error]) {
		NSLog(@"Error fetching: %@", error);
	}
}

- (IBAction)addList:(id)sender {
	UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Add List" message:nil preferredStyle:UIAlertControllerStyleAlert];
	
	[alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
		textField.placeholder = @"List Name";
	}];
	UITextField *listNameTextField = alertController.textFields.lastObject;
	
	[alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
	[alertController addAction:[UIAlertAction actionWithTitle:@"Add List" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"List" inManagedObjectContext:self.context];
		List *list = [[List alloc] initWithEntity:entity insertIntoManagedObjectContext:self.context];
		list.name = listNameTextField.text;
		
		[self saveContext];
	}]];
	[self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.fetchedResultsController.fetchedObjects.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ListCell" forIndexPath:indexPath];
	
	List *list = [self.fetchedResultsController objectAtIndexPath:indexPath];
	cell.textLabel.text = list.name;
	
    return cell;
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
	[self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
	switch (type) {
		case NSFetchedResultsChangeInsert:
			[self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
			break;
			
		case NSFetchedResultsChangeDelete:
			[self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
			break;
			
		case NSFetchedResultsChangeUpdate:
			[self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
			break;
			
		case NSFetchedResultsChangeMove:
			[self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
			[self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
			break;
	}
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
	[self.tableView endUpdates];
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
	ListTableViewController *listTableViewController = segue.destinationViewController;
	List *list = [self.fetchedResultsController objectAtIndexPath:self.tableView.indexPathForSelectedRow];
	listTableViewController.list = list;
}

#pragma mark - 

- (void)saveContext {
	NSError *error;
	if (![self.context save:&error]) {
		NSLog(@"Error saving: %@", error);
	}
}

@end
