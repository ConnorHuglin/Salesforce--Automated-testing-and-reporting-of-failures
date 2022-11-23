/*
* Connor Huglin - 2022/03/31: Generic class that will use custom metadata to export reports dynamically
* and send the reports dynamically to an email address (this was developed for Salesforce -> Slack integration)
* ----------------------------------------------------------
* Execute Anonymous (for testing):
* ReportEmailerScheduler s = new ReportEmailerScheduler();
* s.execute(null);
* ----------------------------------------------------------
*/
global class ReportEmailerScheduler implements System.Schedulable {
    global void execute(SchedulableContext sc) {
        handleReportEmailer();
    }
    
    @future(callout=true)
    public static void handleReportEmailer(){
        // fetch custom metadata records
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        List<Report_Emailer_Setting__mdt> reportList = [SELECT Report_Export_File_Name__c, Report_Id__c, Report_Name__c, Recipient_Email__c FROM Report_Emailer_Setting__mdt];
        
        // handle each reort's attachment
        if(reportList.size() > 0){
            for(Report_Emailer_Setting__mdt report : reportList){
                String reportId = (String)report.Report_Id__c;     
                string reportName = (String)report.Report_Export_File_Name__c;  
                
                // section to get count of records in report. Only add report to emailsToSend if the report has records
                Reports.ReportResults results = Reports.ReportManager.runReport(reportId, true);
                Reports.ReportFactWithDetails factDetails = (Reports.ReportFactWithDetails)results.getFactMap().get('T!T');
                List<Reports.SummaryValue> resultCount = factDetails.getAggregates();
                Decimal grandTotal = (Decimal)resultCount.get(resultCount.size()-1).getValue();
                system.debug('=== REPORT COUNT === : ' + reportName + ' : ' + grandTotal);
                // end section

                if(grandTotal > 0){
                    ApexPages.PageReference objPage = new ApexPages.PageReference('/' + reportId + '?csv=1&isdtp=p1');                    
                    Messaging.EmailFileAttachment objMsgEmailAttach = new Messaging.EmailFileAttachment();
                    objMsgEmailAttach.setFileName(reportName + '.csv');
                    objMsgEmailAttach.setContentType('text/csv');

                    if(!Test.isRunningTest())
                        objMsgEmailAttach.setBody(objPage.getContent());  
                    
                    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                    email.setUseSignature(false);
                    email.setToAddresses(new List<String>{report.Recipient_Email__c});
                    email.setSubject(report.Report_Name__c + ' Daily Report from Salesforce');
                    email.setHtmlBody('<br/><br/>Please review the report attached.<br/><br/><br/><br/>');
                    
                    if(!Test.isRunningTest())
                        email.setFileAttachments(new Messaging.EmailFileAttachment[] {objMsgEmailAttach});
                    
                    emailsToSend.add(email);
                }
            }
        }
        
        if(emailsToSend.size() > 0)
            Messaging.sendEmail(emailsToSend);
    }
}