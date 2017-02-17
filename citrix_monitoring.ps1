#------------------------------------------------------------------------------
# citrix_monitoring.ps1 
#------------------------------------------------------------------------------

# Author	: Andre Becker (Bechtle) Version 3.0
# 
#------------------------------------------------------------------------------
# Enable (1) or Disable (0) Debug Output
#------------------------------------------------------------------------------
$DebugInfoEnabled=0

#------------------------------------------------------------------------------
# Check if Citrix Snapin is loaded
#------------------------------------------------------------------------------
$StartAddIn = (Get-Date)
if ( (Get-PSSnapin -Name Citrix.Common.Commands -ErrorAction SilentlyContinue) -eq $null ) {
	Add-PSSnapin Citrix.*
}

$EndAddIn = (Get-Date)

if ($DebugInfoEnabled -eq '1') {
	write-host "------------------------------------------------------------------------------"
	Write-host "Elapsed Time AddIn		: $(($EndAddIn-$StartAddIn).totalseconds) seconds"
	write-host "------------------------------------------------------------------------------"
}

#------------------------------------------------------------------------------
# Set global variables
#------------------------------------------------------------------------------
$StartSGV = (Get-Date)
$mydate = Get-Date
[int] $dayOfWeek=$mydate.DayOfWeek

#Gets the XD information
$site = Get-XDSite
$sitename=$site.Name
$brokerapplications = get-brokerapplication
$VDAServers = Get-BrokerMachine
$zones = Get-BrokerController
$BrokerCatalogs = Get-BrokerCatalog
$BrokerSessions = Get-BrokerSession
$OnlineServers=@{}
$ServerSessions=@{}
$OnlineCount=@{}
$OfflineCount=@{}
#[int] $TotalSiteServerCount=0
#$DCList=@{}

#------------------------------------------------------------------------------
# Get working directory...
#------------------------------------------------------------------------------
if ($env:CANDLE_HOME) {
	$CurDir=$env:CANDLE_HOME + "\tmaitm6"
} else {
	$CurDir="c:\appl\ibm\itm\tmaitm6"
}

#------------------------------------------------------------------------------
# Check if the Logfile Directory exists...if not create it
#------------------------------------------------------------------------------
$LogDir="$CurDir\Citrix_XD"
if ( ! (Test-Path $LogDir)) {
	$rc=New-Item $LogDir -type directory
}

#------------------------------------------------------------------------------
# Check if a Environment.txt file exists and set appropriate environment 
# variables provided by the agentbuilder...
#------------------------------------------------------------------------------
$EnvFile="$LogDir\Environment.txt"
if (Test-Path $EnvFile) {
	$myenv=Get-content $EnvFile
	if ($myenv[0] -eq "%K28_EXCLUDE_SILOS%") {
		$env:K28_EXCLUDE_SILOS=""
	} else {
		$env:K28_EXCLUDE_SILOS=$myenv[0]
	}
}

#------------------------------------------------------------------------------
# Prepare Data Structures
#------------------------------------------------------------------------------
$OnlineCount=0
$OfflineCount=0
foreach($VDAServer in $VDAServers) {
	if ($VDAServer.RegistrationState -match 'Registered'){
		$OnlineCount++
		$ServerSessions[$VDAServer.UUID]=$VDAServer.SessionCount
	} else {
		$OfflineCount++
	}
	$OnlineZoneCount=$OnlineCount
	$OfflineZoneCount=$OfflineCount
}
$TotalSiteServerCount= $OnlineCount + $OfflineCount
$EndSGV = (Get-Date)
if ($DebugInfoEnabled -eq '1') {
	write-host "------------------------------------------------------------------------------"
	Write-host "Elapsed Time Get VDAs		: $(($EndSGV-$StartSGV).totalseconds) seconds"
	write-host "------------------------------------------------------------------------------"
}

#------------------------------------------------------------------------------
# Function Rotate Logfiles
#------------------------------------------------------------------------------
function RotateFile([string] $FileToRotate) {
	$StartRotateLog = (Get-Date)
	if (Test-Path $FileToRotate) {
		$NewFile=$FileToRotate.trimend(".new") + ".txt"
		Move-Item $FileToRotate $NewFile -force
	}
	$EndRotateLog = (Get-Date)
	if ($DebugInfoEnabled -eq '1') {
		write-host "------------------------------------------------------------------------------"
		Write-host "Elapsed Time Rotate Logfiles: $($NewFile): $(($EndRotateLog-$StartRotateLog).totalseconds) seconds"
		write-host "------------------------------------------------------------------------------"
	}
}

#------------------------------------------------------------------------------
# Function VDAServers
#------------------------------------------------------------------------------
function VDAServers {
	$StartVDAServers = (Get-Date)
	$OutFileName="$script:LogDir\vdaservers.new"
	if (Test-Path $OutFileName) {
		Clear-Content $OutFileName
	}
	foreach($VDAserver in $VDAservers) {
		$script:TotalSiteServerCount++
		if ( $VDAserver.FaultState -match "None") {
			$SvrStatus=1
			$sessioncount = $VDAserver.SessionCount
		} else {
			$load = 0
			$SvrStatus = 0
			$SessionCount = 0
		}	
		if ( $VDAserver.InMaintenanceMode -match "False" ) {
			$InMaintenanceMode=1
		} else {
			$InMaintenanceMode=0
		}
		if ( $VDAserver.WindowsConnectionSetting -match "LogonEnabled" ) {
			$LogOnEnabled=1
		} elseif ( $VDAserver.WindowsConnectionSetting -match "LogonDisabled" ) {
			$LogOnEnabled=0
		}
		if ( $VDAserver.RegistrationState -match "Registered" ) {
			$Registerd=1
		} else {
			$Registerd=0
		}
		$output=$SiteName + ";" + 
			$VDAserver.ZoneName  + ";" +
			$VDAserver.DesktopGroupName + ";" +
			$VDAserver.DNSName + ";" +
			$VDAserver.IPAddress + ";" +
			$SvrStatus + ";" +
			$InMaintenanceMode + ";" +
			$dayOfWeek + ";" +
			$mydate.hour + ";" +
			$mydate.minute + ";" +
			$VDAserver.loadIndex + ";" +
			$Registerd + ";" +
			$SessionCount
		echo $output | add-content $OutFileName
		if ($DebugInfoEnabled -eq '1') {
			write-host "VDAServers Output		   : " $output
		}
	}
	$EndVDAServers = (Get-Date)
	RotateFile($OutFileName)
	if ($DebugInfoEnabled -eq '1') {
		Write-host "Elapsed Time VDAServers	 : $(($EndVDAServers-$StartVDAServers).totalseconds) seconds"
	}
}

#------------------------------------------------------------------------------
# function SiteInfo
#------------------------------------------------------------------------------
function SiteInfo{
	$StartSiteInfo = (Get-Date)
	$OutFileName="$script:LogDir\siteinfo.new"
	if (Test-Path $OutFileName) {
		Clear-Content $OutFileName
	}
	$output=$sitename + ";" +
			$OnlineCount + ";" +
			$dayOfWeek + ";" +
			$mydate.hour + ";" +
			$mydate.minute
	echo $output | add-content $OutFileName
	if ($DebugInfoEnabled -eq '1') {
		write-host "SiteInfo Output			 : " $output
	}
	$endSiteInfo = (Get-Date)
	RotateFile($OutFileName)
	if ($DebugInfoEnabled -eq '1') {
		write-host "------------------------------------------------------------------------------"
		Write-host "Elapsed Time SiteInfo	   : $(($endSiteInfo-$startSiteInfo).totalseconds) seconds"
		write-host "------------------------------------------------------------------------------"
	}
}

#------------------------------------------------------------------------------
# function ZoneInfo # Not Needed because we dont have Zones...
#------------------------------------------------------------------------------

function ZoneInfo{
	$StartZoneInfo = (Get-Date)
	$OutFileName="$script:LogDir\zoneinfo.new"
	if (Test-Path $OutFileName) {
		Clear-Content $OutFileName
	}
	foreach($zone in $script:zones) {
		If ($OfflineCount -eq "0"){
			$ZoneHealth=100
		} else {
			$ZoneHealth=[Int] ($OnlineCount/$OfflineCount*100)
		}
		$output=$sitename + ";" +
			$zone.DnsName + ";" +
			$OnlineCount + ";" +
			$OfflineCount + ";" +
			($OnlineCount+$OfflineCount) + ";" +
			$ZoneHealth + ";" +
			$dayOfWeek + ";" +
			$mydate.hour + ";" +
			$mydate.minute
		echo $output | add-content $OutFileName
		if ($DebugInfoEnabled -eq '1') {
			write-host "ZoneInfo Output			 : $output"
		}
	}
	$EndZoneInfo = (Get-Date)
	RotateFile($OutFileName)
	if ($DebugInfoEnabled -eq '1') {
		write-host "------------------------------------------------------------------------------"
		Write-host "Elapsed Time ZoneInfo	   : $(($endZoneInfo-$startZoneInfo).totalseconds) seconds"
		write-host "------------------------------------------------------------------------------"
	}
}

#------------------------------------------------------------------------------
# function ServerGroups
#------------------------------------------------------------------------------
function ServerGroups{
	$StartServerGroups = (Get-Date)
	$OutFileName="$script:LogDir\appgroups.new"
	if (Test-Path $OutFileName) {
		Clear-Content $OutFileName
	}
	$AppGroup=@{}
	$AppOnline=@{}
	$AppEffOnline=@{}
	$AppLoad=@{}
	$AppMaint=@{}
	$AppLock=@{}
	$AppMonitor=@{}
	$AppSessionCount=@{}
	$IgnoreList=""
	if ($env:K28_EXCLUDE_SILOS) {
		$K28_EXCLUDE_SILOS = $env:K28_EXCLUDE_SILOS
		$IgnoreList=$K28_EXCLUDE_SILOS.Split(" ")
	}
	foreach($server in $VDAservers) {
		$Online=0
		$FolderPath=$server.DesktopGroupName
		if ( $OnlineServers[$server.DNSName] -eq 1) {
			$loadline = $server.LoadIndex
			[int]$load=$loadline.Load
			[int]$sessioncount = $ServerSessions[$server.UUID]
			$SvrStatus=1
			if ($load -le 10000) {
				$Online=1
			}
		} else {
			$load = 0
			$SvrStatus = 0
			$sessioncount = 0
		}
		if ( ! $server.InMaintenanceMode ) {
			$Online=0
		}
		if ($AppGroup.count -gt 0) {
			$AppGroup.$FolderPath++
			if ($Online -eq 1) {
				$AppOnline.$FolderPath++
				$AppEffOnline.$FolderPath++
				$AppLoad.$FolderPath+=$load
				$AppSessionCount.$FolderPath+=$sessioncount
			}
		} else {
			$AppGroup.$FolderPath=1
			$AppLock.$FolderPath=0
			$AppMaint.$FolderPath=0
			if ($Online -eq 1) {
				$AppOnline.$FolderPath=1
				$AppEffOnline.$FolderPath=1
				$AppLoad.$FolderPath=$load
				$AppSessionCount.$FolderPath=$sessioncount
			} else {
				$AppOnline.$FolderPath=0
				$AppEffOnline.$FolderPath=0
				$AppLoad.$FolderPath=0
				$AppSessionCount.$FolderPath=0
			}
		}
		$AppMonitor.$FolderPath=1
		if ($IgnoreList -ne "") {
			foreach ($x in $IgnoreList) {
				if ($FolderPath.EndsWith($x)) {
					$AppMonitor.$FolderPath=0
				}
			}
		}
	}
	$AppGroup.GetEnumerator()  | Foreach-Object {
		$key=$_.Key
		if (($_.Value*$AppOnline.$key) -gt 0) {
			[int] $PctOnline=100/$_.Value*$AppOnline.$key
		} else {
			$PctOnline=0
		}
		if ($_.Value*$AppEffOnline.$key -gt 0) {
			[int] $EffPctOnline=100/$_.Value*$AppEffOnline.$key
		} else {
			$EffPctOnline=0
		}
		if ($AppOnline.$key -gt 0) {
			[int] $AvgLoad=$AppLoad.$key/$AppOnline.$key
		} else {
			$AvgLoad=0
		}
		$output=$key + ";" +
			$_.Value + ";" +
			$AppOnline.$key + ";" +
			$AppMaint.$key + ";" +
			$AppLock.$key + ";" +
			$PctOnline + ";" +
			$AvgLoad + ";" +
			$EffPctOnline + ";" + 
			$AppMonitor.$key + ";" +
			$AppSessionCount.$key
		echo $output | add-content $OutFileName
		if ($DebugInfoEnabled -eq '1') {
			write-host " ServerGroups Output		: $output"
		}
	}
	$EndServerGroups = (Get-Date)
	RotateFile($OutFileName)
	if ($DebugInfoEnabled -eq '1') {
		write-host "------------------------------------------------------------------------------"
		Write-host "Elapsed Time ServerGroups   : $(($endServerGroups-$startServerGroups).totalseconds) seconds"
		write-host "------------------------------------------------------------------------------"
	}
}

#------------------------------------------------------------------------------
# function Applications
#------------------------------------------------------------------------------

function Applications {
	$StartApplications = (Get-Date)
	$OutFileName="$script:LogDir\applications.new"
	if (Test-Path $OutFileName) {
		Clear-Content $OutFileName
	}
	foreach ($App in $brokerapplications) {
		$AppDistinguishedName=$App.AdminFolderName + $App.ApplicationName
		$AppDesc = $App.Description
		if (!$AppDesc) {
			$AppDesc = "No Description"
			}
		$AppWorkDir = $App.WorkingDirectory
		if (!$AppWorkDir) {
			$AppWorkDir = "Not Set"
			}
		$output= $AppDistinguishedName + ";" +
			$App.PublishedName + ";" +
			$AppDesc + ";" +
			$App.CommandLineExecutable + ";" +
			$AppWorkDir + ";" +
			@(Get-BrokerSession | Where-Object { $_.ApplicationsInUse -contains $AppDistinguishedName -and $_.SessionState -match 'Active'} | select UserFullName ).count + ";" +
            @(Get-BrokerSession | Where-Object { $_.ApplicationsInUse -contains $AppDistinguishedName -and $_.SessionState -notmatch 'Active'} | select UserFullName ).count + ";" + 
            @(Get-BrokerSession | Where-Object { $_.ApplicationsInUse -contains $AppDistinguishedName} | select UserFullName).count + ";" +
			$dayOfWeek + ";" +
			$mydate.hour + ";" +
			$mydate.minute
		echo $output | add-content $OutFileName
		if ($DebugInfoEnabled -eq '1') {
			write-host " Applications Output		: $output"
		}
	}
	$EndApplications = (Get-Date)
	RotateFile($OutFileName)
	if ($DebugInfoEnabled -eq '1') {
		write-host "------------------------------------------------------------------------------"
		Write-host "Elapsed Time Applications   : $(($EndApplications-$StartApplications).totalseconds) seconds"
		write-host "------------------------------------------------------------------------------"
	}
}

#------------------------------------------------------------------------------
# function MachineCatalogs
#------------------------------------------------------------------------------
function MachineCatalogs{
	$startMachineCatalogs = (Get-Date)
	$OutFileName="$script:LogDir\machinecatalogs.new"
	if (Test-Path $OutFileName) {
		Clear-Content $OutFileName
	}
	$AppGroup=@{}
	$AppOnline=@{}
	$AppEffOnline=@{}
	$AppLoad=@{}
	$AppMaint=@{}
	$AppLock=@{}
	$AppMonitor=@{}
	$AppSessionCount=@{}
	$IgnoreList=""
	if ($env:K28_EXCLUDE_WORKERGROUPS) {
		$K28_EXCLUDE_WORKERGROUPS = $env:K28_EXCLUDE_WORKERGROUPS
		$IgnoreList=$K28_EXCLUDE_WORKERGROUPS.Split(" ")
	}
	foreach($BrokerCatalog in $BrokerCatalogs) {
		$BrokerCatalogName = $BrokerCatalog.Name
		$BrokerCatalogserver = Get-brokermachine | Where-Object { $_.CatalogName -contains $BrokerCatalogName} | select dnsname
		foreach($server in $BrokerCatalogserver) {
			$Online=0
			if ( $OnlineServers[$server.DNSName] -eq 1) {
				$loadline = get-brokermachine $server.DNSName
				[int] $load=$loadline.Loadindex
				[int]$sessioncount = $ServerSessions[$server.ServerName]
				$SvrStatus=1
				if ($load -le 10000) {
					$Online=1
				}
			} else {
				$load = 0
				$SvrStatus = 0
				$sessioncount = 0
			}
			$mycount = $AppGroup.$BrokerCatalogName
			if ($mycount -gt 0) {
				$AppGroup.$BrokerCatalogName++
				if ($Online -eq 1) {
					$AppOnline.$BrokerCatalogName++
					$AppEffOnline.$BrokerCatalogName++
					$AppLoad.$BrokerCatalogName+=$load
					$AppSessionCount.$BrokerCatalogName+=$sessioncount
				}
			} else {
				$AppGroup.$BrokerCatalogName=1
				$AppLock.$BrokerCatalogName=0
				$AppMaint.$BrokerCatalogName=0
				if ($Online -eq 1) {
					$AppOnline.$BrokerCatalogName=1
					$AppEffOnline.$BrokerCatalogName=1
					$AppLoad.$BrokerCatalogName=$load
					$AppSessionCount.$BrokerCatalogName=$sessioncount
				} else {
					$AppOnline.$BrokerCatalogName=0
					$AppEffOnline.$BrokerCatalogName=0
					$AppLoad.$BrokerCatalogName=0
					$AppSessionCount.$BrokerCatalogName=0
				}
			}
			$AppMonitor.$BrokerCatalogName=1
			if ($IgnoreList -ne "") {
				foreach ($x in $IgnoreList) {
					if ($BrokerCatalogName.EndsWith($x)) {
						$AppMonitor.$BrokerCatalogName=0
					}
				}
			}
		}
	}
	$AppGroup.GetEnumerator()  | Foreach-Object {
		$key=$_.Key
		if (($_.Value*$AppOnline.$key) -gt 0) {
			[int] $PctOnline=100/$_.Value*$AppOnline.$key
		} else {
			$PctOnline=0
		}
		if ($_.Value*$AppEffOnline.$key -gt 0) {
			[int] $EffPctOnline=100/$_.Value*$AppEffOnline.$key
		} else {
			$EffPctOnline=0
		}
		if ($AppOnline.$key -gt 0) {
			[int] $AvgLoad=$AppLoad.$key/$AppOnline.$key
		} else {
			$AvgLoad=0
		}
		$output=$key + ";" +
			$_.Value + ";" +
			$AppOnline.$key + ";" +
			$AppMaint.$key + ";" +
			$AppLock.$key + ";" +
			$PctOnline + ";" +
			$AvgLoad + ";" +
			$EffPctOnline + ";" + 
			$AppMonitor.$key + ";" +
			$AppSessionCount.$key
		echo $output | add-content $OutFileName
		if ($DebugInfoEnabled -eq '1') {
			write-host " MachineCatalog Output		: $output"
		}
	}
	$EndMachineCatalogs = (Get-Date)
	RotateFile($OutFileName)
	if ($DebugInfoEnabled -eq '1') {
		write-host "------------------------------------------------------------------------------"
		Write-host "Elapsed Time MachineCatalogs    : $(($endMachineCatalogs-$startMachineCatalogs).totalseconds) seconds"
		write-host "------------------------------------------------------------------------------"
	}
}

#------------------------------------------------------------------------------
# Main Program
#------------------------------------------------------------------------------
VDAServers 		# DONE
#SiteInfo			# Not needed because no important infos
#ZoneInfo			# Not Needed because we dont have Zones
#ServerGroups		# No AppGroups - have to use something else - maybe Delivery Groups?
Applications		# DONE
MachineCatalogs	# DONE
echo "OK"
exit

