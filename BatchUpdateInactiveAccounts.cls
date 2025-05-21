/**
* @description       : used in "BatchUpdateInactiveAccounts" All the accounts which were prior to A360(inactive accounts), should be hidden from the end users. Only the accounts which holds open opportunities should be visible. 
* @authorName        : Apurba Singh
* @group             : Appstrail
* @last modified on  : 09-03-2025
* @last modified by  : Apurba Singh
**/
public class BatchUpdateInactiveAccounts implements database.stateful, Database.Batchable<sobject> {
    public Set<Id> accountIds;

    // Constructor to accept Account Id
    public BatchUpdateInactiveAccounts(Set<Id> accIds) {
        this.accountIds = accIds;
    }    

    public Database.QueryLocator start(Database.BatchableContext BC) {
        String query = System.Label.Inactive_Accounts_Query;

        // Ensure dynamic query includes Account IDs for filtering
        query += ' AND AccountId IN :accountIds';

        return Database.getQueryLocator(query);
    }
    /*public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(Label.Inactive_Accounts_Query);
    }*/
    
    public void execute(Database.BatchableContext BC, List<Opportunity> opportunities) {
        if (opportunities.isEmpty()) {
            return; // No need to process if no opportunities are found
        }
        System.debug('Get query of opportunities' + opportunities);
        List<Opportunity> oppsToUpdate2 = new List<Opportunity>();
        List<Account> accountsToUpdate = new List<Account>();
        List<Contact> contactsToUpdate = new List<Contact>();
        Set<Id> accountIds = new Set<Id>();  
        Set<Id> successfulOppAccountIds = new Set<Id>();
        Id sysUs = UserInfo.getUserId();
        System.debug('Current System User: ' + sysUs);
        for (Opportunity opp : opportunities) {
            accountIds.add(opp.AccountId);            
        }

        System.debug('opportunities' + opportunities);
        System.debug('accountIds' + accountIds);
        // Query for Open Opportunities (to filter out accounts with open opps)**
        Set<Id> accountsWithOpenOpportunities = new Set<Id>();
        if (!accountIds.isEmpty()) {
            List<Opportunity> openOpportunities = [
                SELECT AccountId 
                FROM Opportunity 
                WHERE AccountId IN :accountIds 
                AND StageName NOT IN ('Closed Lost', 'Completed', 'Shelved') 
                AND (StageName != 'Closed Won' OR Quantity_Available__c > 0)
            ];
            for (Opportunity opp : openOpportunities) {
                accountsWithOpenOpportunities.add(opp.AccountId);
            }
        } else {
            System.debug('accountIds is empty');
        }
        
        System.debug('Accounts with Open Opportunities: ' + accountsWithOpenOpportunities);
        
        for (Opportunity opp : opportunities) {
            if (!accountsWithOpenOpportunities.contains(opp.AccountId)) {
            opp.Old_Account_Id__c = opp.AccountId; // Store original account
            opp.AccountId = null;
            oppsToUpdate2.add(opp);
            }
        }
        
        System.debug('oppsToUpdate2: ' + oppsToUpdate2);
        
        if (!oppsToUpdate2.isEmpty()) {
            try {
                Database.SaveResult[] results = Database.update(oppsToUpdate2, false);
                System.debug('results oppo to update'+results);
                for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    successfulOppAccountIds.add(oppsToUpdate2[i].Old_Account_Id__c);
                }
            }
            } catch (Exception e) {
                System.debug('Error: ' + e.getMessage());
                throw new AuraHandledException(e.getMessage());
            }
        }
        System.debug('Successful Opportunity Account IDs: ' + successfulOppAccountIds);
        
        //Fetch Inactive Accounts (Exclude those with Open Opportunities)**
        if (!successfulOppAccountIds.isEmpty()) {
        List<Account> inactiveAccounts = [
            SELECT Id, OwnerId, PLSI_Account_Type__c 
            FROM Account 
            WHERE Id IN :successfulOppAccountIds 
            AND A360__c = true
            AND Id NOT IN :accountsWithOpenOpportunities
        ];
        
        System.debug('Inactive Accounts Found (No Open Opportunities): ' + inactiveAccounts);
        
        for (Account acc : inactiveAccounts) {
            acc.Account_Owner__c = acc.OwnerId;
            acc.OwnerId = sysUs;
            accountsToUpdate.add(acc);
            
        }
        
        // Fetch all related contacts outside the loop
        List<Contact> relatedContacts = [
            SELECT Id, OwnerId FROM Contact WHERE AccountId IN :successfulOppAccountIds AND AccountId NOT IN :accountsWithOpenOpportunities
        ];
        for (Contact con : relatedContacts) {
            con.OwnerId = sysUs;
            contactsToUpdate.add(con);
        }
        
        System.debug('Accounts to Update: ' + accountsToUpdate);
        System.debug('Contacts to Update: ' + contactsToUpdate);
        //Update Account Owner
        if (!accountsToUpdate.isEmpty()) {
            try {
                Database.SaveResult[] results = Database.update(accountsToUpdate, false);
                System.debug('results of account to update'+results);
            } catch (Exception e) {
                System.debug('Exception in Account Update: ' + e.getMessage());
            }
        }
        
        // Update Contact Owner
        if (!contactsToUpdate.isEmpty()) {
            Database.SaveResult[] results = Database.update(contactsToUpdate, false);
            System.debug('Updated Contacts Successfully.');
        }
      }          
    }
    
    public void finish(Database.BatchableContext BC) {
        System.debug('Batch processing completed.');
    }
}