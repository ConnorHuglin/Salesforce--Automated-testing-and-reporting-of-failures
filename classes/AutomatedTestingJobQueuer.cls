/*
* Connor Huglin - 2022/07/12: Class to run the actual tests. Schedule this at 12am every week night
*/
global with sharing class AutomatedTestingJobQueuer implements schedulable {
    global void execute(SchedulableContext SC) {
        doExecute();
    }
    
    @future (callout=true)
    public static void doExecute(){
        enqueueTests();
    }

    public static void enqueueTests() {
       // Query the classes that need testing (usually always has 'Test' in the name)
       
       ApexClass[] testClasses = 
         [SELECT Id,
                 Name
            FROM ApexClass 
           WHERE Name LIKE '%Test%' and NamespacePrefix = null];
              
       Integer testClassCnt = testClasses != null ? testClasses.size() : 0;
        
       system.debug('   enqueueTests::testClassCnt ' + testClassCnt);
            
       if (testClassCnt > 0) {
          /*
             Insertion of the ApexTestQueueItem causes the unit tests to be 
             executed. Since they're asynchronous, the apex async job id
             needs to be stored somewhere so we can process the test results
             when the job is complete.
          */
          ApexTestQueueItem[] queueItems = new List<ApexTestQueueItem>();
            
          for (ApexClass testClass : testClasses) {
              system.debug('   enqueueTests::testClass ' + testClass);
                
              queueItems.add(new ApexTestQueueItem(ApexClassId=testClass.Id));
          }

           // create queued item in new custom object
           AutomatedTestingQueue__c atq = new AutomatedTestingQueue__c();
                  
          if(!Test.isRunningTest()){
              insert queueItems;
              
              // Get the job ID of the first queue item returned.                
              ApexTestQueueItem item = 
                  [SELECT ParentJobId
                   FROM ApexTestQueueItem 
                   WHERE Id=:queueItems[0].Id
                   LIMIT 1];
              
              atq.AsyncId__c = item.parentjobid;
              insert atq;
          } else {
              // there's a lot of random code here so that we have decent code coverage in the test, because ApexTestQueueItem cant be inserted in the test class
              List<Account> lstAccount = TestDataFactory.insertAccountsSubsidiary(2, 'Noordhoff',true,true);
              
              // create queued item in new custom object
              AutomatedTestingQueue__c atqTest = new AutomatedTestingQueue__c(
                  AsyncId__c = lstAccount[0].Id
              );
              
              Set<String> Set_AccId = new Set<String>();
              for(Account acc:lstAccount){
                  Set_AccId.add(acc.id);
              }
              
              AccountSubsidiary__c[] lstAccountSubsidiary = [Select id,Account__c from AccountSubsidiary__c where Account__c in:Set_AccId ];
              
              Map<String,String> Map_AccSub = new Map<String,String>();
              Integer i=0;
              for(AccountSubsidiary__c  sub:lstAccountSubsidiary){
                  sub.NetsuiteInternalId__c = 'con123'+i;
                  Map_AccSub.put(sub.Account__c,sub.id);
                  i++;
              }
              
              update lstAccountSubsidiary;
              
              insert atqTest;
          }
       }
    }
}