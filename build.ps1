$script:project_config = "Release"

properties {

  if(-not $version)
  {
      $version = "0.0.0.1"
  }
  $release_number =  if ($env:BUILD_NUMBER) {"1.0.$env:BUILD_NUMBER.0"} else {$version}
  
  $project_name       = "CodeCampServer"
  $base_dir           = resolve-path .
  $build_dir          = "$base_dir\build"
  $source_dir         = "$base_dir\src"
  $test_dir           = "$build_dir\test"
  $result_dir         = "$build_dir\results"
  $output_package_dir = "$build_dir\packages"
  $packages_dir       = "$source_dir\packages"
  $unit_test_dlls     =  @("*UnitTests.dll")

  $xunit_runner = @(gci $packages_dir -filter xunit.console.clr4.exe -recurse)[0].FullName
}

task default -depends DeveloperBuild
task ci -depends IntegrationBuild
task unit -depends RunAllUnitTests

task DeveloperBuild -depends SetDebugBuild, Clean, Compile,  RunAllUnitTests

task IntegrationBuild -depends SetReleaseBuild, CommonAssemblyInfo, Clean, Compile, RunAllUnitTests, GenerateNugetPackage

task SetDebugBuild {
    $script:project_config = "Debug"
}

task SetReleaseBuild {
    $script:project_config = "Release"
}

task Help {
  Write-Help-Header
  Write-Help-Section-Header "Comprehensive Building"
  Write-Help-For-Alias "(default)" "Optimized for local development"
  Write-Help-For-Alias "ci" "Continuous Integration build (long and thorough) with packaging"
  Write-Help-Section-Header "Running Tests"
  Write-Help-For-Alias "unit" "All unit tests"
  Write-Help-Footer
  exit 0
}

task Clean {
    delete_directory $build_dir
    create_directory $test_dir 
    create_directory $result_dir
  
    exec { msbuild /t:clean /v:q /P:VisualStudioVersion=12.0 /p:Configuration=$project_config $source_dir\$project_name.sln }
}

task CommonAssemblyInfo {
    create-commonAssemblyInfo "$release_number" $project_name "$source_dir\CommonAssemblyInfo.cs"
}

task Compile -depends Clean, CommonAssemblyInfo { 
    exec { msbuild.exe /t:build /v:q /p:VisualStudioVersion=12.0 /p:Configuration=$project_config /nologo $source_dir\$project_name.sln }
}

task GenerateNugetPackage{
    exec { msbuild.exe /t:build /p:RunOctoPack=true /v:q /p:VisualStudioVersion=12.0 /p:Configuration=$project_config /nologo /p:OctoPackPackageVersion=$release_number /p:OctoPackPublishPackageToFileShare=$output_package_dir $source_dir\$project_name.sln }
}

task CopyAssembliesForTest -Depends Compile {
    copy_all_assemblies_for_test $test_dir
}

task RunAllUnitTests -Depends CopyAssembliesForTest {
    $unit_test_dlls | %{ run_tests $_ }
}

# -------------------------------------------------------------------------------------------------------------
# generalized functions 
# --------------------------------------------------------------------------------------------------------------
function global:delete_directory($directory_name) {
  rd $directory_name -recurse -force  -ErrorAction SilentlyContinue | out-null
}

function global:create_directory($directory_name) {
  mkdir $directory_name  -ErrorAction SilentlyContinue  | out-null
}

function global:copy_and_flatten ($source,$include,$dest) {
  gci $source -include $include -r | cp -dest $dest
}

function global:copy_all_assemblies_for_test($destination) {
  $bin_dir_match_pattern = "$source_dir\**\bin\$project_config"

  create_directory $destination
  copy_and_flatten $bin_dir_match_pattern @("*.exe","*.dll","*.config","*.pdb","*.xml") $destination
}

function global:run_tests([string]$pattern) {
    $items = gci -Path $test_dir $pattern
    $items | %{ run_xunit $_.Name }
}

function global:run_xunit ($test_assembly) {
  $assembly_to_test = $test_dir + "\" + $test_assembly
  $results_output = $result_dir + "\" + $test_assembly + ".xml"
    write-host "Running XUnit Tests in: " $test_assembly
    exec { & $xunit_runner $assembly_to_test /silent /nunit $results_output }
}

function global:create-commonAssemblyInfo($version, $applicationName, $filename) {
  $year = (Get-Date).year 
  $copyright_symbol = [char]0x00A9

"using System.Reflection;

[assembly: AssemblyProduct(""$applicationName"")]

[assembly: AssemblyCompany(""Michael Wolfenden"")]
[assembly: AssemblyCopyright(""Copyright $copyright_symbol Michael Wolfenden $year"")]

#if DEBUG
[assembly: AssemblyConfiguration(""Debug"")]
#else
[assembly: AssemblyConfiguration(""Release"")]
#endif

[assembly: AssemblyVersion(""$version"")]
[assembly: AssemblyFileVersion(""$version"")]" | out-file $filename -encoding "utf8"
}

# -------------------------------------------------------------------------------------------------------------
# generalized functions added by Headspring for Help Section
# --------------------------------------------------------------------------------------------------------------
function global:write-help-header($description) {
  write-host ""
  write-host "********************************" -foregroundcolor DarkGreen -nonewline;
  write-host " HELP " -foregroundcolor Green  -nonewline; 
  write-host "********************************"  -foregroundcolor DarkGreen
  write-host ""
  write-host "This build script has the following common build " -nonewline;
  write-host "task " -foregroundcolor Green -nonewline;
  write-host "aliases set up:"
}

function global:write-help-section-header($description) {
  write-host ""
  write-host " $description" -foregroundcolor DarkGreen
}

function global:write-help-for-alias($alias,$description) {
  write-host "  > " -nonewline;
  write-host "$alias" -foregroundcolor Green -nonewline; 
  write-host " = " -nonewline; 
  write-host "$description"
}

function global:write-help-footer($description) {
  write-host ""
  write-host " For a complete list of build tasks, view default.ps1."
  write-host ""
  write-host "**********************************************************************" -foregroundcolor DarkGreen
}

