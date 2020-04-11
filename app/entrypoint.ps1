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
  import-module ./app/modules/github
  import-module ./app/modules/git
  import-module ./app/modules/fileHelpers
}
catch {
  Write-Error "Unable to import modules" -ErrorAction Stop
}

if (!($ENV:GITHUB_TOKEN)) {
  Write-Error "No GITUB_TOKEN env var detected" -ErrorAction Stop
}

# Setup the git config first, if env vars are not supplied this will do nothing.
Set-GitConfig -gitName $GitName -gitEmail $GitEmail

$SourceRepo = Get-GithubRepository -owner $SourceRepoOwner -repo $SourceRepoName -errorAction Stop

$SourceRepoCheckoutLocation = 'source-repo'
$SourceRepoDiskPath = Join-Path $SourceRepoCheckoutLocation $SourceRepoPath
Remove-PathIfExists -Path $SourceRepoCheckoutLocation
if ($SourceRepo)
{
  New-GitClone -SshUrl $SourceRepo.ssh_url -Directory $SourceRepoCheckoutLocation
}
if (!(Test-Path $SourceRepoDiskPath)) {
  Write-Error "Source Path for file management: $SourceRepoPath was not found" -ErrorAction Stop
}

$searchQuery = "org:$DestinationRepoOwner"
foreach ($topic in $DestinationRepoTopicsCsv.split(','))
{
  $searchQuery += " topic:$topic"
}

$DestinationRepositories = Get-GithubRepositorySearchResults -Query $searchQuery

$DestinationRepositoriesDiskLocation = 'destination-repos'
Remove-PathIfExists $DestinationRepositoriesDiskLocation
New-Item $DestinationRepositoriesDiskLocation -ItemType Directory
$rootFolder = $pwd
# Clone out each and every repository
foreach ($repo in $DestinationRepositories){
  # Clone and setup folder tracking
  $repoFolder = Join-Path $DestinationRepositoriesDiskLocation $repo.name
  New-GitClone -SshUrl $repo.ssh_url -Directory "$DestinationRepositoriesDiskLocation/$($repo.name)"
  New-GithubBranch -repo $repo.name -owner $DestinationRepoOwner -BranchName $BranchName -BranchFromName 'master'
  Set-Location $repoFolder
  Select-GitBranch -BranchName $BranchName
  Set-Location $rootFolder

  # Copy items into the folder
  copy-item "$SourceRepoDiskPath/*" ./$repoFolder -Recurse -Force
  Set-Location $repoFolder
  # Commit and push if files have changed
  New-CommitAndPushIfChanged -CommitMessage "Standardise files with files in $SourceRepoOwner/$SourceRepoName"
  New-GithubPullRequest -owner $DestinationRepoOwner -Repo $repo.name -Head "$($DestinationRepoOwner):$($BranchName)" -base 'master' -title $PullRequestTitle -body $PullRequestBody
}
