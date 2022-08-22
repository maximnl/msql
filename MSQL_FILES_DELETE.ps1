$FileLocation='\\server\SFTP_Root\' 
 
set-Location C:
Set-Location $FileLocation

Write-Output "Deleteing files with no data extension and older than 2 days"
 
Get-ChildItem -File  $FileLocation -exclude *.csv,*.xlsx,*.xls,*.txt | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-1)} | Remove-Item -Force
   
Write-Output "Files successfully deleted"
