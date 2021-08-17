
function Set-ChangeLog {
  param(
    [String]
    $ChangelogPath,
    [String]
    $ChangeLogMarker,
    [String]
    $ChangeLogEntry
  )
  if (-not (Test-Path $ChangeLogPath)) {
    Write-Log -Level WARN -Source 'entrypoint' -Message "Unable to find $ChangeLogPath"
    return $null
  }

  $changelog = get-content $ChangeLogPath
  # Work around case sensitivity
  if ($changelog | Where-Object { $_ -like "*$ChangeLogMarker*" }) {
    $ChangeLogMarker = $changelog | Where-Object { $_ -like "*$ChangeLogMarker*" }
  }
  $changeIndex = $changelog.IndexOf($changelogMarker)

  if ($changeIndex -ge 0) {
    $changeIndex += 2
    $changelog[$changeIndex] = "$changeLogEntry$($changelog[$changeIndex])"
  }
  else {
    # Find the next title:
    $NextSubTitle = ($changelog | Where-Object { $_ -like "## *" })[0]
    if ($NextSubTitle) {
      # Get the index of that subtitle
      $NextSubTitleIndex = $changelog.IndexOf($NextSubTitle)

      $changelog[$NextSubTitleIndex] = "$changelogMarker`n`n$changeLogEntry`n$($changelog[$NextSubTitleIndex])"
    }
    # Unable to find any subtitle
    else {
      $changelog[2] = "$changelogMarker`n`n$changeLogEntry`n$($changelog[2])"
    }
  }

  Set-Content -path $changelogPath -Value $changelog
}

Export-ModuleMember *