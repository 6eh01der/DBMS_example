param (
    [string] $csvDir
)
$pgUser = $env:PostgresUser
$pgPass = $env:PostgresPassword
$pgport = "5432"
$MSSQLServers = (Get-ADComputer -Filter * -SearchBase "OU=, OU=, DC=, DC=").name
$PGServers = (Get-ADComputer -Filter 'Name -like "*SomePG*"' -SearchBase "OU=, OU=, DC=, DC=").Name
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null
ForEach ($mssqlserver in $MSSQLServers) {
    $s = New-Object ('Microsoft.SqlServer.Management.Smo.Server') "$mssqlserver"
    foreach ($db in $s.Databases | Where-Object {$_.Name -ne 'msdb' -AND $_.Name -ne 'tempdb' -AND $_.Name-ne 'master' -AND $_.Name -ne 'model'}) {
        New-Variable -Name "SMA.$mssqlserver$db" -Value $db.ExecuteWithResults('select * from SomeTableA') -Force
        New-Variable -Name "SMB.$mssqlserver$db" -Value $db.ExecuteWithResults('select * from SomeTableB') -Force
        New-Variable -Name "SMC.$mssqlserver$db" -Value $db.ExecuteWithResults('select * from SomeTableC') -Force
    }
}
ForEach ($pgserver in $PGServers) {
    [string]$szConnect  = "Driver={PostgreSQL Unicode(x64)};Server=$pgserver;Port=$pgport;Uid=$pgUser;Pwd=$pgPass;"
    $cnDB = New-Object System.Data.Odbc.OdbcConnection($szConnect)
    $dsDB = New-Object System.Data.DataSet
    $cnDB.Open()
    $adDB = New-Object System.Data.Odbc.OdbcDataAdapter
    $adDB.SelectCommand = New-Object System.Data.Odbc.OdbcCommand('select * from "pg_database"' , $cnDB)
    $adDB.Fill($dsDB)
    $cnDB.Close()
    foreach ($dbName in $dsDB.Tables.datName | Where-Object {$_ -ne 'postgres' -AND $_ -notlike 'template*'}) {
        [string]$szConnect  = "Driver={PostgreSQL Unicode(x64)};Server=$pgserver;Port=$pgport;Database=$dbName;Uid=$pgUser;Pwd=$pgPass;"
        $cnDB = New-Object System.Data.Odbc.OdbcConnection($szConnect)
        $dsSMA = New-Object System.Data.DataSet
        $dsSMB = New-Object System.Data.DataSet
        $dsSMC = New-Object System.Data.DataSet
        $cnDB.Open()
        $adDB = New-Object System.Data.Odbc.OdbcDataAdapter
        $adDB.SelectCommand = New-Object System.Data.Odbc.OdbcCommand('select * from "SomeTableA"' , $cnDB)
        $adDB.Fill($dsSMA)
        $adDB.SelectCommand = New-Object System.Data.Odbc.OdbcCommand('select * from "SomeTableB"' , $cnDB)
        $adDB.Fill($dsSMB)
        $adDB.SelectCommand = New-Object System.Data.Odbc.OdbcCommand('select * from "SomeTableC"' , $cnDB)
        $adDB.Fill($dsSMC)
        $cnDB.Close()
        New-Variable -Name "SMA.$pgserver[$dbName]" -value $dsSMA -Force
        New-Variable -Name "SMB.$pgserver[$dbName]" -value $dsSMB -Force
        New-Variable -Name "SMC.$pgserver[$dbName]" -value $dsSMC -Force
    }
}
$Results = Get-Variable | Where-Object {$_.Name -like "SM*"}
$ResultsFormatted = @()
foreach ($entry in $Results | select-object name, {$_.Value.Tables.Rows.Count}) {
    $one = ($entry.Name.Split('.')[0]).Trim()
    $two = ($entry.Name.Split('.')[1]).Split('[')[0].Trim()
    $three = ($entry.Name.Split('.')[1]).Split('[')[1].Split(']')[0].Trim()
    $ResultsFormatted += New-Object PSObject -Property @{
    Table = $one
    Server = $two
    Database = $three
    Count = $entry.{$_.Value.Tables.Rows.Count}
    }
}
if (Test-Path -Path $csvDir) {
    $ResultsFormatted | Export-CSV -Path "$csvDir\Info.csv" -NoTypeInformation
}