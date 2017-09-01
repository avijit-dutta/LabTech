<#
.SYNOPSIS
    This is a PowerShell Module for LabTech.
    labtechconsulting.com
    labtechsoftware.com
    msdn.microsoft.com/powershell


.DESCRIPTION
    This is a set of commandlets to interface with the LabTech Agent v10.5 and v11.

.NOTES
    Version:        1.3
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2

    Update Date: 6/7/2017
    Purpose/Change: Updates to address 32-bit vs. 64-bit operations.

    Update Date: 6/10/2017
    Purpose/Change: Updates for pipeline input, support for multiple servers
    
#>
    
if (-not ($PSVersionTable)) {Write-Warning 'PS1 Detected. PowerShell Version 2.0 or higher is required.';return}
if (-not ($PSVersionTable) -or $PSVersionTable.PSVersion.Major -lt 3 ) {Write-Verbose 'PS2 Detected. PowerShell Version 3.0 or higher may be required for full functionality'}
if ((Get-WmiObject -Class Win32_OperatingSystem -ErrorAction SilentlyContinue).OSArchitecture -eq '64-bit' -and [IntPtr]::Size -ne 8) {Write-Warning '32-bit Session detected on 64-bit OS. Must run in native environment.';return}

#Module Version
$ModuleVersion = "1.3"

#Ignore SSL errors
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
 
#region-[Functions]------------------------------------------------------------

Function Get-PLTServiceInfo{ 
<#
.SYNOPSIS
    This function will pull all of the registry data into an object.

.NOTES
    Version:        1.2
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
    Update Date: 8/24/2017
    Purpose/Change: Update to use Clear-Variable.
    
.LINK
    http://labtechconsulting.com
#> 
    [CmdletBinding()]
    Param ()
      
  Begin
  {
    Clear-Variable key,BasePath,exclude,Servers -EA 0 #Clearing Variables for use
    Write-Verbose "Starting Get-PLTServiceInfo"

    if ((Test-Path 'HKLM:\SOFTWARE\LabTech\Service') -eq $False){
        Write-Error "ERROR: Unable to find information on LTSvc. Make sure the agent is installed."
        Return
    }
    $exclude = "PSParentPath","PSChildName","PSDrive","PSProvider","PSPath"
  }#End Begin
  
  Process{
    Write-Verbose "Checking for LT Service registry keys."
    Try{
        $key = Get-ItemProperty HKLM:\SOFTWARE\LabTech\Service -ErrorAction Stop | Select * -exclude $exclude
        if (-not ($key|Get-Member|Where {$_.Name -match 'BasePath'})) {
                if (Test-Path HKLM:\SYSTEM\CurrentControlSet\Services\LTService) {
                        $BasePath = ((Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\LTService -ErrorAction Stop).ImagePath.Split('"')|Where {$_}|Select -First 1|Get-Item).DirectoryName
                    } Else {
                        $BasePath = "$env:windir\LTSVC" 
                    }
                    Add-Member -InputObject $key -MemberType NoteProperty -Name BasePath -Value $BasePath
        }
          $key.BasePath = [System.Environment]::ExpandEnvironmentVariables($key.BasePath)
        if (($key|Get-Member|Where {$_.Name -match 'Server Address'})) {
        $Servers = ($Key|Select-Object -Expand 'Server Address' -EA 0).Split('|')|Foreach {$_.Trim()}
        Add-Member -InputObject $key -MemberType NoteProperty -Name 'Server' -Value $Servers -Force
    }
    }#End Try
    
    Catch{
      Write-Error "ERROR: There was a problem reading the registry keys. $($Error[0])"
    }#End Catch
  }#End Process
  
  End{
    if ($?){
        $key
    }    
  }#End End
}#End Function Get-PLTServiceInfo

Function Get-PLTServiceSettings{ 
<#
.SYNOPSIS
    This function will pull the registry data from HKLM:\SOFTWARE\LabTech\Service\Settings into an object.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
.LINK
    http://labtechconsulting.com
#> 
    [CmdletBinding()]
    Param ()
      
  Begin{
    Write-Verbose "Verbose: Checking for registry keys."
    if ((Test-Path 'HKLM:\SOFTWARE\LabTech\Service\Settings') -eq $False){
        Write-Error "ERROR: Unable to find LTSvc settings. Make sure the agent is installed." -ErrorAction Stop
    }
    $exclude = "PSParentPath","PSChildName","PSDrive","PSProvider","PSPath"
  }#End Begin
  
  Process{
    Try{
        Get-ItemProperty HKLM:\SOFTWARE\LabTech\Service\Settings -ErrorAction Stop | Select * -exclude $exclude
    }#End Try
    
    Catch{
      Write-Error "ERROR: There was a problem reading the registry keys. $($Error[0])" -ErrorAction Stop
    }#End Catch
  }#End Process
  
  End{
    if ($?){
        $key
    }    
  }#End End
}#End Function Get-PLTServiceSettings

Function Restart-PLTService{
<#
.SYNOPSIS
    This function will restart the LabTech Services.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
.LINK
    http://labtechconsulting.com
#> 
  
    [CmdletBinding()]
    Param()
  
  Begin{
    if (-not (Get-Service 'LTService','LTSvcMon' -ErrorAction SilentlyContinue)) {
        Write-Error "ERROR: Services NOT Found" $($Error[0]) -ErrorAction Stop
    }
  }#End Begin
  
  Process{
    Try{
      Stop-PLTService
      Start-PLTService
    }#End Try
    
    Catch{
      Write-Error "ERROR: There was an error restarting the services. $($Error[0])" -ErrorAction Stop
    }#End Catch
  }#End Process
  
  End{
    If ($?){Write-Output "Services Restarted successfully."}
    Else {$Error[0]}
  }#End End
}#End Function Restart-PLTService

Function Stop-PLTService{
<#
.SYNOPSIS
    This function will stop the LabTech Services.

.DESCRIPTION
    This function will verify that the LabTech services are present then attempt to stop them.
    It will then check for any remaining LabTech processes and kill them.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
.LINK
    http://labtechconsulting.com
#>   
    [CmdletBinding()]
    Param()
  
  Begin{
    if (-not (Get-Service 'LTService','LTSvcMon' -ErrorAction SilentlyContinue)) {
        Write-Error "ERROR: Services NOT Found" $($Error[0]) -ErrorAction Stop
    }
  }#End Begin
  
  Process{
    Try{
        Stop-Service 'LTService','LTSvcMon' -ErrorAction SilentlyContinue
        Get-Process | Where-Object {@('LTTray','LTSVC','LTSvcMon') -contains $_.ProcessName } | Stop-Process -Force -ErrorAction Stop
    }#End Try
    
    Catch{
        Write-Error "ERROR: There was an error stopping the LabTech processes. $($Error[0])" -ErrorAction Stop
    }#End Catch
  }#End Process
  
  End{
    If ($?){
        Write-Output "Services Stopped successfully."
    }
    Else {$Error[0]}
  }#End End
}#End Function Stop-PLTService

Function Start-PLTService{
<#
.SYNOPSIS
    This function will start the LabTech Services.

.DESCRIPTION
    This function will verify that the LabTech services are present.
    It will then check for any process that is using the LTTray port (Default 42000) and kill it.
    Next it will start the services.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 5/11/2017
    Purpose/Change: added check for non standard port number and set services to auto start

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
        
.LINK
    http://labtechconsulting.com
#>
    
    [CmdletBinding()]
    Param()   
   
    Begin{
        if (-not (Get-Service 'LTService','LTSvcMon' -ErrorAction SilentlyContinue)) {
            Write-Error "ERROR: Services NOT Found" $($Error[0]) -ErrorAction Stop
        }
        #Kill all processes that are using the tray port 
        [array]$processes = @()
        $Port = (Get-PLTServiceInfo -EA 0|Select-Object -Expand TrayPort -EA 0)
    if (-not ($Port)) {$Port = "42000"}

    }#End Begin
  
    Process{
        Try{
          $netstat = netstat.exe -a -o -n | Select-String $Port -EA 0
          foreach ($line in $netstat){
              $processes += ($line -split '  {3,}')[-1]
          }
          $processes = $processes | Where-Object {$_ -gt 0 -and $_ -match '^\d+$'}| Sort-Object | Get-Unique
          if ($processes) {
          foreach ($proc in $processes){
                  Write-Output "Process ID:$proc is using port $Port. Killing process."
                  Stop-Process -ID $proc -Force -Verbose
          }
          }
          @('LTService','LTSvcMon') | ForEach-Object {
                      if (Get-Service $_ -EA 0) {Set-Service $_ -StartupType Automatic -EA 0; Start-Service $_ -EA 0}
          }
        }#End Try
    
        Catch{
            Write-Error "ERROR: There was an error starting the LabTech services. $($Error[0])" -ErrorAction Stop
        }#End Catch
    }#End Process
  
    End
    {
        If ($?){
            Write-Output "Services Started successfully."
        }
        else{
             $($Error[0])
        }
    }#End End
}#End Function Start-PLTService

Function Uninstall-PLTService{
<#
.SYNOPSIS
    This function will uninstall the LabTech agent from the machine.

.DESCRIPTION
    This function will stop all the LabTech services. It will then download the current agent install MSI and issue an uninstall command.
    It will then download and run Agent_Uninstall.exe from the LabTech server. It will then scrub any remaining file/registry/service data.

.PARAMETER Server
    This is the URL to your LabTech server. 
    Example: https://lt.domain.com
    This is used to download the uninstall utilities.
    If no server is provided the uninstaller will use Get-PLTServiceInfo to get the server address.

.PARAMETER Backup
    This will run a 'New-PLTServiceBackup' before uninstalling.

.EXAMPLE
    Uninstall-PLTService
    This will uninstall the LabTech agent using the server address in the registry.

.EXAMPLE
    Uninstall-PLTService -Server 'https://lt.domain.com'
    This will uninstall the LabTech agent using the provided server URL to download the uninstallers.

.NOTES
    Version:        1.4
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
    Update Date: 6/10/2017
    Purpose/Change: Updates for pipeline input, support for multiple servers
    
    Update Date: 6/24/2017
    Purpose/Change: Update to detect Server Version and use updated URL format for LabTech 11 Patch 13.
    
    Update Date: 8/24/2017
    Purpose/Change: Update to use Clear-Variable. Modifications to Folder and Registry Delete steps. Additional Debugging.

    Update Date: 8/31/2017
    Purpose/Change: Removed additional Folder and Registry Delete steps, which is creating memory overFlow issue.
    
.LINK
    http://labtechconsulting.com
#> 
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string[]]$Server,
        [switch]$Backup = $False
    )   
    Begin{
        Clear-Variable Executables,BasePath,reg,regs,installer,installerTest,installerResult,uninstaller,uninstallerTest,uninstallerResult,xarg,Svr,SVer,SvrVer,SvrVerCheck,GoodServer,Item -EA 0 #Clearing Variables for use
        If (-not ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544"))) {
            Throw "Needs to be ran as Administrator" 
        }
        if ($Backup){
            New-PLTServiceBackup
        }

        $BasePath = $(Get-PLTServiceInfo -EA 0|Select-Object -Expand BasePath -EA 0)
        if (-not ($BasePath)){$BasePath = "$env:windir\LTSVC"}

        New-PSDrive HKU Registry HKEY_USERS -ErrorAction SilentlyContinue | Out-Null
        $regs = @( 'Registry::HKEY_LOCAL_MACHINE\Software\LabTechMSP',
          'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\LabTech\Service',
          'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\LabTech\LabVNC',
          'Registry::HKEY_LOCAL_MACHINE\Software\Wow6432Node\LabTech\Service',
          'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC',
          'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC',
          'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\Managed\\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F',
          'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\D1003A85576B76D45A1AF09A0FC87FAC\InstallProperties',
          'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{58A3001D-B675-4D67-A5A1-0FA9F08CF7CA}',
          'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{3426921d-9ad5-4237-9145-f15dee7e3004}',
          'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Appmgmt\{40bf8c82-ed0d-4f66-b73e-58a3d7ab6582}',
          'Registry::HKEY_CLASSES_ROOT\Installer\Dependencies\{3426921d-9ad5-4237-9145-f15dee7e3004}',
          'Registry::HKEY_CLASSES_ROOT\Installer\Dependencies\{3F460D4C-D217-46B4-80B6-B5ED50BD7CF5}',
          'Registry::HKEY_CLASSES_ROOT\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F',
          'Registry::HKEY_CLASSES_ROOT\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC',
          'Registry::HKEY_CLASSES_ROOT\CLSID\{09DF1DCA-C076-498A-8370-AD6F878B6C6A}',
          'Registry::HKEY_CLASSES_ROOT\CLSID\{15DD3BF6-5A11-4407-8399-A19AC10C65D0}',
          'Registry::HKEY_CLASSES_ROOT\CLSID\{3C198C98-0E27-40E4-972C-FDC656EC30D7}',
          'Registry::HKEY_CLASSES_ROOT\CLSID\{459C65ED-AA9C-4CF1-9A24-7685505F919A}',
          'Registry::HKEY_CLASSES_ROOT\CLSID\{7BE3886B-0C12-4D87-AC0B-09A5CE4E6BD6}',
          'Registry::HKEY_CLASSES_ROOT\CLSID\{7E092B5C-795B-46BC-886A-DFFBBBC9A117}',
          'Registry::HKEY_CLASSES_ROOT\CLSID\{9D101D9C-18CC-4E78-8D78-389E48478FCA}',
          'Registry::HKEY_CLASSES_ROOT\CLSID\{B0B8CDD6-8AAA-4426-82E9-9455140124A1}',
          'Registry::HKEY_CLASSES_ROOT\CLSID\{B1B00A43-7A54-4A0F-B35D-B4334811FAA4}',
          'Registry::HKEY_CLASSES_ROOT\CLSID\{BBC521C8-2792-43FE-9C91-CCA7E8ACBCC9}',
          'Registry::HKEY_CLASSES_ROOT\CLSID\{C59A1D54-8CD7-4795-AEDD-F6F6E2DE1FE7}',
          'Registry::HKEY_CLASSES_ROOT\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F',
          'Registry::HKEY_CLASSES_ROOT\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC',
          'Registry::HKEY_CURRENT_USER\SOFTWARE\LabTech\Service',
          'Registry::HKEY_CURRENT_USER\SOFTWARE\LabTech\LabVNC',
          'Registry::HKEY_CURRENT_USER\Software\Microsoft\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F',
          'HKU:\*\Software\Microsoft\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F'
        )

        #Cleanup previous uninstallers
        Remove-Item 'Uninstall.exe','Uninstall.exe.config' -ErrorAction SilentlyContinue

        New-Item $env:windir\temp\LabTech\Installer -type directory -ErrorAction SilentlyContinue | Out-Null

        $xarg = "/x $installer /qn"
    }#End Begin
  
    Process{
        if (-not ($Server)){
          $Server = Get-PLTServiceInfo -ErrorAction SilentlyContinue|Select-Object -Expand 'Server' -EA 0
        }
        if (-not ($Server)){
            $Server = Read-Host -Prompt 'Provide the URL to your LabTech server (https://lt.domain.com):'
        }
        Foreach ($Svr in $Server) {
        if (-not ($GoodServer)) {
                if ($Svr -match '^(https?://)?(([12]?[0-9]{1,2}\.){3}[12]?[0-9]{1,2}|[a-z0-9][a-z0-9_-]*(\.[a-z0-9][a-z0-9_-]*){1,})$') {
                    Try{
                        if ($Svr -notlike 'http*://*') {$Svr = "http://$($Svr)"}
                        $SvrVerCheck = "$($Svr)/Labtech/Agent.aspx"
                        Write-Debug "Testing Server Response and Version: $SvrVerCheck"
                        $SvrVer = $(New-Object Net.WebClient).DownloadString($SvrVerCheck)
                        Write-Debug "Raw Response: $SvrVer"
                        if ($SvrVer -NotMatch '(?<=[|]{6})[0-9]{3}\.[0-9]{3}') {
                            Write-Verbose "Unable to test version response from $($Svr)."
                            Continue
                        }
                        $SVer = $SvrVer|select-string -pattern '(?<=[|]{6})[0-9]{3}\.[0-9]{3}'|foreach {$_.matches}|select -Expand value
                        if ([System.Version]$SVer -ge [System.Version]'110.374') {
                            #New Style Download Link starting with LT11 Patch 13 - Direct Location Targeting is no longer available
                            $installer = "$($Svr)/Labtech/Deployment.aspx?Probe=1&installType=msi&MSILocations=1"
                        } else {
                            #Original Generic Installer URL - Yes, these both reference Location 1 and are thus the same. Will it change in Patch 14? This section is now ready.
                            $installer = "$($Svr)/Labtech/Deployment.aspx?Probe=1&installType=msi&MSILocations=1"
                        }
                        $installerTest = [System.Net.WebRequest]::Create($installer)
                        $installerTest.KeepAlive=$False
                        $installerTest.ProtocolVersion = '1.0'
                        $installerResult = $installerTest.GetResponse()
                        $installerTest.Abort()
                        if ($installerResult.StatusCode -ne 200) {
                            Write-Warning "Unable to download Agent_Install.msi from server $($Svr)."
                            Continue
                        }
                        else{
                            Write-Debug "Downloading Agent_Install.msi from $installer"
                            $(New-Object Net.WebClient).DownloadFile($installer,"$env:windir\temp\LabTech\Installer\Agent_Install.msi")
                        }

                        #Using $SVer results gathered above.
                        if ([System.Version]$SVer -ge [System.Version]'110.374') {
                            #New Style Download Link starting with LT11 Patch 13 - The Agent Uninstaller URI has changed.
                            $uninstaller = "$($Svr)/Labtech/Deployment.aspx?ID=-2"
                        } else {
                            #Original Uninstaller URL
                            $uninstaller = "$($Svr)/Labtech/Deployment.aspx?probe=1&ID=-2"
                        }
                        $uninstallerTest = [System.Net.WebRequest]::Create($uninstaller)
                        $uninstallerTest.KeepAlive=$False
                        $uninstallerTest.ProtocolVersion = '1.0'
                        $uninstallerResult = $uninstallerTest.GetResponse()
                        $uninstallerTest.Abort()
                        if ($uninstallerResult.StatusCode -ne 200) {
                            Write-Warning "Unable to download Agent_Uninstall from server."
                            Continue
                        }
                        else{
                            Write-Debug "Downloading Agent_Uninstall.exe from $uninstaller"
                            #Download Agent_Uninstall.exe
                            $(New-Object Net.WebClient).DownloadFile($uninstaller,"$($env:windir)\temp\Agent_Uninstall.exe")
                        }
                        If ((Test-Path "$env:windir\temp\LabTech\Installer\Agent_Install.msi") -and (Test-Path "$($env:windir)\temp\Agent_Uninstall.exe")) {
                            $GoodServer = $Svr
                            Write-Verbose "Successfully downloaded files from $($Svr)."
                        } else {
                            Write-Warning "Error encountered downloading from $($Svr). Uninstall file(s) could be received."
                            Continue
                        }
                    }
                    Catch {
                        Write-Warning "Error encountered downloading from $($Svr)."
                        Continue
                    }
                } else {
                    Write-Verbose "Server address $($Svr) is not formatted correctly. Example: https://lt.domain.com"
                }
            } else {
                Write-Debug "Server $($GoodServer) has been selected."
                Write-Verbose "Server has already been selected - Skipping $($Svr)."
            }
        }#End Foreach
    }#End Process
  
    End{
        if ($GoodServer) {
            Try{
                Write-Output "Starting Uninstall."

                #Kill all running processes from %ltsvcdir%   
                if (Test-Path $BasePath){
                    $Executables = (Get-ChildItem $BasePath -Filter *.exe -Recurse -ErrorAction SilentlyContinue|Select -Expand Name|Foreach {$_.Trim('.exe')})
                    if ($Executables) {
                    ForEach($Item in $Executables){
                            Stop-Process -Name $Item -Force -ErrorAction SilentlyContinue
                        }
                    }

                    #Unregister DLL
                    regsvr32.exe /u $BasePath\wodVPN.dll /s 2>''
                }     
            
                #Run MSI uninstaller for current installer
                Start-Process -Wait -FilePath msiexec.exe -ArgumentList $xarg
                Start-Sleep -Seconds 5

                #Run Agent_Uninstall.exe
                Start-Process -Wait -FilePath "$($env:windir)\temp\Agent_Uninstall.exe"
                Start-Sleep -Seconds 5

                #Remove %ltsvcdir% - Depth First Removal, First by purging files, then Removing Folders, to get as much removed as possible if complete removal fails
                #@($BasePath, "$env:windir\temp\_ltudpate") | foreach-object {
                #    Get-ChildItem -Path $_ -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not ($_.psiscontainer) }  | Sort-Object { $_.name.length } -Descending | Remove-Item -Force -ErrorAction SilentlyContinue 
               #     Get-ChildItem -Path $_ -Recurse -Force -ErrorAction SilentlyContinue | Sort-Object { $_.name.length } -Descending | Remove-Item -Force -ErrorAction SilentlyContinue -Recurse
               #     Remove-Item -Recurse -Force -Path $_ -ErrorAction SilentlyContinue
               #     Write-Debug "Removing Item: $($_)"
               # }

               # #Remove all registry keys - Depth First Value Removal, then Key Removal, to get as much removed as possible if complete removal fails
                #foreach ($reg in $regs) {
                 #   Get-ChildItem -Path $reg -Recurse -Force -ErrorAction SilentlyContinue | Sort-Object { $_.name.length } -Descending | Remove-Item -Force -ErrorAction SilentlyContinue -Recurse
                  #  Remove-Item -Recurse -Force -Path $reg -ErrorAction SilentlyContinue
                   # Write-Debug "Removing Item: $($reg)"
                #}

                #Remove Services
               # @('LTService','LTSvcMon') | ForEach-Object {
               #     if (Get-Service $_ -ea 0) {Start-Process -FilePath sc.exe -ArgumentList "delete $_" -Wait}
               #     Write-Debug "Removing Service: $($_)"
               # }

                #Post Uninstall Check
                if((Test-Path $env:windir\ltsvc) -or (Test-Path $env:windir\temp\_ltudpate) -or (Test-Path registry::HKLM\Software\LabTech\Service) -or (Test-Path registry::HKLM\Software\WOW6432Node\Labtech\Service)){
                    Start-Sleep -Seconds 10
                }
                if((Test-Path $env:windir\ltsvc) -or (Test-Path $env:windir\temp\_ltudpate) -or (Test-Path registry::HKLM\Software\LabTech\Service) -or (Test-Path registry::HKLM\Software\WOW6432Node\Labtech\Service)){
                    Write-Error "Remnants of previous install still detected after uninstall attempt. Please reboot and try again."
                }

            }#End Try
    
            Catch{
                Write-Error "ERROR: There was an error during the uninstall process. $($Error[0])" -ErrorAction Stop
            }#End Catch
            If ($?){
                Write-Output "LabTech has been successfully uninstalled."
            }
            else {
                $($Error[0])
            }
        } else {
            Write-Error "ERROR: No valid server was reached to use for the uninstall." -ErrorAction Stop
        }#End If
    }#End End
}#End Function Uninstall-PLTService

Function Install-PLTService{
<#
.SYNOPSIS
    This function will install the LabTech agent on the machine.

.DESCRIPTION
    This function will install the LabTech agent on the machine with the specified server/password/location.

.PARAMETER Server
    This is the URL to your LabTech server. 
    example: https://lt.domain.com
    This is used to download the installation files.
    (Get-PLTServiceInfo|Select-Object -Expand 'Server Address' -ErrorAction SilentlyContinue)

.PARAMETER Password
    This is the server password that agents use to authenticate with the LabTech server.
    (Get-PLTServiceInfo).ServerPassword

.PARAMETER LocationID
    This is the LocationID of the location that the agent will be put into.
    (Get-PLTServiceInfo).LocationID

.PARAMETER Rename
    This will call Rename-PLTAddRemove after the install.

.PARAMETER Hide
    This will call Hide-PLTAddRemove after the install.

.EXAMPLE
    Install-PLTService -Server https://lt.domain.com -Password sQWZzEDYKFFnTT0yP56vgA== -LocationID 42
    This will install the LabTech agent using the provided Server URL, Password, and LocationID.

.NOTES
    Version:        1.4
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
    Update Date: 6/10/2017
    Purpose/Change: Updates for pipeline input, support for multiple servers
    
    Update Date: 6/24/2017
    Purpose/Change: Update to detect Server Version and use updated URL format for LabTech 11 Patch 13.

    Update Date: 8/24/2017
    Purpose/Change: Update to use Clear-Variable. Additional Debugging.
    
.LINK
    http://labtechconsulting.com
#> 
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory=$True)]
        [string[]]$Server,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias("Password")]
        [string]$ServerPassword,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [int]$LocationID,
        [string]$Rename = $null,
        [switch]$Hide = $False
    )

    Begin{
        Clear-Variable DotNET,OSVersion,PasswordArg,Result,logpath,logfile,curlog,installer,installerTest,installerResult,GoodServer,Svr,SVer,SvrVer,SvrVerCheck,iarg,timeout,sw,tmpLTSI -EA 0 #Clearing Variables for use

        if (Get-Service 'LTService','LTSvcMon' -ErrorAction SilentlyContinue) {
            Write-Error "LabTech is already installed." -ErrorAction Stop
        }

        If (-not ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544"))) {
            Write-Error "Needs to be ran as Administrator" -ErrorAction Stop
        }
        
        $DotNET = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -recurse -EA 0 | Get-ItemProperty -name Version,Release -EA 0 | Where-Object { $_.PSChildName -match '^(?!S)\p{L}'} | Select-Object -ExpandProperty Version -EA 0
        if (-not ($DotNet -like '3.5.*'))
        {
            Write-Output ".NET 3.5 installation needed."
            #Install-WindowsFeature Net-Framework-Core
            $OSVersion = [Version](Get-CimInstance Win32_OperatingSystem).version

            if ($OSVersion -gt 6.2){
                try{
                    Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -All | Out-Null
                }
                catch{
                    Write-Error "ERROR: .NET 3.5 install failed." -ErrorAction Continue
                    Write-Error $Result -ErrorAction Stop
                }
            }
            else{
                $Result = Dism.exe /online /get-featureinfo /featurename:NetFx3 2>''
                If ($Result -contains "State : Enabled"){ 

                    Write-Warning ".Net Framework 3.5 has been installed and enabled." 
                } 
                Else{
                    Write-Error "ERROR: .NET 3.5 install failed. $Result" -ErrorAction Stop
                } 
            }
            
            $DotNET = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -recurse | Get-ItemProperty -name Version,Release -EA 0 | Where-Object{ $_.PSChildName -match '^(?!S)\p{L}'} | Select -ExpandProperty Version
        }

        if (-not ($DotNet -like '3.5.*')){
            Write-Error "ERROR: .NET 3.5 is not detected and could not be installed." -ErrorAction Stop
        }
        if (-not ($LocationID)){
            $LocationID = "1"
        }

        $logpath = [System.Environment]::ExpandEnvironmentVariables("%windir%\temp\LabTech")
        $logfile = "LTAgentInstall"
        $curlog = "$($logpath)\$($logfile).log"
        if (-not (Test-Path -PathType Container -Path "$logpath\Installer" )){
            New-Item "$logpath\Installer" -type directory -ErrorAction SilentlyContinue | Out-Null
        }#End if
        if ((Test-Path -PathType Leaf -Path $($curlog))){
            $curlog = Get-Item -Path $curlog
            Rename-Item -Path $($curlog.FullName) -NewName "$($logfile)-$(Get-Date $($curlog.LastWriteTime) -Format 'yyyyMMddHHmmss').log" -Force
        }#End if

    }#End Begin
  
    Process{
        Foreach ($Svr in $Server) {
        if (-not ($GoodServer)) {
                if ($Svr -match '^(https?://)?(([12]?[0-9]{1,2}\.){3}[12]?[0-9]{1,2}|[a-z0-9][a-z0-9_-]*(\.[a-z0-9][a-z0-9_-]*){1,})$') {
                    if ($Svr -notlike 'http*://*') {$Svr = "http://$($Svr)"}
                    Try {
                        $SvrVerCheck = "$($Svr)/Labtech/Agent.aspx"
                        Write-Debug "Testing Server Response and Version: $SvrVerCheck"
                        $SvrVer = $(New-Object Net.WebClient).DownloadString($SvrVerCheck)
                        Write-Debug "Raw Response: $SvrVer"
                        if ($SvrVer -NotMatch '(?<=[|]{6})[0-9]{3}\.[0-9]{3}') {
                            Write-Verbose "Unable to test version response from $($Svr)."
                            Continue
                        }
                        $SVer = $SvrVer|select-string -pattern '(?<=[|]{6})[0-9]{3}\.[0-9]{3}'|foreach {$_.matches}|select -Expand value
                        if ([System.Version]$SVer -ge [System.Version]'110.374') {
                            #New Style Download Link starting with LT11 Patch 13 - Direct Location Targeting is no longer available
                            $installer = "$($Svr)/Labtech/Deployment.aspx?Probe=1&installType=msi&MSILocations=1"
                        } else {
                            #Original URL
                            $installer = "$($Svr)/Labtech/Deployment.aspx?Probe=1&installType=msi&MSILocations=$LocationID"
                        }
                        $installerTest = [System.Net.WebRequest]::Create($installer)
                        $installerTest.KeepAlive=$False
                        $installerTest.ProtocolVersion = '1.0'
                        $installerResult = $installerTest.GetResponse()
                        $installerTest.Abort()
                        if ($installerResult.StatusCode -ne 200) {
                            Write-Warning "Unable to download Agent_Install from server $($Svr)."
                            Continue
                        } else {
                            Write-Debug "Downloading Agent_Install.msi from $installer"
                            $(New-Object Net.WebClient).DownloadFile($installer,"$env:windir\temp\LabTech\Installer\Agent_Install.msi")
                        }
                        If (Test-Path "$env:windir\temp\LabTech\Installer\Agent_Install.msi") {
                            $GoodServer = $Svr
                            Write-Verbose "Agent_Install.msi downloaded successfully from server $($Svr)."
                        } else {
                            Write-Warning "Error encountered downloading from $($Svr). No installation file was received."
                            Continue
                        }
                    }
                    Catch {
                        Write-Warning "Error encountered downloading from $($Svr)."
                        Continue
                    }
                } else {
                    Write-Warning "Server address $($Svr) is not formatted correctly. Example: https://lt.domain.com"
                }
            } else {
                Write-Debug "Server $($GoodServer) has been selected."
                Write-Verbose "Server has already been selected - Skipping $($Svr)."
            }
        }#End Foreach
    }#End Process
  
    End{
        if (($ServerPassword)){
            $PasswordArg = "SERVERPASS=$ServerPassword"
        }
        if ($GoodServer) {
            if((Test-Path $env:windir\ltsvc) -or (Test-Path $env:windir\temp\_ltudpate) -or (Test-Path registry::HKLM\Software\LabTech\Service) -or (Test-Path registry::HKLM\Software\WOW6432Node\Labtech\Service)){
                Write-Warning "Previous install detected. Calling Uninstall-PLTService"
                Uninstall-PLTService -Server $GoodServer
            }

            Write-Output "Starting Install."
            $iarg = "/i  $env:windir\temp\LabTech\Installer\Agent_Install.msi SERVERADDRESS=$GoodServer $PasswordArg LOCATION=$LocationID /qn /l $logpath\$logfile.log"

            Try{
                Write-Verbose "Launching Installation Process: msiexec.exe $($iarg)"
                Start-Process -Wait -FilePath msiexec.exe -ArgumentList $iarg
                $timeout = new-timespan -Minutes 3
                $sw = [diagnostics.stopwatch]::StartNew()
                Write-Host -NoNewline "Waiting for agent to register." 
                Do {
                    Write-Host -NoNewline '.'
                    Start-Sleep 2
                    $tmpLTSI = (Get-PLTServiceInfo -EA 0 -Verbose:$False | Select-Object -Expand 'ID' -EA 0)
                } until ($sw.elapsed -gt $timeout -or $tmpLTSI -gt 1)
                $sw.Stop()
                Write-Verbose "Completed wait for LabTech Installation after $($sw.Elapsed.Seconds.ToString()) seconds."
                If ($Hide) {Hide-PLTAddRemove}
            }#End Try

            Catch{
                Write-Error "ERROR: There was an error during the install process. $($Error[0])" -ErrorAction Stop
            }#End Catch

            $tmpLTSI = Get-PLTServiceInfo -EA 0
            if (($tmpLTSI)) {
                if (($tmpLTSI|Select-Object -Expand 'ID' -EA 0) -gt 1) {
                    Write-Host ""
                    Write-Output "LabTech has been installed successfully. Agent ID: $($tmpLTSI|Select-Object -Expand 'ID' -EA 0) LocationID: $($tmpLTSI|Select-Object -Expand 'LocationID' -EA 0)"
                    if (($Rename) -and $Rename -notmatch 'False'){
                        Rename-PLTAddRemove -Name $Rename
                    }
                }
            }
            else {
                if (($Error)) {
                    Write-Error "ERROR: There was an error installing LabTech. Check the log, $($env:windir)\temp\LabTech\LTAgentInstall.log $($Error[0])" -ErrorAction Stop
                } else {
                    Write-Error "ERROR: There was an error installing LabTech. Check the log, $($env:windir)\temp\LabTech\LTAgentInstall.log" -ErrorAction Stop
                }
            }
        } else {
            Write-Error "ERROR: No valid server was reached to use for the install." -ErrorAction Stop
        }
    }#End End
}#End Function Install-PLTService

Function ReInstall-PLTService{
<#
.SYNOPSIS
    This function will reinstall the LabTech agent from the machine.

.DESCRIPTION
    This script will attempt to pull all current settings from machine and issue an 'Uninstall-PLTService', 'Install-PLTService' with gathered information. 
    If the function is unable to find the settings it will ask for needed parameters. 

.PARAMETER Server
    This is the URL to your LabTech server. 
    Example: https://lt.domain.com
    This is used to download the installation and removal utilities.
    If no server is provided the uninstaller will use Get-PLTServiceInfo to get the server address.
    If it is unable to find LT currently installed it will try Get-PLTServiceInfoBackup

.PARAMETER Password
    This is the Server Password to your LabTech server. 
    example: sRWyzEF0KaFzHTnyP56vgA==
    You can find this from a configured agent with, '(Get-PLTServiceInfo).ServerPassword'
    
.PARAMETER LocationID
    The LocationID of the location that you want the agent in
    example: 555

.PARAMETER Backup
    This will run a New-PLTServiceBackup command before uninstalling.

.PARAMETER Hide
    Will remove from add-remove programs

.PARAMETER Rename
    This will call Rename-PLTAddRemove to rename the install in Add/Remove Programs

.EXAMPLE
    ReInstall-PLTService 
    This will ReInstall the LabTech agent using the server address in the registry.

.EXAMPLE
    ReInstall-PLTService -Server https://lt.domain.com -Password sQWZzEDYKFFnTT0yP56vgA== -LocationID 42
    This will ReInstall the LabTech agent using the provided server URL to download the installation files.

.NOTES
    Version:        1.4
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
    Update Date: 6/8/2017
    Purpose/Change: Update to support user provided settings for -Server, -Password, -LocationID.
    
    Update Date: 6/10/2017
    Purpose/Change: Updates for pipeline input, support for multiple servers
    
    Update Date: 8/24/2017
    Purpose/Change: Update to use Clear-Variable.
    
.LINK
    http://labtechconsulting.com
#> 
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipelineByPropertyName = $true, ValueFromPipeline=$True)]
        [string[]]$Server,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias("Password")]
        [string]$ServerPassword,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$LocationID,
        [switch]$Backup = $False,
        [switch]$Hide = $False,
        [string]$Rename = $null
    )
           
    Begin{
        Clear-Variable PasswordArg, RenameArg, Svr, ServerList, Settings -EA 0 #Clearing Variables for use
        # Gather install stats from registry or backed up settings
        $Settings = Get-PLTServiceInfo -ErrorAction SilentlyContinue
        if (-not ($Settings)){
            $Settings = Get-PLTServiceInfoBackup -ErrorAction SilentlyContinue
        }
        $ServerList=@()
    }#End Begin
  
    Process{
        if (-not ($Server)){
            if ($Settings){
              $Server = $Settings|Select-object -Expand 'Server' -EA 0
            }
            if (-not ($Server)){
                $Server = Read-Host -Prompt 'Provide the URL to your LabTech server (https://lt.domain.com):'
            }
        }
        if (-not ($LocationID)){
            if ($Settings){
                $LocationID = $Settings|Select-object -Expand LocationID -EA 0
            }
            if (-not ($LocationID)){
                $LocationID = Read-Host -Prompt 'Provide the LocationID'
            }
        }
        if (-not ($LocationID)){
            $LocationID = "1"
        }
        $ServerList += $Server
    }#End Process
  
    End{
        if ($Backup){
            New-PLTServiceBackup
        }

        $RenameArg=''
        if ($Rename){
            $RenameArg = "-Rename $Rename"
        }

        if (($ServerPassword)){
            $PasswordArg = "-Password '$ServerPassword'"
        }

        Write-Host "Reinstalling LabTech with the following information, -Server $($ServerList -join ',') $PasswordArg -LocationID $LocationID $RenameArg"
        Write-Verbose "Starting: Uninstall-PLTService -Server $($ServerList -join ',')"
        Try{
            Uninstall-PLTService -Server $serverlist -ErrorAction Stop
        }#End Try
    
        Catch{
            Write-Error "ERROR: There was an error during the reinstall process while uninstalling. $($Error[0])" -ErrorAction Stop
        }#End Catch

        Start-Sleep 10
        Write-Verbose "Starting: Install-PLTService -Server $($ServerList -join ',') $PasswordArg -LocationID $LocationID -Hide:$Hide $RenameArg"
        #Write-Verbose "Starting: Install-PLTService -Server $ServerList -LocationID $LocationID"
        
        Try{
            Install-PLTService -Server $ServerList $ServerPassword -LocationID $LocationID -Hide:$Hide $Rename
            #Install-PLTService -Server $ServerList -LocationID $LocationID
        }#End Try
    
        Catch{
            Write-Error "ERROR: There was an error during the reinstall process while installing. $($Error[0])" -ErrorAction Stop
        }#End Catch

        If ($?){
            Return
        }
        else {
            $($Error[0])
        }
    }#End End
}#End Function ReInstall-PLTService

Function Get-PLTError{
<#
.SYNOPSIS
    This will pull the %ltsvcdir%\LTErrors.txt file into an object.

.EXAMPLE
    Get-PLTError | where {(Get-date $_.Time) -gt (get-date).AddHours(-24)}
    Get a list of all errors in the last 24hr

.EXAMPLE
    Get-PLTError | Out-Gridview
    Open the log file in a sortable searchable window.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
.LINK
    http://labtechconsulting.com
#> 

    [CmdletBinding()]
    Param()
    
    Begin{
        $BasePath = $(Get-PLTServiceInfo -ErrorAction SilentlyContinue).BasePath
        if (!$BasePath){$BasePath = "$env:windir\LTSVC"}
        if ($(Test-Path -Path $BasePath\LTErrors.txt) -eq $False) {
            Write-Error "ERROR: Unable to find log." $($Error[0]) -ErrorAction Stop
        }
    }#End Begin
  
    Process{
        Try{
            $errors = Get-Content "$BasePath\LTErrors.txt"
            $errors = $errors -join ' ' -split ':::'
            foreach($Line in $Errors){
                $items = $Line -split "`t" -replace ' - ',''
                if ($items[1]){
                    $object = New-Object -TypeName PSObject
                    $object | Add-Member -MemberType NoteProperty -Name ServiceVersion -Value $items[0]
                    $object | Add-Member -MemberType NoteProperty -Name Timestamp -Value $([datetime]$items[1])
                    $object | Add-Member -MemberType NoteProperty -Name Message -Value $items[2]
                    Write-Output $object
                }
            }
            
        }#End Try
    
        Catch{
            Write-Error "ERROR: There was an error reading the log. $($Error[0])" -ErrorAction Stop
        }#End Catch
    }#End Process
  
    End{
        if ($?){
        }
        Else {$Error[0]}
        
    }#End End
}#End Function Get-PLTError


Function Reset-PLTService{
<#
.SYNOPSIS
    This function will remove local settings on the agent.

.DESCRIPTION
    This function can remove some of the agents local settings.
    ID, MAC, LocationID
    The function will stop the services, make the change, then start the services.
    Resetting all of these will force the agent to check in as a new agent.
    If you have MAC filtering enabled it should check back in with the same ID.
    This function is useful for duplicate agents.

.PARAMETER ID
    This will reset the AgentID of the computer

.PARAMETER Location
    This will reset the LocationID of the computer

.PARAMETER MAC
    This will reset the MAC of the computer

.EXAMPLE
    Reset-PLTService
    This resets the ID, MAC and LocationID on the agent. 

.EXAMPLE
    Reset-PLTService -ID
    This resets only the ID of the agent.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
.LINK
    http://labtechconsulting.com
#> 

    [CmdletBinding()]
    Param(
        [switch]$ID,
        [switch]$Location,
        [switch]$MAC        
    )   
    
    Begin{
        if (!(Get-Service 'LTService','LTSvcMon' -ErrorAction SilentlyContinue)) {
            Write-Error "ERROR: LabTech Services NOT Found" $($Error[0]) -ErrorAction Stop
        }
        $Reg = 'HKLM:\Software\LabTech\Service'
        if (!($ID -or $LocationID -or $MAC)){
            $ID=$true
            $Location=$true
            $MAC=$true
        }
        Write-Output "OLD ID: $((Get-PLTServiceInfo).ID) LocationID: $((Get-PLTServiceInfo).LocationID) MAC: $((Get-PLTServiceInfo).MAC)"
        
    }#End Begin
  
    Process{
        Try{
            Stop-PLTService
            if ($ID) {
                Write-Output ".Removing ID"
                Remove-ItemProperty -Name ID -Path $Reg -ErrorAction SilentlyContinue            
            }
            if ($Location) {
                Write-Output ".Removing LocationID"
                Remove-ItemProperty -Name LocationID -Path $Reg -ErrorAction SilentlyContinue
            }
            if ($MAC) {
                Write-Output ".Removing MAC"
                Remove-ItemProperty -Name MAC -Path $Reg -ErrorAction SilentlyContinue
            }
            Start-PLTService
            $timeout = new-timespan -Minutes 1
            $sw = [diagnostics.stopwatch]::StartNew()
            While (!(Get-PLTServiceInfo).ID -or !(Get-PLTServiceInfo).LocationID -or !(Get-PLTServiceInfo).MAC -and $sw.elapsed -lt $timeout){
                Write-Host -NoNewline '.'
                Start-Sleep 2
            }

        }#End Try
    
        Catch{
            Write-Error "ERROR: There was an error durring the reset process. $($Error[0])" -ErrorAction Stop
        }#End Catch
    }#End Process
  
    End{
        if ($?){
            Write-Output ""
            Write-Output "NEW ID: $((Get-PLTServiceInfo).ID) LocationID: $((Get-PLTServiceInfo).LocationID) MAC: $((Get-PLTServiceInfo).MAC)"
        }
        Else {$Error[0]}
    }#End End
}#End Function Get-PLTError

Function Hide-PLTAddRemove{
<#
.SYNOPSIS
    This function hides the LabTech install from the Add/Remove Programs list.

.DESCRIPTION
    This function will rename the DisplayName registry key to hide it from the Add/Remove Programs list.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
.LINK
    http://labtechconsulting.com
#>
    [CmdletBinding()]
    Param()

    Begin{
        $RegRoots = 'HKLM:\SOFTWARE\Classes\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F','HKLM:\SOFTWARE\Classes\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC'
        foreach($RegRoot in $RegRoots){
            if (Get-ItemProperty $RegRoot -Name ProductName -ErrorAction SilentlyContinue) {
                Write-Output "LabTech found in add/remove programs."
            }
            else {
                if (Get-ItemProperty $RegRoot -Name HiddenProductName -ErrorAction SilentlyContinue) {
                    Write-Error "LabTech already hidden from add/remove programs." -ErrorAction Stop
                }    
            }
        }
        
    }#End Begin
  
    Process{
        Try{
            Rename-ItemProperty $RegRoot -Name ProductName -NewName HiddenProductName
        }#End Try
    
        Catch{
            Write-Error "There was an error renaming the registry key. $($Error[0])" -ErrorAction Stop
        }#End Catch
    }#End Process
  
    End{
        if ($?){
            Write-Output "LabTech is now hidden from Add/Remove Programs."
        }
        else {$Error[0]}
    }#End End
}#End Function Hide-PLTAddRemove

Function Show-PLTAddRemove{
<#
.SYNOPSIS
    This function shows the LabTech install in the add/remove programs list.

.DESCRIPTION
    This function will rename the HiddenDisplayName registry key to show it in the add/remove programs list.
    If there is not HiddenDisplayName key the function will import a new entry.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
.LINK
    http://labtechconsulting.com
#>
    [CmdletBinding()]
    Param()

    Begin{
        $RegRoots = 'HKLM:\SOFTWARE\Classes\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC'
    }#End Begin
  
    Process{
        Try{
            foreach($RegRoot in $RegRoots){

                if (Get-ItemProperty $RegRoot -Name HiddenProductName -ErrorAction SilentlyContinue){
                    Rename-ItemProperty $RegRoot -Name HiddenProductName -NewName ProductName
                }
                else{
                    $RegImport = @'
[HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC]
"PackageCode"="8059C8AD908AB434A9F2225AF86355C2"
"Language"=dword:00000409
"Version"=dword:0b00016d
"Assignment"=dword:00000001
"AdvertiseFlags"=dword:00000184
"ProductIcon"="C:\\WINDOWS\\Installer\\{58A3001D-B675-4D67-A5A1-0FA9F08CF7CA}\\LabTeCh.ico"
"InstanceType"=dword:00000000
"AuthorizedLUAApp"=dword:00000000
"DeploymentFlags"=dword:00000003
"Clients"=hex(7):3a,00,00,00,00,00
"ProductName"="LabTech® Software Remote Agent"
'@
                    $RegImport | Out-File "$env:TEMP\LT.reg" -Force
                    Start-Process -Wait -FilePath reg -ArgumentList "import $($env:TEMP)\LT.reg"
                    Remove-Item "$env:TEMP\LT.reg" -Force
                    New-ItemProperty -Path "$RegRoot\SourceList" -Name LastUsedSource -Value "u;1;$(((Get-PLTServiceInfo).'Server Address').Split(';'))/Labtech/" -PropertyType ExpandString -Force | Out-Null
                    New-ItemProperty -Path "$RegRoot\SourceList\URL" -Name 1 -Value "$(((Get-PLTServiceInfo).'Server Address').Split(';'))/Labtech/" -PropertyType ExpandString -Force | Out-Null
                }
            }
        }#End Try
    
        Catch{
            Write-Error "There was an error renaming the registry key. $($Error[0])" -ErrorAction Stop
        }#End Catch
    }#End Process
  
    End{
        if ($?) {
            Write-Output "LabTech is now shown in Add/Remove Programs."
        }
        Else{$Error[0]}
    }#End End
}#End Function Show-PLTAddRemove

Function Test-PLTPorts{
<#
.SYNOPSIS
    This function will attempt to connect to all required TCP ports.

.DESCRIPTION
    The function will make sure that LTTray is using UDP 42000.
    It will then test all the required TCP ports.

.PARAMETER Server
    This is the URL to your LabTech server. 
    Example: https://lt.domain.com
    This is used to download the installation and removal utilities.
    If no server is provided the uninstaller will use Get-PLTServiceInfo to get the server address.
    If it is unable to find LT currently installed it will try Get-PLTServiceInfoBackup

.PARAMETER Quiet
    This will return a bool for connectivity to the Server

.NOTES
    Version:        1.4
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date:    5/11/2017 
    Purpose/Change: Quiet feature

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2

    Update Date: 6/10/2017
    Purpose/Change: Updates for pipeline input, support for multiple servers

    Update Date: 8/24/2017
    Purpose/Change: Update to use Clear-Variable.
    
.LINK
    http://labtechconsulting.com
#>
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipelineByPropertyName = $true, ValueFromPipeline=$True)]
        [string[]]$Server,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [switch]$Quiet
    )

    Begin{
        Function Private:TestPort{
        Param(
            [parameter(ParameterSetName='ComputerName', Position=0)]
            [string]
            $ComputerName,

            [parameter(ParameterSetName='IP', Position=0)]
            [System.Net.IPAddress]
            $IPAddress,

            [parameter(Mandatory=$true , Position=1)]
            [int]
            $Port
            )

        $RemoteServer = If ([string]::IsNullOrEmpty($ComputerName)) {$IPAddress} Else {$ComputerName};
    
        $test = New-Object System.Net.Sockets.TcpClient;
        Try
        {
            Write-Output "Connecting to $($RemoteServer):$Port (TCP)..";
            $test.Connect($RemoteServer, $Port);
            Write-Output "Connection successful";
        }
        Catch
        {
            Write-Output "ERROR: Connection failed";
            $Global:PortTestError = 1
        }
        Finally
        {
            $test.Close();
        }

    }#End Function TestPort

        Clear-Variable CleanSvr,svr,proc,processes,port,netstat,line -EA 0 #Clearing Variables for use

        if (-not ($Quiet)){
            #Learn LTTrayPort if available.
            $Port = (Get-PLTServiceInfo -EA 0|Select-Object -Expand TrayPort -EA 0)
        if (-not ($Port) -or $Port -notmatch '^\d+$') {$Port=42000}
            [array]$processes = @()
            #Get all processes that are using LTTrayPort (Default 42000)
            $netstat = netstat.exe -a -o -n | Select-String $Port -EA 0
            foreach ($line in $netstat) {
                $process += ($line -split '  {3,}')[-1]
            }
            $processes = $processes | Where-Object {$_ -gt 0 -and $_ -match '^\d+$'}| Sort-Object | Get-Unique
            if ($processes) {
            foreach ($proc in $processes) {
            if ((Get-Process -ID $proc -EA 0).ProcessName -eq 'LTSvc') {
                Write-Output "LTSvc is using port $Port"
            } else {
                Write-Output "Error: $((Get-Process -ID $proc).ProcessName) is using port $Port"
            }
               }
            }
        }    
    }#End Begin
  
    Process{
        if (-not ($Server)){
            Write-Verbose 'No Server Input - Checking for names.'
            $Server = Get-PLTServiceInfo -EA 0|Select-Object -Expand 'Server'
        }
    foreach ($svr in $Server) {
            if ($Quiet){
                Test-Connection $Svr -Quiet
                return
            }

            Try{
                $CleanSvr = ($Svr -replace("(http|https)://",'')|Foreach {$_.Trim()})
                Write-Output "Testing connectivity to required TCP ports"
                TestPort -ComputerName $CleanSvr -Port 70
                TestPort -ComputerName $CleanSvr -Port 80
                TestPort -ComputerName $CleanSvr -Port 443
                TestPort -ComputerName mediator.labtechsoftware.com -Port 8002

            }#End Try

            Catch{
              Write-Error "ERROR: There was an error testing the ports. $($Error[0])" -ErrorAction Stop
            }#End Catch
        }#End Foreach
      }#End Process
  
      End{
        If ($?){
            if (-not ($Quiet)){
                Write-Output "Finished"
            }          
        }
        else{$Error[0]}
      }#End End

}#End Function Test-PLTPorts

Function Get-PLTLogging{ 
<#
.SYNOPSIS
    This function will pull the logging level of the LabTech service.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
.LINK
    http://labtechconsulting.com
#> 
    [CmdletBinding()]
    Param ()
      
  Begin{
    Write-Verbose "Verbose: Checking for registry keys."
    if ((Test-Path 'HKLM:\SOFTWARE\LabTech\Service\settings') -eq $False){
        Write-Error "ERROR: Unable to find logging settings for LTSvc. Make sure the agent is installed." -ErrorAction Stop
    }
  }#End Begin
  
  Process{
    Try{
        $Value = (Get-PLTServiceSettings).Debuging
    }#End Try
    
    Catch{
      Write-Error "ERROR: There was a problem reading the registry key. $($Error[0])" -ErrorAction Stop
    }#End Catch
  }#End Process
  
  End{
    if ($?){
        if ($value -eq 1){
            Write-Output "Current logging level: Normal"
        }
        elseif ($value -eq 1000){
            Write-Output "Current logging level: Verbose"
        }
        else{
            Write-Error "ERROR: Unknown Logging level $((Get-PLTServiceInfo).Debuging)" -ErrorAction Stop
        }
    }    
  }#End End
}#End Function Get-PLTLogging

Function Set-PLTLogging{ 
<#
.SYNOPSIS
        This function will set the logging level of the LabTech service.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
.LINK
    http://labtechconsulting.com
#> 
   Param (
        [switch]$Normal,
        [switch]$Verbose
    )

      
  Begin{
    if ($Normal -ne $true -and $Verbose -ne $true ){
        Write-Error "Please provide a logging level. -Normal or -Verbose" -ErrorAction Stop
    }

  }#End Begin
  
  Process{
    Try{
        Stop-PLTService
        if ($Normal){
            Set-ItemProperty HKLM:\SOFTWARE\LabTech\Service\Settings -Name 'Debuging' -Value 1
        }
        if ($Verbose){
            Set-ItemProperty HKLM:\SOFTWARE\LabTech\Service\Settings -Name 'Debuging' -Value 1000
        }
        Start-PLTService
    }#End Try
    
    Catch{
      Write-Error "ERROR: There was a problem writing the registry key. $($Error[0])" -ErrorAction Stop
    }#End Catch
  }#End Process
  
  End{
    if ($?){
        Get-PLTLogging          
    }    
  }#End End
}#End Function Set-LTSLogging

Function Get-PLTProbeErrors {
<#
.SYNOPSIS
    This will pull the %ltsvcdir%\LTProbeErrors.txt file into an object.

.EXAMPLE
    Get-PLTProbeErrors | where {(Get-date $_.Time) -gt (get-date).AddHours(-24)}
    Get a list of all errors in the last 24hr

.EXAMPLE
    Get-PLTProbeErrors | Out-Gridview
    Open the log file in a sortable searchable window.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
.LINK
    http://labtechconsulting.com
#> 

    [CmdletBinding()]
    Param()
    
    Begin{
        $BasePath = $(Get-PLTServiceInfo -ErrorAction SilentlyContinue).BasePath
        if (!$BasePath){$BasePath = "$env:windir\LTSVC"}
        if ($(Test-Path -Path $BasePath\LTProbeErrors.txt) -eq $False) {
            Write-Error "ERROR: Unable to find log." $($Error[0]) -ErrorAction Stop
        }
    }#End Begin
    process{
        $errors = Get-Content $BasePath\LTProbeErrors.txt
        $errors = $errors -join ' ' -split ':::'
        foreach($Line in $Errors){
            $items = $Line -split "`t" -replace ' - ',''
            $object = New-Object -TypeName PSObject
            $object | Add-Member -MemberType NoteProperty -Name ServiceVersion -Value $items[0]
            $object | Add-Member -MemberType NoteProperty -Name Timestamp -Value $([datetime]$items[1])
            $object | Add-Member -MemberType NoteProperty -Name Message -Value $items[2]
            Write-Output $object
        }
    }
    End{
        if ($?){
        }
        Else {$Error[0]}
        
    }#End End
}#End Function Get-PLTProbeErrors

Function New-PLTServiceBackup {
<#
.SYNOPSIS
    This function will backup all the reg keys to 'HKLM\SOFTWARE\LabTechBackup'
    This will also backup those files to "$((Get-PLTServiceInfo).BasePath)Backup"

.NOTES
    Version:        1.3
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  5/11/2017
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
    Update Date: 6/7/2017
    Purpose/Change: Updated error handling.
    
    Update Date: 8/24/2017
    Purpose/Change: Update to use Clear-Variable.
    
.LINK
    http://labtechconsulting.com
#> 
    [CmdletBinding()]
    Param ()
      
  Begin{
    Clear-Variable LTPath,BackupPath,Keys,Path,Result,Reg,RegPath -EA 0 #Clearing Variables for use
    $LTPath = "$(Get-PLTServiceInfo -EA 0|Select-Object -Expand BasePath -EA 0)"
    if (-not ($LTPath)) {
      Write-Error "ERROR: Unable to find LTSvc folder path." -ErrorAction Stop
    }
    $BackupPath = "$($LTPath)Backup"
    $Keys = "HKLM\SOFTWARE\LabTech"
    $RegPath = "$BackupPath\LTBackup.reg"
    
    Write-Verbose "Verbose: Checking for registry keys."
    if ((Test-Path ($Keys -replace '^(H[^\\]*)','$1:')) -eq $False){
        Write-Error "ERROR: Unable to find registry information on LTSvc. Make sure the agent is installed." -ErrorAction Stop
        Return
    }
    if ($(Test-Path -Path $LTPath -PathType Container) -eq $False) {
      Write-Error "ERROR: Unable to find LTSvc folder path $LTPath" -ErrorAction Stop
    }
    New-Item $BackupPath -type directory -ErrorAction SilentlyContinue | Out-Null
    if ($(Test-Path -Path $BackupPath -PathType Container) -eq $False) {
      Write-Error "ERROR: Unable to create backup folder path $BackupPath" -ErrorAction Stop
    }
  }#End Begin
  
  Process{
    Try{
    Copy-Item $LTPath $BackupPath -Recurse -Force
    }#End Try
    
    Catch{
    Write-Error "ERROR: There was a problem backing up the LTSvc Folder. $($Error[0])"
    }#End Catch

    Try{
    $Result = reg.exe export "$Keys" "$RegPath" /y 2>''
    $Reg = Get-Content $RegPath
    $Reg = $Reg -replace [Regex]::Escape('[HKEY_LOCAL_MACHINE\SOFTWARE\LabTech'),'[HKEY_LOCAL_MACHINE\SOFTWARE\LabTechBackup'
    $Reg | Out-File $RegPath
    $Result = reg.exe import "$RegPath" 2>''
    $True | Out-Null #Protection to prevent exit status error
    }#End Try
 
    Catch{
    Write-Error "ERROR: There was a problem backing up the LTSvc Registry keys. $($Error[0])"
    }#End Catch
  }#End Process
  
  End{
    If ($?){
    Write-Output "The LabTech Backup has been created."
    }
    Else {
        Write-Error "ERROR: There was a problem completing the LTSvc Backup. $($Error[0])"
    }#End If
  }#End End
}#End Function New-PLTServiceBackup

Function Get-PLTServiceInfoBackup { 
<#
.SYNOPSIS
    This function will pull all of the backed up registry data into an object.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  5/11/2017
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
.LINK
    http://labtechconsulting.com
#> 
    [CmdletBinding()]
    Param ()
      
  Begin{
    Write-Verbose "Verbose: Checking for registry keys."
    If ((Test-Path 'HKLM:\SOFTWARE\LabTechBackup\Service') -eq $False){
        Write-Error "ERROR: Unable to find backup information on LTSvc. Use New-PLTServiceBackup to create a settings backup."
        Return
    }
    $exclude = "PSParentPath","PSChildName","PSDrive","PSProvider","PSPath"
  }#End Begin
  
  Process{
    Try{
        $key = Get-ItemProperty HKLM:\SOFTWARE\LabTechBackup\Service -ErrorAction Stop | Select * -exclude $exclude
        if (($key|Get-Member|Where {$_.Name -match 'BasePath'})) {
            $key.BasePath = [System.Environment]::ExpandEnvironmentVariables($key.BasePath)
        }
        if (($key|Get-Member|Where {$_.Name -match 'Server Address'})) {
        $Servers = ($Key|Select-Object -Expand 'Server Address' -EA 0).Split('|')|Foreach {$_.Trim()}
        Add-Member -InputObject $key -MemberType NoteProperty -Name 'Server' -Value $Servers -Force
    }
    }#End Try
    
    Catch{
      Write-Error "ERROR: There was a problem reading the registry keys. $($Error[0])"
    }#End Catch
  }#End Process
  
  End{
    If ($?){
        $key
    }    
  }#End End
}#End Function Get-PLTServiceInfoBackup

Function Rename-PLTAddRemove{
<#
.SYNOPSIS
    This function renames the LabTech install as shown in the Add/Remove Programs list.

.DESCRIPTION
    This function will change the value of the DisplayName registry key to effect Add/Remove Programs list.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  5/14/2017
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
.LINK
    http://labtechconsulting.com
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)]
        $Name
    )

    Begin{
        $RegRoot = 'HKLM:\SOFTWARE\Classes\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC'       
    }#End Begin
  
    Process{
        Try{
            Set-ItemProperty $RegRoot -Name ProductName -Value $Name
        }#End Try
    
        Catch{
            Write-Error "There was an error renaming the registry key. $($Error[0])" -ErrorAction Stop
        }#End Catch
    }#End Process
  
    End{
        if ($?){
            Write-Output "LabTech is now listed as '$Name' in Add/Remove Programs."
        }
        else {$Error[0]}
    }#End End
}#End Function Rename-PLTAddRemove

#endregion Functions
rein