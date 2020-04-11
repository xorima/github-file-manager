function Remove-PathIfExists {
  param (
      [Parameter()]
      [String]
      $Path
  )
  if (Test-Path $Path )
  {
    Remove-Item $Path -Recurse -Force
  }
}

Export-ModuleMember *
