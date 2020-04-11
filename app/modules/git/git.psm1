function New-GitClone {
  param (
    [Parameter()]
    [String]
    $SshUrl,
    [Parameter()]
    [String]
    $Directory
  )
  try {
    git clone $SshUrl $Directory
  }
  catch {
    Write-Error "Unable to Clone $SshUrl"
  }
}

function Select-GitBranch {
  param (
    [String]
    $BranchName
  )
  try {
    git fetch
    git checkout $BranchName
  }
  catch {
    Write-Error "Unable to checkout $BranchName"
  }
}

function New-CommitAndPushIfChanged {
  param (
    [String]
    $CommitMessage,
    [Switch]
    $Push
  )
  try {
    $ChangeCount = Get-GitChangeCount
    if ($ChangeCount -gt 0) {
      git add -A
      git commit -m "$CommitMessage"
      if ($push) {
        git push
      }
    }
  }
  catch {
    Write-Error "Unable to commit"
  }
}

function Get-GitChangeCount {
  try {
    return git status --porcelain | Measure-Object | Select-Object -expand Count
  }
  catch {
    Write-Error "Unable to count changes"
  }
}

function Set-GitConfig {
  param(
    [String]
    $GitName,
    [String]
    $GitEmail
  )
  if ($GitName){
    git config --global user.name "$GitName"
  }
  if ($GitEmail){
    git config --global user.email "$GitEmail"
  }
}
Export-ModuleMember *
