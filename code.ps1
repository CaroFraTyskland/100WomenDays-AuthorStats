#Zeile bereinigen (| und Leerzeichen entfernen)
function transformLine ($line) {
   return $line.replace("|", "").trim()
}

#zu Tabelle aus Quellcode die Autor*innen-Statisik befüllen
function getStatsToTable ($table) {
    $entries = $table -split '(?m)^\s*\|-\s*$'

    foreach ($entry in $entries) {
        if ($entry.contains('id="Start Biografien"')) { continue }
        $lines = $entry -split '\r?\n'
        $lines = $lines | where {-not [string]::IsNullOrWhiteSpace($_) -and $_ -notmatch '^\s*(\{\{anker|\|\}|!)'}

        if (-not $lines) {continue}
        $script:authors += transformLine -line $lines[-1]
    }
}

#Wiki-Quelltext abfragen
function getSourceCode () {
  $url = "https://de.wikipedia.org/w/api.php"
  
  $params = @{
      action        = "query"
      prop          = "revisions"
      titles        = "Wikipedia:100 Women Days 2026"
      rvprop        = "content"
      rvslots       = "main"
      format        = "json"
      formatversion = "2"
  }

  $response = invoke-restMethod -Uri $url -Method Get -Body $params
  $wikitext = $response.query.pages[0].revisions[0].slots.main.content

  return $wikitext
}

#Tabellen aus Quelltext auslesen
function getTables ($wikitext) {
  $tables = [regex]::Matches($wikitext, '(?s)\{\|.*?\|\}') | foreach { $_.Value }
  return $tables
}

$wikitext = getSourceCode
$tables = getTables -wikitext $wikitext

$script:authors = @()

#die beiden Artikel-Tabellen auswerten
getStatsToTable -table $tables[1]
getStatsToTable -table $tables[2]

#aus Autor*innen-Liste die Statistik berechnen (bei 'a und b' bekommen Autor*in a und b je 0.5 Punkte)
$stats = $authors |
    foreach {
        if ($_ -match '\s+und\s+') { $_ -split '\s+und\s+' | foreach {
                [PSCustomObject]@{
                    Name  = $_.Trim()
                    Count = 0.5
                }
            }
        } else {
            [PSCustomObject]@{
                Name  = $_.Trim()
                Count = 1
            }
        }
    } | group name | foreach {
        [PSCustomObject]@{
            Name  = $_.name
            Count = ($_.group | measure-object count -sum).sum
        }
    } | sort @{expression='Count'; descending=$true}, @{expression='Name'; ascending=$true}

#Diagramm-Quelltext zusammensetzen
$diagram = "{{Balkendiagramm
| title    = Verteilung nach Autor/-in
| titlebar = #DDD
| left1    = Verteilung der Artikel
| right1   = Anzahl
| width    = 400px
| bars     ="

$count = 1

#Balken zu den Autor*innen bilden
foreach ($statsEntry in $stats) {
   $diagram += "`n{{Balken Pixel|$($statsEntry.Name)|{{/Farbe|$count}}|$($statsEntry.count)}}"
   $count++

   #zurück zu Farbe 1
   if ($count -gt 8) {$count = 1}
}

#Artikzelzahl bestimmen und anfügen
$countTable1 = (($tables[1] -split '(?m)^\s*\|-\s*$')[-1] -split "`n")[1].replace("|", "").trim()
$countTable2 = (($tables[2] -split '(?m)^\s*\|-\s*$')[-1] -split "`n")[1].replace("|", "").trim()

$diagram += "`n|caption = bis Artikel $($countTable1)/$($countTable2)
`nInsgesamt: $($stats.count) Autoren
}}"

#Diagram in Zwischenablage kopieren
$diagram | set-clipboard


write-host "`n`nBerechnung abgeschlossen!" -ForegroundColor Green
read-host "`n`nBeenden mit Enter"
exit
