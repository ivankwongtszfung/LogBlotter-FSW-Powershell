#region File Settings & classes

    $Path = "<SomePath>"
    $filename = "<SomeFilename>"

    Add-Type -AssemblyName PresentationFramework
    $DataContext = New-Object System.Collections.ObjectModel.ObservableCollection[Object]

    $fileroot = "Y:"
    $filepath  = New-Object System.Collections.Generic.List[System.Object]
    $filePathHash = [hashtable]::Synchronized(@{})
    $meta = New-Module -AsCustomObject -ScriptBlock {
        [System.Collections.Generic.List[System.Object]]$Filepaths = New-Object System.Collections.Generic.List[System.Object]
        [System.Datetime]$startDateTime = [System.Datetime]::Today
        Export-ModuleMember -Variable * -Function *
    }

    $syncHash = [hashtable]::Synchronized(@{})
    $syncHash.filePathHash = $filePathHash
    $syncHash.meta = $meta
#endregion
#region FSWatcher
    #region RunSpace Definition $newRunspace
        $newRunspace =[runspacefactory]::CreateRunspace()
        $newRunspace.ApartmentState = "STA"
        $newRunspace.ThreadOptions = "ReuseThread"         
        $newRunspace.Open()
        $newRunspace.SessionStateProxy.SetVariable("meta",$meta)
        $newRunspace.SessionStateProxy.SetVariable("syncHash",$syncHash)    
    #endregion
    #region Runspace Definition FSWatcher
        $psCmd = [PowerShell]::Create().AddScript({ 
        $winObj = new-object System.IO.FileSystemWatcher
        $winObj.Filter = "*.log"
        $winObj.Path = $Path
        $winObj.IncludeSubdirectories = $true
        $winObj.NotifyFilter = [System.IO.NotifyFilters]::LastAccess , [System.IO.NotifyFilters]::LastWrite, [System.IO.NotifyFilters]::FileName , [System.IO.NotifyFilters]::DirectoryName;
        $action = {
            try{
                $Object = New-Object System.Collections.Generic.List[System.Object]

                $pathname = $Event.SourceEventArgs.FullPath

                if(!$syncHash.filePathHash.ContainsKey($pathname)){
                    $syncHash.meta.Filepaths.Add($pathname)
                    $syncHash.filePathHash.Add($pathname,3)
                    if($syncHash.meta.Filepaths.Count -gt 1){
                         $syncHash.meta.Filepaths.Sort([System.Management.Automation.ScriptBlock]{
                            param ($x,$y)
                            $x = split-path -Path $x -Parent | split-path -Parent | split-path -Leaf
                            $y = split-path -Path $y -Parent | split-path -Parent | split-path -Leaf
                            $xNum = [System.Int16]$x.SubString(7,$x.length - 7)
                            $yNum = [System.Int16]$y.SubString(7,$y.length - 7)
                            return ($xNum - $yNum)
                        })

                    }
                    Write-Host "new File: $pathname" -ForegroundColor Yellow
                }

                $localFilepath = $syncHash.meta.Filepaths
                $localDataContext = $syncHash.DataContext

                for($i=0 ;$i -lt $localFilepath.count; $i++){
                
                    if ([System.IO.File]::Exists($localFilepath[$i])) {  
        
                        $lastOne = Get-Content -tail 1 $localFilepath[$i] 

                        $name = split-path -Path $localFilepath[$i] -Parent | split-path -Parent | split-path -Leaf

                        if ($lastOne -eq $localDataContext[$i].LogMessage){
                            $time = $localDataContext[$i].LogTime
                        }else{
                            $time = $event.TimeGenerated
                        }

                        if($((New-TimeSpan -Start $time -End ([DateTime]::Now)).Minutes) -gt 6 ){
                            $LogStatus = "OverRun"
                            $syncHash.alert = 1
                        }
                        elseif($props.LogMessage -eq "No file found"){
                            $LogStatus = "Ready"
                        }
                        else{
                            $LogStatus = "Running"
                        }
                        
                        $item = New-Object PSObject -Property @{
                                logprogramname  = $name
                                LogMessage      = $lastOne
                                LogStatus     	= $LogStatus
                                LogTime         = $time
                                LogFilePath     = $localFilepath[$i]
                            }

                        $Object.Add($item)

                    }

                }

            
                $syncHash.DataContext = $Object
            }
            catch{
                Write-Host $Error 
            }


        }
        $syncHash.fsw = $winObj
        $syncHash.registerEvent = Register-ObjectEvent $winObj Changed -SourceIdentifier LogFileChanges -Action $action

    })
    $psCmd.Runspace = $newRunspace
    #endregion
#endregion

#region WPF Controls

[xml]$xaml = @"
            <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                Title="Log Blotter"
                SizeToContent="WidthAndHeight">                 
                <Grid>                      
                    <Grid.RowDefinitions>
                        <RowDefinition Height="*" />
                    </Grid.RowDefinitions>
                                        
                    <DataGrid x:Name="observableDataGrid"  AutoGenerateColumns="False" ItemsSource="{Binding}" GridLinesVisibility="None">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Program Name" Binding="{Binding logprogramname}"></DataGridTextColumn>
                                                
                            <DataGridTextColumn Header="Status" Binding="{Binding LogStatus}">
                                <DataGridTextColumn.ElementStyle>
                                        <Style TargetType="{x:Type TextBlock}">
                                            <Style.Triggers>
                                                <Trigger Property="Text" Value="Ready">
                                                    <Setter Property="Background" Value="#D2E1F4"/>
                                                </Trigger>
                                                <Trigger Property="Text" Value="Running">
                                                    <Setter Property="Background" Value="#E0CCFF"/>
                                                    <Setter Property="Foreground" Value="#FFFFFF" />
                                                </Trigger>
                                                <Trigger Property="Text" Value="OverRun">
                                                    <Setter Property="Background" Value="#FFBFBF"/>
                                                    <Setter Property="Foreground" Value="#000000" />
                                                </Trigger>
                                                                    
                                            </Style.Triggers>
                                        </Style>
                                    </DataGridTextColumn.ElementStyle>
                            </DataGridTextColumn>
                            <DataGridTextColumn Header="Message" Binding="{Binding logmessage}"></DataGridTextColumn>
                            <DataGridTextColumn Header="Path" Binding="{Binding LogFilePath}"></DataGridTextColumn>
                        </DataGrid.Columns>
                    </DataGrid>
                </Grid>
                <Window.Resources>
                    <!--A Style that affects all DataGridRow-->
                    <Style  TargetType="{x:Type DataGridRow}">
                        <Setter Property="Foreground" Value="#000000"/>
                        <Setter Property="Height" Value="25"/>
                        <Setter Property="HorizontalContentAlignment" Value="Center"/>
                        <Setter Property="MaxHeight" Value="75" />
                        <Setter Property="FontSize" Value="14"/>
                        <Style.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter Property="Opacity" Value="1.0" />
                            </Trigger>
                            <DataTrigger Binding="{Binding Path=LogStatus}" Value="OverRun">
                                <Setter Property="Foreground" Value="Red" />
                            </DataTrigger> 
                            </Style.Triggers>
                    </Style>
                </Window.Resources>
            </Window> 
"@
    
$reader=(New-Object System.Xml.XmlNodeReader $xaml)

$syncHash.Window = [Windows.Markup.XamlReader]::Load( $reader )

#endregion

$observableDataGrid = $syncHash.Window.FindName("observableDataGrid")

$syncHash.alert = 0

$syncHash.DataContext = $DataContext
    
$syncHash.DataGrid = $observableDataGrid
    
$syncHash.DataGrid.ItemsSource = $syncHash.DataContext
    
$scriptBlock = {
    $syncHash.DataGrid.ItemsSource = $syncHash.DataContext

    if($syncHash.alert -eq 1 ){
        #$syncHash.Window.WindowState = "minimized";
        $syncHash.Window.WindowState = "Normal";
        $syncHash.Window.Show();
        $syncHash.Window.Activate();
        $syncHash.alert = 0
    }

    if(([System.TimeSpan] ( ([System.Datetime]::Today)- ($syncHash.meta.startDateTime))).Hours -ge 1){
        $syncHash.meta.startDateTime = get-date
        $syncHash.DataContext.clear()
    }

        
}

$syncHash.Window.Add_SourceInitialized( {
    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]"0:0:10.0"
    $timer.Add_Tick($scriptBlock)
    $timer.Start()
    if (!$timer.IsEnabled) {
        $syncHash.Window.Close()
    } 
})

#endregion
#region Main
$psCmd.Invoke()
$psCmd.Dispose()
$syncHash.Window.TopMost = $True;
$syncHash.Window.ShowDialog() | Out-Null

#dispose
$syncHash.window.Close()
$syncHash.fsw.Dispose()
(Get-Runspace| where {$_.Id -ne 1}).dispose()
#Error
$syncHash.Error = $Error
$Error.Clear()
#Display Error
Write-Host "Runspace:" -fore Green
Write-host $syncHash.Error -fore Red -BackgroundColor Black
Write-Host "Form Runspace:" -fore Green
Write-Host $syncHash.formError -fore Red -BackgroundColor Black
#endregion