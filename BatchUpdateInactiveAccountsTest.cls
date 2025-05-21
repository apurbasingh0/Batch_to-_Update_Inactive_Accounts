@isTest
public class BatchUpdateInactiveAccountsTest {
    
    @testSetup
    static void setupTestData() {
        // Step 1: Create an Organization Account (for Project_Org_Name__c)
        Account orgAccount = new Account(Name = 'Test Organization');
        insert orgAccount;  


        // Step 3: Create **One** Project
        Project__c project = new Project__c(
            Name = 'Test Project', 
            Project_Type__c = 'Residential',  // ✅ Required field
            Project_Org_Name__c = orgAccount.Id
        );
        insert project;

        // Step 4: Create an Account (linked to the project)
        Account account = new Account(
            Name = 'Test Account', 
            A360__c = true
        );
        insert account;

        // Step 5: Create a Contact for the Account **(Directly Assigned to Project)**
        Contact contact = new Contact(
            LastName = 'Test Contact',
            AccountId = account.Id,
            Project__c = project.Id // ✅ Direct relationship
        );
        insert contact;

        // Step 6: Create a ProjectContactRelation__c record (Direct Assignment)
        ProjectContactRelation__c projectContactRelation = new ProjectContactRelation__c(
            Project__c = project.Id,
            Contact__c = contact.Id,
            OwnerId = UserInfo.getUserId(),  
            Roles__c = 'Business User'
        );
        insert projectContactRelation;

        // Step 7: Create an Opportunity linked to the Account
        Opportunity opportunity = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = account.Id,
            StageName = 'Prospecting',  // ✅ Required by validation rule
            CloseDate = Date.today().addMonths(1) 
        );

        // ✅ Assign Primary Contact (if required)
        if (Schema.sObjectType.Opportunity.fields.getMap().containsKey('Primary_Contact__c')) {
            opportunity.put('Primary_Contact__c', contact.Id); 
        }
        
        insert opportunity;
    }

    @isTest
    static void testBatchExecution() {  
        // ✅ Fetch the test Account ID
        Id accountId = [SELECT Id FROM Account LIMIT 1].Id;

        Test.startTest();
        BatchUpdateInactiveAccounts batchJob = new BatchUpdateInactiveAccounts(new Set<Id>{accountId}); // ✅ Pass Account ID
        Database.executeBatch(batchJob, 2);
        Test.stopTest();

        // ✅ Verify updates
        Opportunity updatedOpportunity = [SELECT AccountId, Old_Account_Id__c FROM Opportunity WHERE Old_Account_Id__c != null LIMIT 1];
        System.assert(updatedOpportunity != null, 'Opportunity should have been updated.');
    }
}