Clear-Host

$_me = "Andrew Stanton"
$_searchText = @("sql")

$file = @(Get-ChildItem -Path C:\temp -Filter "IssueList*.json" -File) | Sort-Object -Property Name -Descending | Select-Object -First 1
$c = Get-Content $file.FullName -Raw

$allItems = ConvertFrom-Json $c

$tmpFile = [System.IO.Path]::GetTempFileName()
$tmpFile = [System.IO.Path]::ChangeExtension($tmpFile, "html")
$allItems | Select-Object -Property Tag,Status,LastUpdatedDate,Author,IssueLink | ConvertTo-Html -Fragment| Set-Content -Path $tmpFile

$results = @()
foreach ($item in $allItems)
{
    if ($item.Author -ine $_me)
    {
        continue
    }

    foreach($searchTerm in $_searchText)
    {
        if ($item.Title.IndexOf($searchTerm, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
        {
            $results += $item
            break
        }
    }

}

Write-Host "Found $($results.Count) results"
#$results | Select-Object -Property IssueNum,MyTag,Status,@{Label="LastUpdatedDate";Expression={(Get-Date $_.LastUpdatedDate).ToString("yyyy-MM-dd")}},LastUpdatedBy,Author,@{Label="Issue Title/Link";Expression={"<a href='$($_.IssueLink)' target='_blank'>$($_.Title)</a>"}}


if ($results.Count -ge 0 -and $results.Count -le 25)
{
    $openToEdit = $results| Select-Object -Property IssueNum,MyTag,Status, IssueLink
    $openToEdit | ForEach-Object {Start-Process -FilePath $_.IssueLink; Write-Output $_.IssueLink}
    
}