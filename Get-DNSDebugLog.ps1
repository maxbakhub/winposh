#############################################################################
# This cmdlet parses a Windows DNS Debug log. See Example uses below
#
# Revision
#       v3.0 Re-write, bug and performance fixes by Mayuresh K. <22/03/2019>
#            Tested with DNS Trace files for Windows Server 2012 R2
#            Added support for -debug switch and printing of processed stats in debug mode
#       v2.0 Adaptation (by Oscar Virot at https://gallery.technet.microsoft.com/scriptcenter/Get-DNSDebugLog-Easy-ef048bdf)
#       v1.0 Initial Version (by ASabale at https://gallery.technet.microsoft.com/scriptcenter/Read-DNS-debug-log-and-532a8504)
#
# Credits
#        ASabale - https://gallery.technet.microsoft.com/scriptcenter/Read-DNS-debug-log-and-532a8504
#        Oscar Virot - https://gallery.technet.microsoft.com/scriptcenter/Get-DNSDebugLog-Easy-ef048bdf
#############################################################################
function Get-DNSDebugLog
{
    <#
    .SYNOPSIS
    This cmdlet parses a Windows DNS Debug log.
    .DESCRIPTION
    When a DNS log is converted with this cmdlet it will be turned into objects for further parsing.
    .EXAMPLE
    Get-DNSDebugLog -DNSLog ".\Something.log" | Format-Table
    Outputs the contents of the dns debug file "Something.log" as a table.
    .EXAMPLE
    Get-DNSDebugLog -DNSLog ".\Something.log" | Export-Csv .\ProperlyFormatedLog.csv -NoTypeInformation
    Turns the debug file into a csv-file.
    .PARAMETER DNSLog
    Mandatory. Path to the DNS log or DNS log data. Allows pipelining from for example Get-ChildItem for files, and supports pipelining DNS log data.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)]
        [String]$DNSLog
        )

    BEGIN
    {
        Write-Debug "BEGIN: Initializing settings"

        #stats
        $nTotalSuccess = 0      # No of lines of interest and saved with SUCCESS
        $nTotalFailed = 0       # No of lines of interest but FAILED to save
        $nTotalDiscarded = 0    # No of lines not of interest
        $nTotalEvaluated = 0    # No of lines looked at

      #
      # data sample from Windows Server 2012 R2, used for dnspattern below
      # 05/03/2019 16:05:31 0F9C PACKET  000000082A8141F0 UDP Snd 10.202.168.232  c1f8 R Q [8081   DR  NOERROR] A      (3)api(11)blahblah(3)com(0)
      #
       $dnspattern = "^(?<log_date>([0-9]{1,2}.[0-9]{1,2}.[0-9]{2,4}|[0-9]{2,4}-[0-9]{2}-[0-9]{2})\s*[0-9: ]{7,8}\s*(PM|AM)?) ([0-9A-Z]{3,4} PACKET\s*[0-9A-Za-z]{8,16}) (?<protocol>UDP|TCP) (?<way>Snd|Rcv) (?<ip>[0-9.]{7,15}|[0-9a-f:]{3,50})\s*([0-9a-z]{4}) (?<QR>.) (?<OpCode>.) \[.*\] (?<QueryType>.*) (?<query>\(.*)"
       $returnselect =  @{label="DateTime";expression={[datetime]::ParseExact($match.Groups['log_date'].value.trim(),"dd/MM/yyyy HH:mm:ss",$null)}},
                        @{label="Query/Response";expression={switch($match.Groups['QR'].value.trim()){"" {'Query'};"R" {'Response'}}}},
                        @{label="Client";expression={[ipaddress] ($match.Groups['ip'].value.trim()).trim()}},
                        @{label="SendReceive";expression={$match.Groups['way'].value.trim()}},
                        @{label="Protocol";expression={$match.Groups['protocol'].value.trim()}},
                        @{label="RecordType";expression={$match.Groups['QueryType'].value.trim()}},
                        @{label="Query";expression={$match.Groups['query'].value.trim() -replace "(`\(.*)","`$1" -replace "`\(.*?`\)","." -replace "^.",""}}

        Write-Debug "BEGIN: Initializing Settings - DONE"
    }

    PROCESS
    {
        Write-Debug "PROCESS: Starting to processing File: $DNSLog"

        getDNSLogLines -DNSLog $DNSLog | % {

            # Overall Total
            $nTotalEvaluated = $nTotalEvaluated + 1

            $match = [regex]::match($_,$dnspattern) #approach 2
            if ($match.success )
            {
                Try
                {
                    $true | Select-Object $returnselect
                    $nTotalSuccess = $nTotalSuccess + 1
                    # No of lines of interest and saved with SUCCESS
                } # end try
                Catch
                {
                    # Lines of Interest but FAILED to save
                    Write-Debug "Failed to process row: $_"
                    $nTotalFailed = $nTotalFailed + 1
                } #end catch
            } #end if($match.success )
            else
            {
                # No of lines not of interest
                $nTotalDiscarded = $nTotalDiscarded + 1
            } #end else

        } # end of getDNSLogLine

        Write-Debug "PROCESS: Finished Processing File: $DNSLog"

    } # end PROCESS

    END
    {
        # print summary
        Write-Debug "Summary"
        Write-Debug "Total lines in the file ($DNSLog): $nTotalEvaluated"
        Write-Debug "Records Processed with Success: $nTotalSuccess"
        Write-Debug "Records Processed with failure: $nTotalFailed"
        Write-Debug "Records discarded as not relevant: $nTotalDiscarded"
    }

}

function getDNSLogLines
{
    Param($DNSLog)

    # Don't bother if the file does not exist
    $PathCorrect=try { Test-Path $DNSLog -ErrorAction Stop } catch { $false }

    if ($DNSLog -match "^\d\d" -AND $DNSLog -notlike "*EVENT*" -AND $PathCorrect -ne $true)
    {
        $DNSLog
    }
    elseif ($PathCorrect -eq $true)
    {
        Get-Content $DNSLog | % { $_ }
    }
}
