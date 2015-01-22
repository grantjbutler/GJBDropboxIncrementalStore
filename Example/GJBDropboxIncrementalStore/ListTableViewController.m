//
//  ListTableViewController.m
//  GJBDropboxIncrementalStore
//
//  Created by Grant Butler on 1/17/15.
//  Copyright (c) 2015 Grant Butler. All rights reserved.
//

#import "ListTableViewController.h"
#import "List.h"
#import "Task.h"

@interface ListTableViewController () <NSFetchedResultsControllerDelegate>

@property (nonatomic, readonly) NSManagedObjectContext *context;

@property (nonatomic) NSFetchedResultsController *fetchedResultsController;

@property (nonatomic) UIBarButtonItem *editTasksBarButtonItem;
@property (nonatomic) UIBarButtonItem *doneBarButtonItem;
@property (nonatomic, getter=isEditingTasks) BOOL editingTasks;

@end

@implementation ListTableViewController

- (void)setList:(List *)list {
	_list = list;
	
	self.title = self.list.name;
	
	if (self.isViewLoaded) {
		[self.tableView reloadData];
	}
}

- (NSManagedObjectContext *)context {
	return self.list.managedObjectContext;
}

- (UIBarButtonItem *)editTasksBarButtonItem {
	if (!_editTasksBarButtonItem) {
		_editTasksBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(toggleEditingTasks:)];
	}
	
	return _editTasksBarButtonItem;
}

- (UIBarButtonItem *)doneBarButtonItem {
	if (!_doneBarButtonItem) {
		_doneBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(toggleEditingTasks:)];
	}
	
	return _doneBarButtonItem;
}

#pragma mark -

- (void)viewDidLoad {
    [super viewDidLoad];
	
	self.tableView.editing = YES;
	self.tableView.allowsSelectionDuringEditing = YES;
	
	self.navigationItem.rightBarButtonItem = self.editTasksBarButtonItem;
	
	[self setupFetchedResultsController];
}

- (void)setupFetchedResultsController {
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"Task" inManagedObjectContext:self.context];
	[fetchRequest setEntity:entity];
	[fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"%K == %@", NSStringFromSelector(@selector(list)), self.list]];
	[fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"completed" ascending:YES], [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
	
	self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.context sectionNameKeyPath:nil cacheName:nil];
	self.fetchedResultsController.delegate = self;
	
	NSError *error;
	if (![self.fetchedResultsController performFetch:&error]) {
		NSLog(@"Error fetching: %@", error);
	}
}

- (void)addTask {
	UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Add Task" message:nil preferredStyle:UIAlertControllerStyleAlert];
	
	[alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
		textField.placeholder = @"Task Name";
	}];
	UITextField *taskNameTextField = alertController.textFields.lastObject;
	
	[alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
	[alertController addAction:[UIAlertAction actionWithTitle:@"Add Task" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"Task" inManagedObjectContext:self.context];
		Task *task = [[Task alloc] initWithEntity:entity insertIntoManagedObjectContext:self.context];
		task.name = taskNameTextField.text;
		task.list = self.list;
		
		[self saveContext];
	}]];
	[self presentViewController:alertController animated:YES completion:nil];
}

- (IBAction)toggleEditingTasks:(id)sender {
	self.editingTasks = !self.isEditingTasks;
	
	UIBarButtonItem *barButtonItem;
	
	if (self.isEditingTasks) {
		barButtonItem = self.doneBarButtonItem;
	}
	else {
		barButtonItem = self.editTasksBarButtonItem;
	}
	
	[self.navigationItem setRightBarButtonItem:barButtonItem animated:YES];
	
	[self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
}

#pragma mark - Table view data source

- (BOOL)isIndexPathAddRowIndexPath:(NSIndexPath *)indexPath {
	return indexPath.row == 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.list.tasks.count + 1;
}

- (NSIndexPath *)taskIndexPathForRowIndexPath:(NSIndexPath *)indexPath {
	return [NSIndexPath indexPathForRow:indexPath.row - 1 inSection:indexPath.section];
}

- (NSIndexPath *)rowIndexPathForTaskIndexPath:(NSIndexPath *)indexPath {
	return [NSIndexPath indexPathForRow:indexPath.row + 1 inSection:indexPath.section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell;
	
	if ([self isIndexPathAddRowIndexPath:indexPath]) {
		cell = [tableView dequeueReusableCellWithIdentifier:@"AddTaskCell" forIndexPath:indexPath];
		
		cell.editing = YES;
	}
	else {
		cell = [tableView dequeueReusableCellWithIdentifier:@"TaskCell" forIndexPath:indexPath];
		
		NSIndexPath *taskIndexPath = [self taskIndexPathForRowIndexPath:indexPath];
		Task *task = [self.fetchedResultsController objectAtIndexPath:taskIndexPath];
		cell.textLabel.text = task.name;
		
		BOOL isCompleted = task.completed;
		
		if (isCompleted) {
			cell.accessoryType = UITableViewCellAccessoryCheckmark;
			cell.textLabel.textColor = [UIColor lightGrayColor];
			cell.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
		}
		else {
			cell.accessoryType = UITableViewCellAccessoryNone;
			cell.textLabel.textColor = [UIColor blackColor];
			cell.backgroundColor = [UIColor whiteColor];
		}
	}
	
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	if ([self isIndexPathAddRowIndexPath:indexPath]) {
		[self addTask];
	}
	else {
		NSIndexPath *taskIndexPath = [self taskIndexPathForRowIndexPath:indexPath];
		Task *task = [self.fetchedResultsController objectAtIndexPath:taskIndexPath];
		task.completed = !task.completed;
		
		[self saveContext];
	}
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.isEditingTasks) {
		return YES;
	}
	
	return [self isIndexPathAddRowIndexPath:indexPath];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([self isIndexPathAddRowIndexPath:indexPath]) {
		return UITableViewCellEditingStyleInsert;
	}
	
	if (self.isEditingTasks) {
		return UITableViewCellEditingStyleDelete;
	}
	
	return UITableViewCellEditingStyleNone;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([self isIndexPathAddRowIndexPath:indexPath]) {
		return;
	}
	
	NSIndexPath *taskIndexPath = [self taskIndexPathForRowIndexPath:indexPath];
	Task *task = [self.fetchedResultsController objectAtIndexPath:taskIndexPath];
	[self.context deleteObject:task];
	[self saveContext];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	return ![self isIndexPathAddRowIndexPath:indexPath];
}

#pragma mark -

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
	[self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
	NSIndexPath *rowIndexPath = [self rowIndexPathForTaskIndexPath:indexPath];
	NSIndexPath *newRowIndexPath = [self rowIndexPathForTaskIndexPath:newIndexPath];
	
	switch (type) {
		case NSFetchedResultsChangeInsert:
			[self.tableView insertRowsAtIndexPaths:@[newRowIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
			break;
			
		case NSFetchedResultsChangeDelete:
			[self.tableView deleteRowsAtIndexPaths:@[rowIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
			break;
			
		case NSFetchedResultsChangeUpdate:
			[self.tableView reloadRowsAtIndexPaths:@[rowIndexPath] withRowAnimation:UITableViewRowAnimationFade];
			break;
			
		case NSFetchedResultsChangeMove:
			[self.tableView deleteRowsAtIndexPaths:@[rowIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
			[self.tableView insertRowsAtIndexPaths:@[newRowIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
			break;
	}
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
	[self.tableView endUpdates];
}

#pragma mark -

- (void)saveContext {
	NSError *error;
	if (![self.context save:&error]) {
		NSLog(@"Error saving: %@", error);
	}
}

@end
