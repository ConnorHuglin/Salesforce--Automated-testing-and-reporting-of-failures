@isTest(SeeAllData = true)
public class AutomatedTestingJob_Test {
    public static testMethod void AutomatedTestingJob_Test() {
        test.startTest();
        AutomatedTestingJobQueuer ctrlQ = new AutomatedTestingJobQueuer();
        ctrlQ.execute(null);
        
        AutomatedTestingJob ctrl = new AutomatedTestingJob();
        ctrl.execute(null);
        
        test.stopTest();
    }
}