## what to do:

# Get and clone the source repository

# find all repos matching topics supplied

# clone, branch and pr if required

# close off

## Logging should be able to undertstand both file and std out

[CmdletBinding()]
param (
  [Parameter()]
  [String]
  [ValidateNotNullOrEmpty()]
  $SourceRepoOwner = $ENV:GFM_SOURCE_REPO_OWNER,
  [Parameter()]
  [String]
  [ValidateNotNullOrEmpty()]
  $SourceRepoName = $ENV:GFM_SOURCE_REPO_NAME,
  [Parameter()]
  [String]
  [ValidateNotNullOrEmpty()]
  $SourceRepoPath = $ENV:GFM_SOURCE_REPO_PATH,
  [Parameter()]
  [String]
  [ValidateNotNullOrEmpty()]
  $SourceRepoDeletePath = $ENV:GFM_SOURCE_REPO_DELETE_PATH,
  [String]
  [ValidateNotNullOrEmpty()]
  $DestinationRepoOwner = $ENV:GFM_DESTINATION_REPO_OWNER,
  [String]
  [ValidateNotNullOrEmpty()]
  $DestinationRepoTopicsCsv = $ENV:GFM_DESTINATION_REPO_TOPICS,
  [String]
  [ValidateNotNullOrEmpty()]
  $BranchName = $ENV:GFM_BRANCH_NAME,
  [String]
  [ValidateNotNullOrEmpty()]
  $PullRequestTitle = $ENV:GFM_PULL_REQUEST_TITLE,
  [String]
  [ValidateNotNullOrEmpty()]
  $PullRequestBody = $ENV:GFM_PULL_REQUEST_BODY,
  [String]
  $PullRequestLabels = $ENV:GFM_PULL_REQUEST_LABELS,
  [String]
  $GitName = $ENV:GFM_GIT_NAME,
  [String]
  $GitEmail = $ENV:GFM_GIT_EMAIL
)

try {
  import-module ./app/modules/fileHelpers
  import-module ./app/modules/github
  import-module ./app/modules/git
  import-module ./app/modules/logging

}
catch {
  Write-Error "Unable to import modules" -ErrorAction Stop
  exit 1
}

if (!($ENV:GITHUB_TOKEN)) {
  Write-Log -Level Error -Source 'entrypoint' -Message "No GITUB_TOKEN env var detected"
}
if (!($ENV:GITHUB_API_ROOT)) {
  Write-Log -Level INFO -Source 'entrypoint' -Message "GITHUB_API_ROOT has been set to api.github.com"
  $ENV:GITHUB_API_ROOT = 'api.github.com'
}
# Setup the git config first, if env vars are not supplied this will do nothing.
Set-GitConfig -gitName $GitName -gitEmail $GitEmail

try {
  Write-Log -Level Info -Source 'entrypoint' -Message "Getting repository information for $sourceRepoOwner/$sourceRepoName"
  $SourceRepo = Get-GithubRepository -owner $SourceRepoOwner -repo $SourceRepoName -errorAction Stop
}
catch {
  Write-Log -Level Error -Source 'entrypoint' -Message "Unable to get information about $sourceRepoOwner/$sourceRepoName"
}

try {
  Write-Log -Level Info -Source 'entrypoint' -Message "Setting up file paths for $sourceRepoOwner/$sourceRepoName"
  $SourceRepoCheckoutLocation = 'source-repo'
  $SourceRepoDiskPath = Join-Path $SourceRepoCheckoutLocation $SourceRepoPath
  Remove-PathIfExists -Path $SourceRepoCheckoutLocation
}
catch {
  Write-Log -Level Error -Source 'entrypoint' -Message "Unable to setup file paths for $sourceRepoOwner/$sourceRepoName"
}

if ($SourceRepo) {
  try {
    Write-Log -Level Info -Source 'entrypoint' -Message "Cloning $sourceRepoOwner/$sourceRepoName"
    New-GitClone -HttpUrl $SourceRepo.clone_url -Directory $SourceRepoCheckoutLocation
  }
  catch {
    Write-Log -Level Error -Source 'entrypoint' -Message "Unable to clone $sourceRepoOwner/$sourceRepoName"
  }
}
if (!(Test-Path $SourceRepoDiskPath)) {
  Write-Log -Level Error -Source 'entrypoint' -Message "Source Path for file management: $SourceRepoPath was not found"
}

Write-Log -Level Info -Source 'entrypoint' -Message "Finding all repositories in the destination"
$searchQuery = "org:$DestinationRepoOwner"
foreach ($topic in $DestinationRepoTopicsCsv.split(',')) {
  $searchQuery += " topic:$topic"
}
try {
  $DestinationRepositories = Get-GithubRepositorySearchResults -Query $searchQuery
}
catch {
  Write-Log -Level Error -Source 'entrypoint' -Message "Unable to find destination repositories for $searchQuery"
}

try {
  Write-Log -Level Info -Source 'entrypoint' -Message "Setting up file paths for $sourceRepoOwner/$sourceRepoName"
  $DestinationRepositoriesDiskLocation = 'destination-repos'
  Remove-PathIfExists $DestinationRepositoriesDiskLocation
  New-Item $DestinationRepositoriesDiskLocation -ItemType Directory
  $rootFolder = $pwd
}
catch {
  Write-Log -Level Error -Source 'entrypoint' -Message "Unable to setup file paths for $DestinationRepositoriesDiskLocation"
}
# Clone out each and every repository
foreach ($repository in $DestinationRepositories) {
  Set-Location $rootFolder
  Write-Log -Level Info -Source 'entrypoint' -Message "Starting processing on $($repository.name)"
  # Clone and setup folder tracking
  $repoFolder = Join-Path $DestinationRepositoriesDiskLocation $repository.name
  try {
    Write-Log -Level Info -Source 'entrypoint' -Message "Cloning $DestinationRepositoriesDiskLocation/$($repository.name)"
    New-GitClone -HttpUrl $repository.clone_url -Directory "$DestinationRepositoriesDiskLocation/$($repository.name)"
  }
  catch {
    Write-Log -Level Error -Source 'entrypoint' -Message "Unable to clone $sourceRepoOwner/$sourceRepoName"
  }

try {
  $branchExists = Get-GithubBranch -repo $repository.name -owner $DestinationRepoOwner -branchFilterName $BranchName
  if ($branchExists) {
    Write-Log -Level INFO -Source 'entrypoint' -Message "Branch $branchName already exists, switching to it"
    Set-Location $repoFolder
    Select-GitBranch -BranchName $BranchName
    Set-Location $rootFolder
  }
}
catch {
  Write-Log -Level Error -Source 'entrypoint' -Message "Unable to check if branch $branchName already exists"
}


  try {
    Write-Log -Level INFO -Source 'entrypoint' -Message "Copying managed files from $SourceRepoDiskPath to $repoFolder"
    # Copy items into the folder
    copy-item "$SourceRepoDiskPath/*" ./$repoFolder -Recurse -Force
    Set-Location $repoFolder
  }
  catch {
    Write-Log -Level Error -Source 'entrypoint' -Message "Unable to copy managed files from $SourceRepoDiskPath to $repoFolder"
  }
  try {
    Write-Log -Level INFO -Source 'entrypoint' -Message "Copying managed files from $SourceRepoDiskPath to $repoFolder"
    # Copy items into the folder
    copy-item "$SourceRepoDiskPath/*" ./$repoFolder -Recurse -Force
    Set-Location $repoFolder
  }
  catch {
    Write-Log -Level Error -Source 'entrypoint' -Message "Unable to copy managed files from $SourceRepoDiskPath to $repoFolder"
  }
  try {
  $filesChanged = Get-GitChangeCount
  }
  catch {
    Write-Log -Level Error -Source 'entrypoint' -Message "Unable to count changed files in git"
  }
  if ($filesChanged -gt 0)
  {
    try {
      if (!($branchExists))
      {
        Write-Log -Level INFO -Source 'entrypoint' -Message "Creating branch $BranchName as it does not already exist"
        New-GithubBranch -repo $repository.name -owner $DestinationRepoOwner -BranchName $BranchName -BranchFromName 'master'
        Select-GitBranch -BranchName $BranchName
      }
    }
    catch {
      Write-Log -Level Error -Source 'entrypoint' -Message "Unable to create branch $BranchName"
    }

    # Commit the files that have changed
    try {
      Write-Log -Level INFO -Source 'entrypoint' -Message "Commiting standardised files and pushing to remote if changed"
      New-CommitAndPushIfChanged -CommitMessage "Standardise files with files in $SourceRepoOwner/$SourceRepoName" -push
    }
    catch {
      Write-Log -Level ERROR -Source 'entrypoint' -Message "Unable to commit standardised files and push to remote if changed"
    }
    try {
      Write-Log -Level INFO -Source 'entrypoint' -Message "Opening Pull Request $PullRequestTitle with body of $PullRequestBody"
      New-GithubPullRequest -owner $DestinationRepoOwner -Repo $repository.name -Head "$($DestinationRepoOwner):$($BranchName)" -base 'master' -title $PullRequestTitle -body $PullRequestBody
    }
    catch {
      Write-Log -Level ERROR -Source 'entrypoint' -Message "Unable to open Pull Request $PullRequestTitle with body of $PullRequestBody"
    }
  }
  else {
    Write-Log -Level INFO -Source 'entrypoint' -Message "No file changes to process"
  }
}
