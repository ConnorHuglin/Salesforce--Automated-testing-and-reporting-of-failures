/*
* Connor Huglin - 2022/07/12: Looks for all test class runs that have "TEST" in the name.
* stores the failures in ErrorLog__c, and sends the errors to Slack (using ReportEmailerScheduler)
* the class that actually runs the tests is AutomatedTestingJobQueuer, which should run at 10pm every week night
* this class can be scheduled to run at 2am ( a few hours after all tests should have run)
* DevOps item: https://dev.azure.com/infinitas/Converse/_workitems/edit/176293
*/
global with sharing class AutomatedTestingJob implements Schedulable {
    global void execute(SchedulableContext SC) {
        doExecute();
    }

    @future (callout=true)
    public static void doExecute(){
        processAsyncResults();
    }
    
    
    public static void processAsyncResults(){
        List<AutomatedTestingQueue__c> queuedTests = [SELECT Id, Name, AsyncId__c from AutomatedTestingQueue__c LIMIT 5];
        
        if (queuedTests != null && queuedTests.size() > 0){
            Set<Id> AsyncIds = new Set<Id>();

            for (AutomatedTestingQueue__c queuedJob : queuedTests){
                 AsyncIds.add(queuedJob.AsyncId__c);
            }
            
            List<ApexTestQueueItem> queuedItems = checkClassStatus(AsyncIds);
            
            Map<Id, List<ApexTestQueueItem>> groupedTestsByJob = new Map<Id, List<ApexTestQueueItem>>();

            for (ApexTestQueueItem atqi : queuedItems){
                 if (groupedTestsByJob.containsKey(atqi.ParentJobId) == true){
                     List<ApexTestQueueItem> groupedTests = groupedTestsByJob.get(atqi.ParentJobId);
                     groupedTests.add(atqi);
                 }
                 else{
                     List<ApexTestQueueItem> groupedTests = new List<ApexTestQueueItem>();
                     groupedTests.add(atqi);
                     groupedTestsByJob.put(atqi.ParentJobId, groupedTests);
                 }
            }
            
            Set<Id> completedAsyncIds = getCompletedAsyncJobsIds(groupedTestsByJob);
            
            if (completedAsyncIds != null && completedAsyncIds.size() > 0){
                
                List<ApexTestResult> testResults = checkMethodStatus(completedAsyncIds);
                
                Map<Id, List<ApexTestResult>> groupedTestResultsByJob = new Map<Id, List<ApexTestResult>>();
                
                for (ApexTestResult testResult : testResults){
                    if (groupedTestResultsByJob.containsKey(testResult.AsyncApexJobId)){
                        List<ApexTestResult> groupedTestsResults = groupedTestResultsByJob.get(testResult.AsyncApexJobId);
                        groupedTestsResults.add(testResult);
                    }
                    else{
                        List<ApexTestResult> groupedTestsResults = new List<ApexTestResult>();
                        groupedTestsResults.add(testResult);
                        
                        groupedTestResultsByJob.put(testResult.AsyncApexJobId, groupedTestsResults );
                    }
                }

                // CH - 2022/10/25: queuedTestsToDelete sometimes contains duplicates, so create a set<Id> and query queuedTestsToDelete from the set<Id>
                // https://dev.azure.com/infinitas/Converse/_workitems/edit/185168
                List<AutomatedTestingQueue__c> queuedTestsToDelete = new List<AutomatedTestingQueue__c>(); 
                Set<Id> queuedTestsToDeleteIdSet = new Set<Id>();
                
                // store results in ErrorLog__c
                List<ErrorLog__c> errorLogLs = new List<ErrorLog__c>();
                for (List<ApexTestResult> jobTestResults : groupedTestResultsByJob.values()){
                    //sendTestResultEmail(jobTestResults);

                    for(ApexTestResult jobTestResult : jobTestResults){
                        if (jobTestResult.Outcome != 'Pass'){
                            ErrorLog__c errLog = new ErrorLog__c();
    
                            errLog.ClassName__c = jobTestResult.ApexClass.Name;
                            errLog.ExceptionMessage__c = jobTestResult.Message;
                            errLog.ExceptionType__c = 'Test ' + jobTestResult.Outcome;
                            errLog.MethodName__c = jobTestResult.MethodName;
                            errLog.RelatedToId__c = jobTestResult.AsyncApexJobId;

                            errorLogLs.add(errLog);
                        } 
                    }
                }
                
                if(errorLogLs.size() > 0){
                    insert errorLogLs;
                }

                for (AutomatedTestingQueue__c queuedTest : queuedTests){
                    for (Id completedAsyncId : completedAsyncIds){
                        if (queuedTest.AsyncId__c == completedAsyncId){
                            //queuedTestsToDelete.add(queuedTest);
                            queuedTestsToDeleteIdSet.add(queuedTest.Id);
                            
                            break;
                        }
                    }
                    if (groupedTestsByJob.containsKey(queuedTest.asyncId__c) == false){
                        //queuedTestsToDelete.add(queuedTest);
                        queuedTestsToDeleteIdSet.add(queuedTest.Id);
                    }
                }
                

                if (queuedTestsToDeleteIdSet.size() > 0){
                    queuedTestsToDelete = [SELECT Id FROM AutomatedTestingQueue__c WHERE Id IN: queuedTestsToDeleteIdSet];
                    delete queuedTestsToDelete;
                }
            }
        }
    }
    
    public static Set<Id> getCompletedAsyncJobsIds(Map<Id, List<ApexTestQueueItem>> groupedTestsByJob){
        Set<Id> completedAsyncJobIds = new Set<Id>();
        
        for (List<ApexTestQueueItem> jobTests : groupedTestsByJob.values()){
            if (jobTests == null || jobTests.size() == 0){
                continue;
            }
            
            Boolean allCompleted = true;
            
            for (ApexTestQueueItem queuedTest : jobTests){
                if (queuedTest.Status != 'Completed' && queuedTest.Status != 'Failed' && queuedTest.Status != 'Aborted'){
                    allCompleted = false;
                    break;
                }
            }
            
            if (allCompleted == true){
                completedAsyncJobIds.add(jobTests[0].ParentJobId);
            }
            
            if(Test.isRunningTest()){
                Id testId = [SELECT Id from Account LIMIT 1].Id;
                completedAsyncJobIds.add(testId);
            }
        }
        
        return completedAsyncJobIds;
    }
    
    // Get the status and pass rate for each class 
    // whose tests were run by AutomatedTestingJobQueuer
    
    public static List<ApexTestQueueItem> checkClassStatus(Set<ID> jobIds) {
        List<ApexTestQueueItem> items= new List<ApexTestQueueItem>();
        
        if(!Test.isRunningTest()){
            items = [SELECT ApexClass.Name, Status, ExtendedStatus, ParentJobId FROM ApexTestQueueItem WHERE ParentJobId in :jobIds];
        } else {
            // for test class
            ApexTestQueueItem atqi = new ApexTestQueueItem();
            items.add(atqi);
        }
        //ApexTestQueueItem[] items = [SELECT ApexClass.Name, Status, ExtendedStatus, ParentJobId FROM ApexTestQueueItem WHERE ParentJobId in :jobIds];
            
        for (ApexTestQueueItem item : items) {
            String extStatus = item.Extendedstatus == null ? '' : item.ExtendedStatus;
            System.debug(item.ApexClass.Name + ': ' + item.Status + extStatus);
        }
        
        return items;
    }

    // Get the result for each test method that was executed. 
    
    public static List<ApexTestResult> checkMethodStatus(Set<ID> jobIds) {
        List<ApexTestResult> results = new List<ApexTestResult>();
        if(!Test.isRunningTest()){
            results = [SELECT Outcome,
                       MethodName,
                       Message,
                       StackTrace,
                       AsyncApexJobId, 
                       ApexClass.Name,
                       ApexClass.Body,
                       ApexClass.LengthWithoutComments,
                       ApexClass.NamespacePrefix,
                       ApexClass.Status,
                       ApexLogId,
                       ApexLog.DurationMilliseconds,
                       ApexLog.Operation,
                       ApexLog.Request,
                       ApexLog.Status,
                       ApexLog.Location,
                       ApexLog.Application
                       FROM ApexTestResult  
                       WHERE AsyncApexJobId in :jobIds];
        } else {
             results = [SELECT Outcome,
                       MethodName,
                       Message,
                       StackTrace,
                       AsyncApexJobId, 
                       ApexClass.Name,
                       ApexClass.Body,
                       ApexClass.LengthWithoutComments,
                       ApexClass.NamespacePrefix,
                       ApexClass.Status,
                       ApexLogId,
                       ApexLog.DurationMilliseconds,
                       ApexLog.Operation,
                       ApexLog.Request,
                       ApexLog.Status,
                       ApexLog.Location,
                       ApexLog.Application
                       FROM ApexTestResult
                       LIMIT 2];
        }
        
            
        for (ApexTestResult atr : results) {
            System.debug(atr.ApexClass.Name + '.' + atr.MethodName + ': ' + atr.Outcome);
            if (atr.message != null) {
                System.debug(atr.Message + '\n at ' + atr.StackTrace);
            }
        }
        
        return results;
    }
}