
Properties {
  $projectName ="Appccelerate"
  
  $base_dir = Resolve-Path ..
  $binaries_dir = "$base_dir\binaries"
  $source_dir = "$base_dir\source"
  $publish_dir = "$base_dir\publish"
  
  $sln_file = "$source_dir\$projectName.sln"
  
  $version_file_name = "Version.txt"
  $assembly_info_file_name = "VersionInfo.g.cs"
  
  $xunit_runner = "$source_dir\packages\xunit.runners.1.9.1\tools\xunit.console.clr4.x86.exe"
  $mspec_runner = "$source_dir\packages\Machine.Specifications.0.5.8\tools\mspec-clr4.exe"
  
  $publish = $false
  $parallelBuild = $true
}

FormatTaskName (("-"*70) + [Environment]::NewLine + "[{0}]"  + [Environment]::NewLine + ("-"*70))

Task default –depends Clean, WriteAssemblyInfo #, Build, Test, CopyBinaries, ResetAssemblyInfo, Nuget

Task Clean { 
    Write-Host "cleaning"
    
    #Delete all bin and obj folders within source directory
    Get-Childitem $source_dir -Recurse | 
    Where {$_.psIsContainer -eq $true -and ($_.name -eq "bin" -or $_.name -eq "obj") } | 
    Foreach-Object { 
        Write-Host "deleting" $_.fullname
        Remove-Item $_.fullname -force -recurse -ErrorAction SilentlyContinue
    }
}

Task WriteAssemblyInfo -precondition { return $publish } -depends clean{
    Write-Host "writing assembly info"
    
    Get-Childitem $source_dir | 
    Where{$_.psIsContainer -eq $true `
    -and $_.name -like "$projectName.*" `
    -and $_.name -notlike "$projectName.*.Test" `
    -and $_.name -notlike "$projectName.*.Specification" `
    -and $_.name -notlike "$projectName.*.Sample" `
    -and $_.name -notlike "$projectName.*.Performance" `
    -and $_.name -notlike "\.*"} | 
    Foreach-Object { 
       Write-Host "updating assembly info of" $_.fullname
       $versionFile = $_.fullname + "\" + $version_file_name
       $assemblyInfoFile = $_.fullname + "\Properties\" + $assembly_info_file_name
       $version = Get-Content $versionFile
       Generate-Assembly-Info `
       -file $assemblyInfoFile `
       -version $version `
    }
}

Task Build -depends Clean, WriteAssemblyInfo {
    Write-Host "building" $sln_file 
    if($parallelBuild){
    
        if($Env:MAX_CPU_COUNT){
            $maxcpucount = ":$Env:MAX_CPU_COUNT"
        }

        msbuild $sln_file "/p:Configuration=Release" "/t:Rebuild" "/p:Platform=Any CPU" "/verbosity:minimal" "/fileLogger" "/fileLoggerParameters:LogFile=$base_dir/msbuild.log" "/m$maxcpucount"
    }else{
        msbuild $sln_file "/p:Configuration=Release" "/t:Rebuild" "/p:Platform=Any CPU" "/verbosity:minimal" "/fileLogger" "/fileLoggerParameters:LogFile=$base_dir/msbuild.log"
    }
}

Task Test -depends Clean, Build {
    Write-Host "testing"
    RunUnitTest
    RunMSpecTest
}

Task CopyBinaries -precondition { return $publish } -depends Clean, WriteAssemblyInfo, Build, Test {
    Write-Host "copying binaries"
}

Task ResetAssemblyInfo -precondition { return $publish } -depends Clean, WriteAssemblyInfo, Build, Test, CopyBinaries {
    Write-Host "reseting assembly info"
}

Task Nuget -precondition { return $publish } -depends Clean, WriteAssemblyInfo, Build, Test, CopyBinaries {
    Write-Host "reseting assembly info"
}

Function RunUnitTest(){
    $bin_folders = Get-Childitem $source_dir -include bin -Recurse
    $test_assemblies = Get-Childitem $bin_folders -include *Test.dll -Recurse 
    if($test_assemblies -ne $null){
        foreach ($test_assembly in $test_assemblies)
        {
            Write-Host "testing" $test_assembly
            exec { cmd /c "$xunit_runner $test_assembly" }
        }
    }
}

Function RunMSpecTest(){
    $bin_folders = Get-Childitem $source_dir -include bin -Recurse
    $test_assemblies = Get-Childitem $bin_folders -include *Specification.dll -Recurse 
    if($test_assemblies -ne $null){
        foreach ($test_assembly in $test_assemblies)
        {
            Write-Host "testing" $test_assembly
            exec { cmd /c "$mspec_runner $test_assembly" }
        }
    }
}