function Write-Log {
  param(
    [String]
    $Message,
    [String]
    $Source,
    [String]
    [ValidateSet('DEBUG','INFO', 'WARN', 'ERROR')]
    $level = 'INFO',
    $lineNumber = $Myinvocation.ScriptlineNumber
  )

  Write-Host "$($level.ToLower()) - $($Source.toLower()):$lineNumber : $Message"
  if($level -eq 'ERROR')
  {
    Exit 1
  }
}

Export-ModuleMember *
