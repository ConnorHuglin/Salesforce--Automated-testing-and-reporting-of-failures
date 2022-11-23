@isTest(SeeAllData = true)
public class ReportEmailerSchedulerTest {
    public static testMethod void ReportEmailerSchedulerTest() {
        /*Report rep = [SELECT Id FROM Report LIMIT 1]; // NEED A REPORT TO TEST

        Report_Emailer_Setting__mdt customMetaData = new Report_Emailer_Setting__mdt();
        customMetaData.Report_Export_File_Name__c = 'TestExport';
        customMetaData.Report_Id__c = rep.Id;
        customMetaData.Report_Name__c = 'Test Export';
        customMetaData.Recipient_Email__c = 'connor@cloudmuscle.nl';
        insert customMetaData;*/

        test.startTest();
        ReportEmailerScheduler s = new ReportEmailerScheduler();
        s.execute(null);
        test.stopTest();
    }
}