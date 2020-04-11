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
    $headers.Authorization = "token $ENV:GITHUB_TOKEN"
  }
  else {
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
    $ApiRoot = 'api.github.com'
  )

  $AuthHeader = Get-GithubAuthenticationHeader
  $headers.add('Authorization', $AuthHeader.Authorization)


  if ($method -eq 'GET') {
    if ($query) {
      $queryString = "?$query"
    }

    # If this is a paginated response we need to walk it
    $response = Invoke-WebRequest -Method $method -Uri "https://$apiRoot/$endpoint$queryString" -Headers $headers -UseBasicParsing
    if ($response.RelationLink.next) {
      return Get-GithubApiPaginatedResponse -uri "https://$apiRoot/$endpoint$queryString" -Headers $Headers
    }
    else {
      return Invoke-RestMethod -Method $method -Uri "https://$apiRoot/$endpoint$queryString" -Headers $headers -UseBasicParsing
    }
  }
  else {
    return  Invoke-RestMethod -Method $method -Uri "https://$apiRoot/$endpoint" -Headers $headers -body $body -UseBasicParsing
  }
}

function Get-GithubApiPaginatedResponse {
  param(
    [String]
    $uri,
    [Array]
    $responseItems = @(),
    [Hashtable]
    $Headers = @{'accept' = 'application/json' }
  )
  $response = Invoke-WebRequest -Method 'GET' -Uri $uri -Headers $headers -UseBasicParsing
  $responseItems += ($response.content | ConvertFrom-Json).items
  if ($response.RelationLink.next) {
    $responseItems += Get-GithubApiPaginatedResponse -uri $response.RelationLink.next
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

  return Invoke-GithubApi -Endpoint "repos/$owner/$repo" -Method GET
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
  return Invoke-GithubApi -Endpoint 'search/repositories' -Query "q=$Query&sort=$Sort&order=$Order"
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
    $BranchFromName = 'master'
  )


  if (Get-GithubBranch -owner $owner -repo $repo -branchFilterName $BranchName) {
    # Branch already exists
    return $null
  }

  else {
    $branchFromInfo = Get-GithubBranch -owner $owner -repo $repo -branchFilterName $BranchFromName
    $branchFromSha = $branchFromInfo.object.sha

    $bodyNewBranch = @{
      "ref" = "refs/heads/$branchName";
      "sha" = "$branchFromSha"
    }
    $bodyNewBranchJson = ConvertTo-Json $bodyNewBranch
    return Invoke-GithubApi -Endpoint "repos/$owner/$repo/git/refs" -Method POST -Body $bodyNewBranchJson
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

  $currentBranches = Invoke-GithubApi -Endpoint "repos/$owner/$repo/git/refs/heads" -Method GET

  # Add name properties
  foreach ($branch in $currentBranches) {
    $branchName = $branch.ref.replace('refs/heads/', '')
    $branch | Add-Member -MemberType NoteProperty -Name "name" -Value $branchName
  }
  if ($branchFilterName) {
    return $currentBranches | Where-Object { $_.name -eq $branchFilterName }
  }
  else {
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
    if ($Head -notlike '*:*') {
      Write-Error "Owner is not set on HEAD, it will not be filtered, it should be owner:repo"  -ErrorAction Stop
    }
    $query += "&head=$head"
  }
  if ($base) {
    $query += "&base=$base"
  }

  $PullRequests = Invoke-GithubApi -Endpoint "repos/$owner/$repo/pulls" -Method GET -Query $query

  return $PullRequests
}

function New-GithubPullRequest {
  param(
    [String]
    $owner,
    [String]
    $repo,
    [string]
    $Head,
    [string]
    $Base = 'master',
    [String]
    $title,
    [String]
    $body
  )

  if (Get-GithubPullRequests -repo $repo -owner $owner -Head $Head -base $Base -state Open) {
    # PR already open, return null
    return $null
  }
  else {
    if ($Head -notlike '*:*') {
      Write-Error "Owner is not set on HEAD, PR cannot be created" -ErrorAction Stop
    }

    $body = @{
      "title" = $title;
      "body" = $body;
      "head" = $head;
      "base" = $base;
     }

     return Invoke-GithubApi -ApiRoot "repos/$owner/$repo/pulls" -Method POST -Body $body
  }
}


Export-ModuleMember *
