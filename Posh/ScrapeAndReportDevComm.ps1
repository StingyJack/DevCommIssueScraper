$Error.Clear()
Clear-Host
$ErrorActionPreference = 'STOP'

$_me = "Andrew Stanton"
$_myId = "3413"
$_maxDopListFetch = -1
$_numberOfIssuesNeedingMyUpdateToOpenInBrowser = 0
$_showNoNeedUpdateList = $false
$_reFetchList = $true


Add-Type -AssemblyName System.Web  #needed for link encoding


if ($_reFetchList -eq $true)
{
    Write-Host "Refetching list..."
    & "..\GetIssueDetails\GetIssueDetails\bin\Debug\GetIssueDetails.exe" "$_myId" $_maxDopListFetch
}

$file = @(Get-ChildItem -Path C:\temp -Filter "IssueList*.json" -File) | Sort-Object -Property Name -Descending | Select-Object -First 1
Write-Host "Selected $($file.FullName) for items"
$_outFile = [System.IO.Path]::ChangeExtension($file,"html")
$cssContent = Get-Content "$PSScriptRoot\issuelist.css"
$scriptContent = Get-Content "$PSScriptRoot\issueList.js"
Set-Content -Path $_outFile -Value "<doctype html><html><head><style>$cssContent</style></head><body>"

function Report
{
    Param(
        [parameter(Mandatory=$false, Position=1)][string] $Message,
        [parameter(Mandatory=$false)][object[]] $Collection,
        [parameter(Mandatory=$false)] [switch] $Embolden,
        [parameter(Mandatory=$false)] [string] $AnchorRef,
        [parameter(Mandatory=$false)] [string] $Anchor
    )

    if ([string]::IsNullOrWhiteSpace($Message) -eq $false)
    {
        $style = "style=`"`""
        if ($Embolden.IsPresent)
        {
            $style = "style=`"font-weight:bold`""
        }
        $eleStart = "<div class=`"textContainer`"><span $style>"
        $eleEnd = "</span></div>"

        if ([System.string]::IsNullOrWhiteSpace($AnchorRef) -eq $false)
        {
            $eleStart = "<a href=`"`#$AnchorRef`">$eleStart"
            $eleEnd = "$eleEnd</a>"
        }
        
        if ([System.string]::IsNullOrWhiteSpace($Anchor) -eq $false)
        {
            $eleStart = "<h5><a id=`"$Anchor`">"
            $eleEnd = "$eleEnd</a>&emsp;<a href=`"#`" onclick=`"history.go(-1)`">Go Back</a></h5>"
        }

        $addToTheStart = ""
        $addToTheEnd = ""

        $trimmedMessage = $Message
        $somethingOnTheEnds = ($trimmedMessage.StartsWith("`n") -or $trimmedMessage.StartsWith("`t") -or $trimmedMessage.EndsWith("`n") -or $trimmedMessage.EndsWith("`t"))
        while ($somethingOnTheEnds)
        {
            if ($trimmedMessage.StartsWith("`n"))
            {
                $addToTheStart += "<br>"
                $trimmedMessage = $trimmedMessage.Substring(1)
            }
            elseif ($trimmedMessage.EndsWith("`n"))
            {
                $addToTheEnd += "<br>"
                $trimmedMessage = $trimmedMessage.Substring(0, $trimmedMessage.Length -2)
            }
            elseif ($trimmedMessage.StartsWith("`t"))
            {
                $addToTheStart += "&emsp;"
                $trimmedMessage = $trimmedMessage.Substring(1)
            }
            elseif ($trimmedMessage.EndsWith("`t"))
            {
                $addToTheEnd += "&emsp;"
                $trimmedMessage = $trimmedMessage.Substring(0, $trimmedMessage.Length -2)
            }
            $somethingOnTheEnds = ($trimmedMessage.StartsWith("`n") -or $trimmedMessage.StartsWith("`t") -or $trimmedMessage.EndsWith("`n") -or $trimmedMessage.EndsWith("`t"))    
        }
        
        $replacedMessage = $trimmedMessage.Replace("`n", "<br>").Replace("`t", "&emsp;") #now on the inside
                

        Add-Content -Path $_outFile -Value ($addToTheStart + $eleStart + $replacedMessage + $eleEnd + $addToTheEnd + "<br>")

    }

    if ($null -ne $Collection -and $Collection.Length -gt 0)
    {
         $fragment = $Collection | ConvertTo-Html -Fragment -PreContent "<div class=`"tableContainer`">" -PostContent "</div>" 
         [System.Web.HttpUtility]::HtmlDecode($fragment) | Add-Content -Path $_outFile 
    }
}
Report "Report for open items executed on $(Get-Date)" -Embolden

$c = Get-Content $file.FullName -Raw
$allItems = ConvertFrom-Json $c 


$tagNew = "NEW"
$tagClosed = "CLOSED"
$tagTriaged = "PERMA TRIAGE"
$tagPendingRelease = "PENDING RELEASE"
$tagRegression = "REGRESSION"
$tagWaitingForResponse = "WFR"
$statusUnderConsideration = "Under Consideration"
$statusUnderInvestigation = "Under Investigation"
$statusTriaged = "Triaged"

Report "There are $($allItems.Count) items in 'My Followed Items' list"

$UPDATE_TYPE_NEEDS_NO_UPDATE = "NeedsNoUpdate"
$UPDATE_TYPE_NEEDS_UPDATE_BY_ME = "NeedsUpdateByMe"
$UPDATE_TYPE_NEEDS_TAGGING_BY_ME = "NeedsTaggingByMe"
$UPDATE_TYPE_NEEDS_UPDATE_BY_MSFT = "NeedsUpdateByMsft"


function Get-UpdateType
{
    [CmdletBinding()]
    [OutputType([System.string])]
    Param(
        [PSObject] $item
    )

    if ($item.Author -ine $_me)
    {
        return $UPDATE_TYPE_NEEDS_NO_UPDATE
    }

    if ($item.LastUpdatedBy -eq "Marsha Robertson" -and$item.IssueNum -eq 148909) #me2
    {
        return $UPDATE_TYPE_NEEDS_NO_UPDATE
    }

    if ([System.String]::IsNullOrWhiteSpace($item.MyTag))
    {
        return $UPDATE_TYPE_NEEDS_TAGGING_BY_ME
    }

    if ($item.MyTag.IndexOf($tagClosed, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) 
    { 
        return $UPDATE_TYPE_NEEDS_NO_UPDATE
    }

    if ($item.MyTag.IndexOf($tagPendingRelease, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) 
    { 
        return $UPDATE_TYPE_NEEDS_NO_UPDATE
    }    
    
    if ($item.MyTag.IndexOf($tagTriaged, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -and $item.Status -ine $statusTriaged) 
    { 
        return $UPDATE_TYPE_NEEDS_UPDATE_BY_ME
    }

    if ($item.MyTag.IndexOf($tagTriaged, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) 
    { 
        return $UPDATE_TYPE_NEEDS_UPDATE_BY_MSFT
    }

    if ($item.MyTag.IndexOf($tagRegression, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) 
    { 
        return $UPDATE_TYPE_NEEDS_UPDATE_BY_MSFT
    }
    
    if ($item.Status -ieq $statusUnderInvestigation)
    {
        return $UPDATE_TYPE_NEEDS_UPDATE_BY_MSFT
    }    

    if ((($item.MyTag -ieq $tagNew) -or ($item.MyTag -ieq $tagWaitingForResponse)) -and ($item.LastUpdatedBy -ne $_me))
    { 
        return $UPDATE_TYPE_NEEDS_UPDATE_BY_ME
    }

    if ((($item.MyTag -ieq $tagNew) -or ($item.MyTag -ieq $tagWaitingForResponse)) -and ($item.Status -ieq $statusUnderConsideration))
    { 
        return $UPDATE_TYPE_NEEDS_UPDATE_BY_MSFT
    }

    if ($item.LastUpdatedBy -ieq $_me) 
    { 
        return $UPDATE_TYPE_NEEDS_UPDATE_BY_MSFT
    }
    
    return $UPDATE_TYPE_NEEDS_UPDATE_BY_ME
}

$needUpdateFromMe = @()
$needTaggingFromMe = @()
$needUpdateFromMsft = @()
$needsNoUdpates = @()

foreach ($item in $allItems)
{
  
    $updateType = Get-UpdateType $item

    if ($updateType -eq $UPDATE_TYPE_NEEDS_NO_UPDATE) 
    {
        $needsNoUdpates += $item
        continue
    }   
    elseif ($updateType -eq $UPDATE_TYPE_NEEDS_UPDATE_BY_ME) 
    {
        $needUpdateFromMe += $item
        continue
    }   
    elseif ($updateType -eq $UPDATE_TYPE_NEEDS_TAGGING_BY_ME) 
    {
        $needTaggingFromMe += $item
        continue
    }   
    elseif ($updateType -eq $UPDATE_TYPE_NEEDS_UPDATE_BY_MSFT) 
    {
        $needUpdateFromMsft += $item
        continue
    }   
}

<#
$filters = @()
$filters += @{Text='There are $($filtered.Count) items I have authored out of $($allItems.Count) items';
            SourceCollection=$allItems;
            Filter={$_.Author -ieq $_me};
            SortProperty='IssueNum'}
$filters +=@{Text='There are $($filtered.Count) items that need an update from me';
            Filter={[System.String]::IsNullOrWhiteSpace($_.MyTag) -eq $false -and ($_.MyTag.Equals("CLOSED", [System.StringComparison]::OrdinalIgnoreCase) -or $_.MyTag.Equals("CLOSED MOVED", [System.StringComparison]::OrdinalIgnoreCase) )};
            SortProperty='LastUpdatedDate'}

$anchorCount = 0

$filteredResults = @()

foreach ($filter in $filters)
{
    $anchorCount++
    $selectProperties = {IssueNum,MyTag,Status,LastUpdatedDate,LastUpdatedBy,@{Label=`"Issue Title/Link`";Expression={`"<a href='$($_.IssueLink)' target='_blank'>$($_.Title)</a>`"}}}
    if ($filter | Get-Member -Name SelectProperties)
    {
        $selectProperties = $filter.SelectProperties
    }
    $filtered = @($filter.SourceCollection | Where-Object $filter.Filter | Select-Object -Property $selectProperties)
    $unfurledText = $ExecutionContext.InvokeCommand.ExpandString($filter.Text)
    $anchorName = "Anchor_$anchorCount"
    Report -Message $unfurledText -AnchorRef $anchorName -Embolden:($filtered.Count -gt 0)

    $filteredResults += @{AnchorName=$anchorName;FilteredCollection=$filtered}
}

Report "`n`n"

foreach ($filteredResult in $filteredResults)
{
    Report -Collection $filteredResult.FilteredCollection -Anchor $filteredResult.AnchorName
}
#>

$myIssues = @($allItems | Where-Object {$_.Author -ieq $_me})
$itemsIConsiderClosed = @($myIssues | Where-Object {[System.String]::IsNullOrWhiteSpace($_.MyTag) -eq $false -and ($_.MyTag.Equals("CLOSED", [System.StringComparison]::OrdinalIgnoreCase) -or $_.MyTag.Equals("CLOSED MOVED", [System.StringComparison]::OrdinalIgnoreCase) )})
$itemsIDontFeelLikeArguingAbout = @($myIssues | Where-Object {[System.String]::IsNullOrWhiteSpace($_.MyTag) -eq $false -and ($_.MyTag.IndexOf("UNRESOLVED", [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or $_.MyTag.Equals("CLOSED NOT FIXED", [System.StringComparison]::OrdinalIgnoreCase) )})
$itemsMsftConsidersClosed = @($myIssues | Where-Object {$_.Status.IndexOf("Closed", [System.StringComparison]::OrdinalIgnoreCase) -ge 0})
$itemsRecentlyUpdatedBySomeoneElse = @($myIssues | Where-Object {$_.LastUpdatedBy -ine $_me -and $_.LastUpdatedDate -le (Get-Date).AddDays(-14)})
$triageItems = @($myIssues | Where-Object {([System.String]::IsNullOrWhiteSpace($_.MyTag) -eq $false -and ($_.MyTag.Equals("PERMA TRIAGE" , [System.StringComparison]::OrdinalIgnoreCase)) -or $_.Status -ieq "Triaged") })
$itemsByMsftStatus = @($myIssues | Group-Object -Property Status | Sort-Object -Property Count -Descending)
$itemsByMyTag = @($myIssues | Group-Object -Property MyTag | Sort-Object -Property Count -Descending)


Report "There are $($myIssues.Count) items I've authored of $($allItems.Count) total followed" -AnchorRef "issueListAllMine"
Report "There are $($needUpdateFromMe.Count) items that need an update from me" -Embolden:($needUpdateFromMe.Count -gt 0) -AnchorRef "issueListItemsNeedMyUpdate"
Report "There are $($needTaggingFromMe.Count) items that need tagging by me" -Embolden:($needTaggingFromMe.Count -gt 0) -AnchorRef "issueListNeedsTaggingFromMe"
Report "There are $($needUpdateFromMsft.Count) items that need an update from MSFT" -Embolden:($needUpdateFromMsft.Count -gt 0) -AnchorRef "issueListItemsNeedMsftUpdate"
Report "There are $($triageItems.Count) items that are still Traiaged (or [PERMA TRIAGE])" -AnchorRef "issueListItemsPermaTriage"
Report "There are $($needsNoUdpates.Count) items that need no update" -AnchorRef "issueListItemsNeedNoUpdate"
Report "Items I consider closed $($itemsIConsiderClosed.Count)" -Embolden:($itemsIConsiderClosed.Count -gt 0)
Report "Items MSFT considers closed $($itemsMsftConsidersClosed.Count)" -Embolden:($itemsMsftConsidersClosed.Count -gt 0)
Report "Items I dont feel like arguing about $($itemsIDontFeelLikeArguingAbout.Count)" -Embolden:($itemsIDontFeelLikeArguingAbout.Count -gt 0)
Report "Count of items by 'Status'" -Embolden -AnchorRef "issueListItemsByStatus"
foreach ($msftStatusGroup in $itemsByMsftStatus)
{
    Report "`t$($msftStatusGroup.Count) : $($msftStatusGroup.Name)" -AnchorRef "itemByStatus$($msftStatusGroup.Name.Replace(`" `", `"`").Replace(`"-`", `"`"))"
}

Report "Count of items by 'my tag'" -Embolden -AnchorRef "issueListItemsByMyTag"
foreach ($myTagGroup in $itemsByMyTag)
{
    Report "`t$($myTagGroup.Count) : $($myTagGroup.Name)" -AnchorRef "itemByMyTagGroup$($myTagGroup.Name.Replace(`" `", `"`").Replace(`"-`", `"`"))"
}


Report "`n-------------------Issue Lists-------------------------`n`n`n" -Embolden

Report  "Items that do require tagging `n`t $($needTaggingFromMe.Count) items to display" -Embolden -Anchor "issueListNeedsTaggingFromMe"
if ($needTaggingFromMe.Count -gt 0)
{
    Report -collection @($needTaggingFromMe | Select-Object -Property IssueNum,MyTag,Status,@{Label="LastUpdatedDate";Expression={(Get-Date $_.LastUpdatedDate).ToString("yyyy-MM-dd")}},LastUpdatedBy,@{Label="Issue Title/Link";Expression={"<a href='$($_.IssueLink)' target='_blank'>$($_.Title)</a>"}})
}

Report  "Items that do require an update from me `n`t $($needUpdateFromMe.Count) items to display" -Embolden -Anchor "issueListItemsNeedMyUpdate"
if ($needUpdateFromMe.Count -gt 0)
{
    Report -collection @($needUpdateFromMe | Select-Object -Property IssueNum,MyTag,Status,@{Label="LastUpdatedDate";Expression={(Get-Date $_.LastUpdatedDate).ToString("yyyy-MM-dd")}},LastUpdatedBy,@{Label="Issue Title/Link";Expression={"<a href='$($_.IssueLink)' target='_blank'>$($_.Title)</a>"}} | Sort-Object -Property Tag)
}

Report  "Items that are in triage state  `n`t $($triageItems.Count) items to display" -Embolden -Anchor "issueListItemsPermaTriage"
if ($triageItems.Count -gt 0)
{
    Report -collection @($triageItems | Select-Object -Property IssueNum,MyTag,Status,DaysSinceOpen,DaysSinceLastUpdated,LastUpdatedBy, @{Label="Issue Title/Link";Expression={"<a href='$($_.IssueLink)' target='_blank'>$($_.Title)</a>"}} | Sort-Object -Property DaysSinceOpen -Descending)
}

Report "Items that require an update from MSFT `n`t $($needUpdateFromMsft.Count) items to display" -Embolden -Anchor "issueListItemsNeedMsftUpdate"
if ($needUpdateFromMsft.Count -gt 0)
{
    Report -collection @($needUpdateFromMsft | Select-Object -Property IssueNum,MyTag,Status,@{Label="LastUpdatedDate";Expression={(Get-Date $_.LastUpdatedDate).ToString("yyyy-MM-dd")}},LastUpdatedBy,DaysSinceLastUpdated,@{Label="Issue Title/Link";Expression={"<a href='$($_.IssueLink)' target='_blank'>$($_.Title)</a>"}} | Sort-Object -Property DaysSinceLastUpdated -Descending)
}

Report "Items that do not require an update from anyone `n`t $($needsNoUdpates.Count) items to display" -Anchor "issueListItemsNeedNoUpdate"
if ($needsNoUdpates.Count -gt 0 -and $_showNoNeedUpdateList -eq $true)
{
    Report -collection ($needsNoUdpates | Select-Object -Property IssueNum,MyTag,Status,@{Label="LastUpdatedDate";Expression={(Get-Date $_.LastUpdatedDate).ToString("yyyy-MM-dd")}},LastUpdatedBy,Author,@{Label="Issue Title/Link";Expression={"<a href='$($_.IssueLink)' target='_blank'>$($_.Title)</a>"}} | Sort-Object -Property Tag)
}


Report "My issues `n`t $($myIssues.Count) items to display" -Anchor "issueListAllMine"
if ($myIssues.Count -gt 0)
{
    Report -collection @($myIssues| Select-Object -Property IssueNum,MyTag,Status,@{Label="LastUpdatedDate";Expression={(Get-Date $_.LastUpdatedDate).ToString("yyyy-MM-dd")}},LastUpdatedBy,Author,@{Label="Issue Title/Link";Expression={"<a href='$($_.IssueLink)' target='_blank'>$($_.Title)</a>"}} | Sort-Object -Property Tag)
}


Report "There are $($itemsByMsftStatus.Count) different msft statuses" 
foreach($msftStatusGroup in $itemsByMsftStatus)
{
    Report "Status $($msftStatusGroup.Name)" -Anchor "itemByStatus$($msftStatusGroup.Name.Replace(`" `", `"`").Replace(`"-`", `"`"))"
    Report -Collection @($msftStatusGroup.Group | Select-Object -Property IssueNum,MyTag,Status,@{Label="LastUpdatedDate";Expression={(Get-Date $_.LastUpdatedDate).ToString("yyyy-MM-dd")}},LastUpdatedBy,@{Label="Issue Title/Link";Expression={"<a href='$($_.IssueLink)' target='_blank'>$($_.Title)</a>"}})
}

Report "There are $($itemsByMyTag.Count) different Tags of mine" 
foreach($tagGroup in $itemsByMyTag)
{
    Report "Status $($tagGroup.Name)" -Anchor "itemByMyTagGroup$($tagGroup.Name.Replace(`" `", `"`").Replace(`"-`", `"`"))"
    Report -Collection @($tagGroup.Group | Select-Object -Property IssueNum,MyTag,Status,@{Label="LastUpdatedDate";Expression={(Get-Date $_.LastUpdatedDate).ToString("yyyy-MM-dd")}},LastUpdatedBy,@{Label="Issue Title/Link";Expression={"<a href='$($_.IssueLink)' target='_blank'>$($_.Title)</a>"}})
}


if ($_numberOfIssuesNeedingMyUpdateToOpenInBrowser -gt 0 -and ($needUpdateFromMe.Count -gt 0 -or $needTaggingFromMe.Count -gt 0))
{
    $openToEdit = @($needUpdateFromMe| Select-Object -First $_numberOfIssuesNeedingMyUpdateToOpenInBrowser)
    $openDiff = $_numberOfIssuesNeedingMyUpdateToOpenInBrowser - $openToEdit.Count
    $needTaggingFromMe | Select-Object -First $openDiff | ForEach-Object {$openToEdit += $_}
    $openToEdit | ForEach-Object {Start-Process -FilePath $_.IssueLink }
}

$issuesJson = ConvertTo-Json -InputObject $myIssues
Add-Content -Path $_outFile -Value "</body><script>$scriptContent</script><script> const myIssues = $issuesJson </script></html>"
Invoke-Item $_outFile


<#
#list of all topics (tag list)

$topics = @()
97..122 | ForEach-Object {$char = [char]$_; $topics += ((iwr -uri "https://developercommunity.visualstudio.com/search/topics.json?q=$char").Content | ConvertFrom-Json).topics.name}
$topics

#>
