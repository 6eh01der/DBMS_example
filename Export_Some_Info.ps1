param (
    [string] $csvDir
)
$pgUser = $env:PostgresUser
$pgPass = $env:PostgresPassword
$pgport = "5432"
$MSSQLServers = (Get-ADComputer -Filter * -SearchBase "OU=, OU=, DC=, DC=").name
$PGServers = (Get-ADComputer -Filter 'Name -like "*SomePG*"' -SearchBase "OU=, OU=, DC=, DC=").Name
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null
$Results = @{}
ForEach ($mssqlserver in $MSSQLServers) {
    $s = New-Object ('Microsoft.SqlServer.Management.Smo.Server') "$mssqlserver"
    foreach ($db in $s.Databases | Where-Object {$_.Name -ne 'msdb' -AND $_.Name -ne 'tempdb' -AND $_.Name-ne 'master' -AND $_.Name -ne 'model'}) {
        $Results.Add("STA.$mssqlserver$db", $db.ExecuteWithResults('select * from SomeTableA'))
        $Results.Add("STB.$mssqlserver$db", $db.ExecuteWithResults('select * from SomeTableB'))
        $Results.Add("STC.$mssqlserver$db", $db.ExecuteWithResults('select * from SomeTableC'))
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
        $dsSTA = New-Object System.Data.DataSet
        $dsSTB = New-Object System.Data.DataSet
        $dsSTC = New-Object System.Data.DataSet
        $cnDB.Open()
        $adDB = New-Object System.Data.Odbc.OdbcDataAdapter
        $adDB.SelectCommand = New-Object System.Data.Odbc.OdbcCommand('select * from "SomeTableA"' , $cnDB)
        $adDB.Fill($dsSTA)
        $adDB.SelectCommand = New-Object System.Data.Odbc.OdbcCommand('select * from "SomeTableB"' , $cnDB)
        $adDB.Fill($dsSTB)
        $adDB.SelectCommand = New-Object System.Data.Odbc.OdbcCommand('select * from "SomeTableC"' , $cnDB)
        $adDB.Fill($dsSTC)
        $cnDB.Close()
        $Results.Add("STA.$pgserver[$dbName]", $dsSTA)
        $Results.Add("STB.$pgserver[$dbName]", $dsSTB)
        $Results.Add("STC.$pgserver[$dbName]", $dsSTC)
    }
}
$ResultsFormatted = [PSCustomObject]@{}
foreach ($Key in $Results.Keys | select-object name, {$_.Value.Tables.Rows.Count}) {
    $one = ($entry.Name.Split('.')[0]).Trim()
    $two = ($entry.Name.Split('.')[1]).Split('[')[0].Trim()
    $three = ($entry.Name.Split('.')[1]).Split('[')[1].Split(']')[0].Trim()
    $ResultsFormatted | Add-Member -NotePropertyMembers @{
        Table = $one
        Server = $two
        Database = $three
        Count = $entry.{$_.Value.Tables.Rows.Count}
    }
}
if (Test-Path -Path $csvDir) {
    $ResultsFormatted | Export-CSV -Path "$csvDir\Info.csv" -NoTypeInformation
}
