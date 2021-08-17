function Get-GithubCredential {
  if ($Script:GithubCredentials) {
    return $Script:GithubCredentials
  }
  else {
    $Script:GithubCredentials = Get-Credential -Message "Enter your github credentials"
    return $Script:GithubCredentials
  }
}

function Get-GithubAuthenticationHeader {
  $Headers = @{ }
  if ($ENV:GITHUB_TOKEN) {
    Write-Log -Level Debug -Source 'github' -Message "Setting github token for authentication"
    $headers.Authorization = "token $ENV:GITHUB_TOKEN"
  }
  else {
    Write-Log -Level Debug -Source 'github' -Message "Setting username/password for authentication"
    $cred = Get-GithubCredential
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $cred.username, $cred.GetNetworkCredential().password)))
    $headers.Authorization = ("Basic {0}" -f $base64AuthInfo)
  }
  return $headers
}

function Invoke-GithubApi {

  param(
    [String]
    $Endpoint,
    [String]
    $Query,
    [String]
    [ValidateSet('GET', 'DELETE', 'POST')]
    $Method = 'GET',
    [Hashtable]
    $Headers = @{'accept' = 'application/json' },
    [String]
    $Body = "{}",
    [String]
    $ApiRoot = $ENV:GITHUB_API_ROOT
  )
  Write-Log -Level Debug -Source 'github' -Message "Getting Authentication header"
  $AuthHeader = Get-GithubAuthenticationHeader
  $headers.add('Authorization', $AuthHeader.Authorization)


  if ($method -eq 'GET') {
    if ($query) {
      Write-Log -Level INFO -Source 'github' -Message "Adding Query $query to GET call"
      $queryString = "?$query&per_page=1000"
    }

    # If this is a paginated response we need to walk it
    Write-Log -Level INFO -Source 'github' -Message "Making initial $method call to find out response information https://$apiRoot/$endpoint$queryString"
    $response = Invoke-WebRequest -Method $method -Uri "https://$apiRoot/$endpoint$queryString" -Headers $headers -UseBasicParsing -ErrorAction Stop
    $items = ConvertFrom-Json $response.Content

    if ($response.RelationLink.next) {
      Write-Log -Level INFO -Source 'github' -Message "Response is Paginated, getting all results"
      return $items.items + (Get-GithubApiPaginatedResponse -uri $response.RelationLink.next -Headers $Headers -ErrorAction Stop)
    }
    # We use an index here due to how diff powershell object behave
    # elseif ($responseContent.items[0]) {
    #   Write-Log -Level INFO -Source 'github' -Message "Result has an items property, returning only the items"
    #   return $responseContent.items
    # }
    else {
      Write-Log -Level INFO -Source 'github' -Message "Returning results object"

      # $items can be 1 of 3 things:
      # an array or a single item -> we want it
      # an objects with an array of items -> we want the items
      # Testing on $item.items first doesn't work as sometimes there's a special property with the wrong values
      if($items -is [array]) {
        return $items
      }
      if($items.items) {
        return $items.items
      }
      return $items
    }
  }
  else {
    Write-Log -Level INFO -Source 'github' -Message "Invoking a $method against github api"
    Write-Log -Level DEBUG -Source 'github' -Message "https://$apiRoot/$endpoint"
    Write-Log -Level DEBUG -Source 'github' -Message "$body"
    return  Invoke-RestMethod -Method $method -Uri "https://$apiRoot/$endpoint" -Headers $headers -body $body -UseBasicParsing -ErrorAction Stop
  }
}

function Get-GithubApiPaginatedResponse {
  param(
    [String]
    $uri,
    [Hashtable]
    $Headers = @{'accept' = 'application/json' }
  )
  $response = Invoke-WebRequest -Method 'GET' -Uri $uri -Headers $headers -UseBasicParsing -ErrorAction Stop
  $responseJson = ($response.content | ConvertFrom-Json)
  if ($responseJson.GetType().BaseType.Name -eq 'Array') {
      $responseItems = $responseJson
  }
  else {
    $responseItems = $responseJson.items
  }
  if ($response.RelationLink.next) {
    Write-Log -Level INFO -Source 'github' -Message "Getting next page of items"
    $responseItems += Get-GithubApiPaginatedResponse -uri $response.RelationLink.next -Headers $Headers
  }
  return $responseItems
}

function Get-GithubRepository {
  param(
    [String]
    $Owner,
    [String]
    $Repo
  )
  Write-Log -Level INFO -Source 'github' -Message "Getting repo information for $owner/$repo"
  return Invoke-GithubApi -Endpoint "repos/$owner/$repo" -Method GET -ErrorAction Stop
}

function Get-GithubRepositorySearchResults {
  param(
    [String]
    $Query,
    [String]
    [ValidateSet('best-match', 'stars', 'forks', 'help-wanted-issues')]
    $Sort = 'best-match',
    [String]
    [ValidateSet('desc', 'asc')]
    $Order = 'desc'
  )
  Write-Log -Level INFO -Source 'github' -Message "Getting search results for q=$Query&sort=$Sort&order=$Order"
  return Invoke-GithubApi -Endpoint 'search/repositories' -Query "q=$Query&sort=$Sort&order=$Order" -ErrorAction Stop
}

function New-GithubBranch {
  param(
    [String]
    $owner,
    [String]
    $repo,
    [String]
    $BranchName,
    [String]
    $BranchFromName
  )

  Write-Log -Level INFO -Source 'github' -Message "Checking if $owner/$repo already has a branch $BranchName to update against"
  if (Get-GithubBranch -owner $owner -repo $repo -branchFilterName $BranchName) {
    Write-Log -Level INFO -Source 'github' -Message "$owner/$repo already has a branch $BranchName, skipping creation"
    # Branch already exists
    return $null
  }

  else {
    Write-Log -Level INFO -Source 'github' -Message "Creating $BranchName for $owner/$repo"
    Write-Log -Level INFO -Source 'github' -Message "Getting information from branch from target: $branchFromName in $owner/$repo"
    $branchFromInfo = Get-GithubBranch -owner $owner -repo $repo -branchFilterName $BranchFromName
    $branchFromSha = $branchFromInfo.object.sha

    $bodyNewBranch = @{
      "ref" = "refs/heads/$branchName";
      "sha" = "$branchFromSha"
    }
    $bodyNewBranchJson = ConvertTo-Json $bodyNewBranch
    Write-Log -Level INFO -Source 'github' -Message "Sending call to Create $BranchName for $owner/$repo from $branchFromTarget"
    return Invoke-GithubApi -Endpoint "repos/$owner/$repo/git/refs" -Method POST -Body $bodyNewBranchJson -ErrorAction Stop
  }
}

function Get-GithubBranch {
  param(
    [String]
    $owner,
    [String]
    $repo,
    [String]
    $branchFilterName
  )
  Write-Log -Level INFO -Source 'github' -Message "Getting Current branches for $owner/$repo"
  $currentBranches = Invoke-GithubApi -Endpoint "repos/$owner/$repo/git/refs/heads" -Method GET -ErrorAction Stop

  # Add name properties
  foreach ($branch in $currentBranches) {
    Write-Log -Level INFO -Source 'github' -Message "Working on $branch"
    $branchName = $branch.ref.replace('refs/heads/', '')
    Write-Log -Level INFO -Source 'github' -Message "Setting a Branch Name"
    $branch | Add-Member -MemberType NoteProperty -Name "name" -Value $branchName
  }
  if ($branchFilterName) {
    Write-Log -Level INFO -Source 'github' -Message "Filter $branchFilerName is specified, returning filtered results"
    return $currentBranches | Where-Object { $_.name -eq $branchFilterName }
  }
  else {
    Write-Log -Level INFO -Source 'github' -Message 'No filter is specified, returning all results'
    return $currentBranches
  }
}

function Get-GithubPullRequests {
  param(
    [String]
    $owner,
    [String]
    $repo,
    [Parameter()]
    [ValidateSet('Open', 'Closed', 'All')]
    [string]
    $State = 'Open',
    [Parameter()]
    [string]
    $Head,
    [Parameter()]
    [string]
    $Base
  )
  $query = "state=$state"
  if ($head) {
    Write-Log -Level INFO -Source 'github' -Message "Setting head filter: $head"
    if ($Head -notlike '*:*') {
      Write-Log -Level Error -Source 'github' -Message "Owner $owner is not set on HEAD, it will not be filtered, it should be owner:repo"
    }
    $query += "&head=$head"
  }
  if ($base) {
    $query += "&base=$base"
  }

  Write-Log -Level INFO -Source 'github' -Message "Checking current Open PRs against $owner/$repo with $query"
  $PullRequests = Invoke-GithubApi -Endpoint "repos/$owner/$repo/pulls" -Method GET -Query $query -ErrorAction Stop

  return $PullRequests
}

function New-GithubPullRequest {
  param(
    [String]
    $owner,
    [String]
    $repo,
    [String]
    $Head,
    [String]
    $Base,
    [String]
    $title,
    [String]
    $body
  )

  Write-Log -Level INFO -Source 'github' -Message "Checking if PR is already open"
  if (Get-GithubPullRequests -repo $repo -owner $owner -Head $Head -base $Base -state Open) {
    # PR already open, return null
    Write-Log -Level INFO -Source 'github' -Message "PR is already open -skipping"
    return $null
  }
  else {
    Write-Log -Level INFO -Source 'github' -Message "Opening a PR, could not detect one"
    if ($Head -notlike '*:*') {
      Write-Log -Level Error -Source 'github' -Message "Owner $owner is not set on HEAD, PR cannot be created"
    }

    $bodyHash = @{
      title = $title;
      body  = $body;
      head  = $head;
      base  = $base;
    }

    Write-Log -Level INFO -Source 'github' -Message "$($body | convertto-json)"
    try
    {
      $bodyJson = ConvertTo-Json $bodyHash
    }
    catch
    {
      Write-Log -Level Error -Source 'github' -Message "Error converting $body to Json"
    }
    Write-Log -Level DEBUG -Source 'github' -Message "Creating PR with body $($bodyJson.toString())"
    return Invoke-GithubApi -Endpoint "repos/$owner/$repo/pulls" -Method POST -Body $bodyJson -ErrorAction Stop
  }
}


function Add-GithubIssueLabels {
  param(
    [String]
    $owner,
    [String]
    $repo,
    [Int]
    $issueId,
    [Array]
    $labels
  )

  Write-Log -Level INFO -Source 'github' -Message "Setting Labels $Labels on $owner/$repo : $issueID"
  $labelsJson = @{'labels' = $labels} | ConvertTo-Json

    return Invoke-GithubApi -Endpoint "repos/$owner/$repo/issues/$issueID/labels" -Method POST -Body $labelsJson -ErrorAction Stop
}


Export-ModuleMember *
