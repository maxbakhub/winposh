# Get-MessageReadStatusReport.ps1 
# Tracking read and unread status of email messages in on-prem Exchange Server
# ref http://woshub.com/check-read-unread-email-status-exchange/

[CmdletBinding()]
  param (
  [Parameter( Mandatory=$true)]
  [string]$Mailbox,
  [Parameter( Mandatory=$true)]
  [string]$MessageId
  )
$output = @()
#Checking Exchange organization read tracking state
  if (!(Get-OrganizationConfig).ReadTrackingEnabled) {
    throw "Email tracking status is disabled"
  }
#Getting an email ID
$msg = Search-MessageTrackingReport -Identity $Mailbox -BypassDelegateChecking -MessageId $MessageId
#There should be one message
  if ($msg.count -ne 1) {
   throw "$($msg).count emails found with this ID"
  }
#Getting a report
$report = Get-MessageTrackingReport -Identity $msg.MessageTrackingReportId -BypassDelegateChecking
#Getting events
$recipienttrackingevents = @($report | Select -ExpandProperty RecipientTrackingEvents)
#Generating a list of recipients
$recipients = $recipienttrackingevents | select recipientaddress
#Getting an email status for each recipient
  foreach ($recipient in $recipients) {
    $events = Get-MessageTrackingReport -Identity $msg.MessageTrackingReportId -BypassDelegateChecking `
    -RecipientPathFilter $recipient.RecipientAddress -ReportTemplate RecipientPath
    $outputline = $events.RecipientTrackingEvents[-1] | Select RecipientAddress,Status,EventDescription
    $output += $outputline
  }
$output
$directory = "C:\PS\ExchangeReports"
$filename = 'ReadStatusReport'
$file = "$filename.csv"
#Exporting the report to CSV
$output | Export-Csv -NoTypeInformation -Append -Path "$directory\$file"
