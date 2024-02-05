# PowerShell script to block the IP addresses from which attempts are made to brute-force passwords through an RDP connection
# Full script description in the post: https://woshub.com/block-rdp-brute-force-powershell-firewall-rules/

# The number of failed login attempts from an IP address, after which the IP is blocked.
$badAttempts = 5
# Check the number of failed RDP logon events for the last N hours.
$intervalHours = 2
# Create a new Windows Firewall rule if the previous blocking rule contains more than N  unique IP addresses
$ruleMaxEntries = 2000
# Port number on which the RDP service is listening
$RdpLocalPort=3389
# Log file
$log = "c:\ps\rdp_block.log"
# A list of trusted IP addresses from which RDP connections should never be blocked
$trustedIPs = @("192.168.100.21","8.8.4.4")  
 $startTime = [DateTime]::Now.AddHours(-$intervalHours)
$badRDPlogons = Get-EventLog -LogName 'Security' -After $startTime -InstanceId 4625 |
    Where-Object { $_.Message -match 'logon type:\s+(3)\s' } |
    Select-Object @{n='IpAddress';e={$_.ReplacementStrings[-2]}}
$ipsArray = $badRDPlogons |
    Group-Object -Property IpAddress |
    Where-Object { $_.Count -ge $badAttempts } |
    ForEach-Object { $_.Name }
# Remove trusted IP addresses from the list
$ipsArray = $ipsArray | Where-Object { $_ -notin $trustedIPs }
if ($ipsArray.Count -eq 0) {
    return
}
[System.Collections.ArrayList]$ips = @()
[System.Collections.ArrayList]$current_ip_lists = @()
$ips.AddRange([string[]]$ipsArray)
$ruleCount = 1
$ruleName = "BlockRDPBruteForce" + $ruleCount
$foundRuleWithSpace = 0
while ($foundRuleWithSpace -eq 0) {
    $firewallRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    if ($null -eq $firewallRule) {
  New-NetFirewallRule -DisplayName $ruleName –RemoteAddress 1.1.1.1 -Direction Inbound -Protocol TCP –LocalPort $RdpLocalPort -Action Block
        $firewallRule = Get-NetFirewallRule -DisplayName $ruleName
        $current_ip_lists.Add(@(($firewallRule | Get-NetFirewallAddressFilter).RemoteAddress))
        $foundRuleWithSpace = 1
    } else {
        $current_ip_lists.Add(@(($firewallRule | Get-NetFirewallAddressFilter).RemoteAddress))        
        if ($current_ip_lists[$current_ip_lists.Count – 1].Count -le ($ruleMaxEntries – $ips.Count)) {
            $foundRuleWithSpace = 1
        } else {
            $ruleCount++
            $ruleName = "BlockRDPBruteForce" + $ruleCount
        }
    }
}
# Remove IP addresses already in the blocking firewall rule 
for ($i = $ips.Count – 1; $i -ge 0; $i--) {
    foreach ($current_ip_list in $current_ip_lists) {
        if ($current_ip_list -contains $ips[$i]) {
            $ips.RemoveAt($i)
            break
        }
    }
}
if ($ips.Count -eq 0) {
    exit
}
# Block the IP address in Windows Firewall and log the action.
$current_ip_list = $current_ip_lists[$current_ip_lists.Count – 1]
foreach ($ip in $ips) {
    $current_ip_list += $ip
    (Get-Date).ToString().PadRight(22) + ' | ' + $ip.PadRight(15) + ' | The IP address has been blocked due to ' + ($badRDPlogons | Where-Object { $_.IpAddress -eq $ip }).Count + ' failed login attempts over ' + $intervalHours + ' hours' >> $log
}
Set-NetFirewallRule -DisplayName $ruleName -RemoteAddress $current_ip_list
