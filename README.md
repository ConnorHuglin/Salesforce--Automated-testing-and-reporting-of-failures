# Salesforce--Automated-testing-and-reporting-of-failures
Job to run apex test classes on a daily basis, which stores the failures in the ErrorLog__c custom object. A report can be used to filter these records, and the report emailer can be used to email the report out


1) Schedule the apex class "AutomatedTestingJobQueuer". This will schedule all the test classes to run. You can also make it run immediately by pasting this into the execute anonymous window:
AutomatedTestingJobQueuer ctrlQ = new AutomatedTestingJobQueuer();
ctrlQ.execute(null);

2) Schedule the apex class "AutomatedTestingJob" to run a few hours after AutomatedTestingJobQueuer is scheduled to run (so that it ensures that all the test classes have run before further processing is done). AutomatedTestingJob will then use the data from the test classes to create records in the ErrorLog__c object. You can also schedule AutomatedTestingJob to run after the test classes have finished running by pasting this into the execute anonymous window:
AutomatedTestingJob ctrl = new AutomatedTestingJob();
ctrl.execute(null);

3) The failures get stored in ErrorLog__c. Create a report for this.

4) Schedule the apex class "ReportEmailerScheduler" to run after the job in step 2 runs. ReportEmailerScheduler uses the custom metadata "Report Emailer Setting" to dynamically send out reports to a specified email
You can also make the emails send immediately by pasting the following into execute anonymous:
ReportEmailerScheduler s = new ReportEmailerScheduler();
s.execute(null);
