param(
    [Parameter(
        Mandatory=$true,
        HelpMessage="Full path to root of the enlistment to analyze"
    )]
    [string]$PathToRoot,
    [ValidateSet("csv", "json", IgnoreCase = $true)]
    [Parameter(
        Mandatory=$false,
        HelpMessage="The type of file to write the output into (*.csv, *.json)",
        ParameterSetName="csv"
    )]
    [string]$OutputType,
    [Parameter(
        Mandatory=$false,
        HelpMessage="The name of the file to write the output into"
    )]
    [string]$OutputFileName
)

#
# Uses git blame to find all code changers throughout history and score them by number of lines and weighted by recency of those changes.
#

Function Get-Weights {
    param (
        [Parameter()]
        [string]$filePath,
        [Parameter()]
        [string]$fileName,
        [Parameter()]
        [string]$baseName
    )

    $revList = git rev-list HEAD -- $filePath;
    $hashtable = @{};
    $historyIteration = 1; # inverse of log10 on 1 is infinity

    foreach ($rev in $revList)
    {
        $historyIteration += 1;
        $weight = 1 / [System.Math]::log10($historyIteration);
        $item = git blame -l -L 1,+100000 $rev -- $filePath;

        $total = ([regex]::Matches($item, $rev)).count;
        $author = git log $rev -1 --format='%an';

        if ($hashtable.ContainsKey($author) -eq $False)
        {
            $hashtable[$author]=0;
        }
        
        $score = $weight * $total;
        $hashtable[$author] += $score;
    }

    $hashtabSorted = $hashtable.GetEnumerator() | Sort-Object -Property Value -Descending;

    $blameInstance = [PSCustomObject]@{
        FileName = $fileName;
        FilePathFromRoot = $filePath;
        Authors = @{};
    };

    foreach ($kvp in $hashtabSorted) {
        $roundedScore = [System.Math]::Round($kvp.Value);
        $blameInstance.Authors.Add($kvp.Key, $roundedScore);
    }

    return $blameInstance;
}

$startingDir = Get-Location;
Set-Location $PathToRoot;

#
# Cycling through all files in the enlistment from the provided root directory.
#

$blame = @{};
$rootDir = get-childitem "." -recurse;
$rootDirsFiltered = $rootDir |
    Where-Object {($_.FullName -like '*node_modules*') -eq $False} |
    Where-Object {($_.FullName -like '*\.*') -eq $False} |
    Where-Object  {($_.FullName -like '*\*.**') -eq $True};
$rootDirsFiltered | ForEach-Object {
    Write-Host "Analyzing: $($_.FullName) --- $($_.Name) --- $($_.BaseName)";
    $instance = Get-Weights -filePath $_.FullName -fileName $_.Name -baseName $_.BaseName;

    $key = $_.BaseName;
    if ($blame.ContainsKey($key) -eq $False) {
        $blame.Add($key, @{});
    }
    $blame[$key].Add($instance.FilePathFromRoot, $instance);
};

#
# Reformatting the data for export to different file types.
#

if ([string]::IsNullOrEmpty($OutputFileName) -eq $True) {
    $OutputFileName = "WhoDoneIt";
}

$entryList = @();

Write-Host " ";
foreach ($kvp1 in $blame.GetEnumerator()) {
    Write-Host "BaseName = $($kvp1.Key)";
    Write-Host " ";
    foreach ($kvp2 in $kvp1.Value.GetEnumerator()) {
        $relativePath = $kvp2.Value.FilePathFromRoot.Replace("$($startingDir)\","");
        foreach ($author in $kvp2.Value.Authors.GetEnumerator() | Sort-Object -Property Value -Descending) {
            $entry = [PSCustomObject]@{
                BaseName = $kvp1.Key;
                FileName = $kvp2.Value.FileName;
                FilePath = "$($relativePath)";
                Author = $author.Key;
                Score = $author.Value;
            };

            Write-Output $entry;
            $entryList += $entry;

            if ($OutputType -eq "csv") {
                $entry | Export-CSV "$($startingDir)\$($OutputFileName).csv" -Append -NoTypeInformation -Force;
            }
        }
        Write-Host " ";
    }
}

if ($OutputType -eq "json") {
    $jsonified = ConvertTo-Json -InputObject $entryList -Depth 100;
    $jsonified | Out-File "$($startingDir)\$($OutputFileName).json";
}

Set-Location $startingDir;
