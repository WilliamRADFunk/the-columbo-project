param(
    [ValidateSet("csv", "json", IgnoreCase = $true)]
    [Parameter(
        Mandatory=$false,
        HelpMessage="The type of file to write the output into (*.csv, *.json)",
        ParameterSetName="csv"
    )]
    [string]$OutputType
)

$suspects = @(
    [PSCustomObject]@{
        Name="msportalfx-mock";
        Url="https://github.com/Azure/msportalfx-mock.git";
    }
);

$startingDir = Get-Location;

# Clones all the listed repositories so 'git blame' and other history commands can be run on them.
foreach($suspect in $suspects) {
    Write-Host " "
    Write-Host "Bringing in '$($suspect.Name)' for questioning..." -ForegroundColor "Green";
    Write-Host " "

    git clone $($suspect.Url);
}

# Creates the suspects folder if it doesn't already exist.
Write-Host "Preparing for the suspect line up." -ForegroundColor "Green";
$FolderName = "$($startingDir)\suspects";
$PathTest = Test-Path -Path $FolderName;
if ($PathTest) {
    # Suspects folder already exists.
} else {
    New-Item $FolderName -ItemType Directory
}
Write-Host "Suspect line up is prepared." -ForegroundColor "Green";

# Analyzes each repository for code ownership file by file and then puts results in a separate json file.
foreach($suspect in $suspects) {
    Write-Host " "
    Write-Host "Finding out what '$($suspect.Name)' knows about the murder..." -ForegroundColor "Green";
    Write-Host " "

    .\Get-TheClues.ps1 -PathToRoot ".\$($suspect.Name)" -OutputType "json" -OutputFileName "suspects\$($suspect.Name)";
}

# Delete all the cloned repositories.
foreach($suspect in $suspects) {
    Write-Host " "
    Write-Host "Letting '$($suspect.Name)' go...for now (tell them not to leave town)." -ForegroundColor "Green";
    Write-Host " "

    Remove-Item -Path ".\$($suspect.Name)" -Recurse -Force;
}