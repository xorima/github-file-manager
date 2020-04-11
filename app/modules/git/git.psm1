function New-GitClone {
  param (
    [Parameter()]
    [String]
    $HttpUrl,
    [Parameter()]
    [String]
    $Directory
  )
    git clone $($HttpUrl.replace('https://',"https://$ENV:GITHUB_TOKEN@")) $Directory
    # If error in clone
    if (!($?)){
      Write-Error "Unable to Clone $SshUrl" -ErrorAction Stop
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
      Write-Log -Level INFO -Source 'git' -Message 'Files have changed adding all files'
      git add -A
      Write-Log -Level INFO -Source 'git' -Message "Committing to current branch $(git branch)"
      git commit -m "$CommitMessage"
      if ($push) {
        Write-Log -Level INFO -Source 'git' -Message "Pushing changes to remote"
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
    Write-Log -Level INFO -Source 'git' -Message 'Getting file changes'
    return git status --porcelain | Measure-Object | Select-Object -expand Count
  }
  catch {
    Write-Log -Level ERROR -Source 'git' -Message 'Unable to count changes'
  }
}

function Set-GitConfig {
  param(
    [String]
    $GitName,
    [String]
    $GitEmail,
    [String]
    $GitKey
  )
  if ($GitName){
    git config --global user.name "$GitName"
  }
  if ($GitEmail){
    git config --global user.email "$GitEmail"
  }
  # if ($GitKey){
  #   New-Item "~/.ssh" -ItemType Directory
  #   Out-File -FilePath "~/.ssh/id_rsa" -InputObject $GitKey -Encoding utf8 -NoClobber -NoNewline
  #   Out-File -InputObject "Host github.com`n`tStrictHostKeyChecking no`n" -filePath "~/.ssh/config" -Encoding utf8 -NoClobber -NoNewLine
  #   if ($IsLinux)
  #   {
  #     chmod 700 ~/.ssh/id_rsa
  #   }

  # }

}
Export-ModuleMember *
