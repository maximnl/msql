
$Position=0
$mandatory=$true
$FileLocation='\\server\SFTP_Root\' 
$Server='YOUR_SERVER'
$Database='YOUR_DATABASE'
$Table='CORE_FILES'

set-Location C:
Set-Location $FileLocation

Write-Output "Inserting files"
$sqlstatement="
INSERT INTO $Table(
   Fully_Qualified_FileName, File_name, attributes, CreationTime, LastAccessTime, LastWriteTime,
    Length    
) 
VALUES (
   '{0}',
   '{1}',
   '{2}',
   '{3}',
   '{4}',
   '{5}',
    '{6}'
)
"
Invoke-Sqlcmd -Query "Truncate Table $Table" -ServerInstance $Server -database $Database
Get-ChildItem -File  $FileLocation  | select  FullName, Name,attributes, CreationTime, LastAccessTime, LastWriteTime,@{Label="Length";Expression={$_.Length / 1MB -as [int] }}|
   ForEach-Object {
      $SQL = $sqlstatement -f $_.FullName, $_.name,$_.attributes, $_.CreationTime, $_.LastAccessTime, $_.LastWriteTime,$_.Length                            
      
        Invoke-sqlcmd -Query $SQL -ServerInstance $Server -database $Database

   }

Write-Output "File Inserted successfully... Below Is list of files"
