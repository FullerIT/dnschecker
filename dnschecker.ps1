# Specify the path to the CSV file containing domains
$domainsFilePath = "C:\temp\domains.csv"
# Specify the path to the output CSV file
$outputFilePath = "C:\temp\dnsresults.csv"

# Import domains from the CSV file
$domains = Import-Csv -Path $domainsFilePath -Header "Domain" | Select-Object -ExpandProperty Domain

# Specify the string to append to each domain for CNAME lookup
$cnameSuffix1 = "selector1._domainkey"
$cnameSuffix2 = "selector2._domainkey"
$cnameSuffix3 = "google._domainkey"

# Create an empty array to store the results
$resultsArray = @()

# Loop through each domain and perform NSlookup for the appended CNAME
foreach ($domain in $domains) {
    # Construct the full CNAME by appending the suffix to the domain
    $fullCname1 = "$cnameSuffix1.$domain"
    $fullCname2 = "$cnameSuffix2.$domain"
    $fullCname3 = "$cnameSuffix3.$domain"
    $dmarcdns = "_dmarc.$domain"

    $domainResults = @{
        "Domain" = $domain
    }

    # Checking NS for $domain
    try {
        $result = Resolve-DnsName -Name $domain -Type NS -ErrorAction SilentlyContinue | Where-Object { $_.QueryType -eq "NS" }
        if ($result) {
            $domainResults["NS"] = "$($result.NameHost)"
        } else {
            $domainResults["NS"] = "Not found"
        }
    } catch {
        $domainResults["NS"] = "Error occurred while performing NSlookup"
    }


    # Checking MSDKIM1 for $fullCname1
    try {
        $result = Resolve-DnsName -Name $fullCname1 -Type CNAME -ErrorAction SilentlyContinue | Where-Object { $_.QueryType -eq "CNAME" }
        if ($result) {
            $domainResults["MSDKIM1"] = "$($result.NameHost)"
        } else {
            $domainResults["MSDKIM1"] = "Not found"
        }
    } catch {
        $domainResults["MSDKIM1"] = "Error occurred while performing NSlookup"
    }

    # Checking MSDKIM2 for $fullCname2
    try {
        $result = Resolve-DnsName -Name $fullCname2 -Type CNAME -ErrorAction SilentlyContinue | Where-Object { $_.QueryType -eq "CNAME" }
        if ($result) {
            $domainResults["MSDKIM2"] = "$($result.NameHost)"
        } else {
            $domainResults["MSDKIM2"] = "Not found"
        }
    } catch {
        $domainResults["MSDKIM2"] = "Error occurred while performing NSlookup"
    }

    # Checking GoogleDKIM for $fullCname3
    try {
        $result = Resolve-DnsName -Name $fullCname3 -Type CNAME -ErrorAction SilentlyContinue | Where-Object { $_.QueryType -eq "CNAME" }
        if ($result) {
            $domainResults["GoogleDKIM"] = "$($result.NameHost)"
        } else {
            $domainResults["GoogleDKIM"] = "Not found"
        }
    } catch {
        $domainResults["GoogleDKIM"] = "Error occurred while performing NSlookup"
    }

    # Checking SPF for $domain
    try {
        $result = Resolve-DnsName -Name $domain -Type TXT -ErrorAction SilentlyContinue | Where-Object { $_.QueryType -eq "TXT" }
        if ($result) {
            $SPFRecord = $result | Where-Object { $_.Strings -match "^v=spf1" }
            if ($SPFRecord) {
                $domainResults["SPF"] = "$($SPFRecord.Strings)"
            } else {
                $domainResults["SPF"] = "Not found"
            }
        } else {
            $domainResults["SPF"] = "Not found"
        }
    } catch {
        $domainResults["SPF"] = "Error occurred while performing NSlookup"
    }

    # Checking DMARC for $domain
    try {
        $result = Resolve-DnsName -Name $dmarcdns -Type TXT -ErrorAction SilentlyContinue | Where-Object { $_.QueryType -eq "TXT" }
        if ($result) {
            $DMARCRecord = $result | Where-Object { $_.Strings -match "^v=DMARC1" }
            if ($DMARCRecord) {
                $domainResults["DMARC"] = "$($DMARCRecord.Strings)"
            } else {
                $domainResults["DMARC"] = "Not found"
            }
        } else {
            $domainResults["DMARC"] = "Not found"
        }
    } catch {
        $domainResults["DMARC"] = "Error occurred while performing NSlookup"
    }


    # Add the domain results to the results array
    $resultsArray += New-Object PSObject -Property $domainResults
}

# Export the results array to a CSV file with "Domain" as the first column
$resultsArray | Select-Object Domain, NS, MSDKIM1, MSDKIM2, GoogleDKIM, SPF, DMARC | Export-Csv -Path $outputFilePath -NoTypeInformation

Write-Output "DNS results have been saved to $outputFilePath"
