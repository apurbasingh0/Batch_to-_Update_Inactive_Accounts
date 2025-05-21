"# Batch_to-_Update_Inactive_Accounts" 
Problem statement:
Currently there are inactive accounts which got deprecated while a360 (Account based), still are visible to the users.
That’s resulting in confusion while creating tasks, leads etc.

Functional Solution:
All the accounts which were prior to A360(inactive accounts), should be hidden from the end users. Only the accounts which holds open opportunities should be visible.

BatchUpdateInactiveAccounts
This Apex batch class updates inactive Accounts and their related Contacts by:
Unlinking Opportunities from Accounts with no open Opportunities.
Changing ownership of inactive Accounts and their Contacts to the system user.
Only processing Accounts marked with A360__c = true and without active Opportunities.

It uses a dynamic SOQL query from a custom label and tracks original Account ownership using custom fields.
Usage:
Set<Id> accountIds = new Set<Id>{/* Account Ids */};
Database.executeBatch(new BatchUpdateInactiveAccounts(accountIds));
