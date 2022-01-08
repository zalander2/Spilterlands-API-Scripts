Param(
    [Parameter(Mandatory=$True)]
    [string]$userName,
    [Parameter(Mandatory=$false)]
    [string]$outputDirectory = $PSScriptRoot
)

$response = Invoke-RestMethod -Method Get -Uri "https://api2.splinterlands.com/cards/collection/$userName";
if ($response.cards.Count -eq 0)
{
    Write-Error "Card collection from player $userName is emtpy.";
    exit;
}

$cardCollection = $response.cards | where { $_.player -eq $userName }
if ($cardCollection.Count -eq 0)
{
    Write-Error "Player $userName doesn't own any card.";
    exit;
}

$cardsForSale = Invoke-RestMethod -Method Get -Uri "https://api2.splinterlands.com/market/for_sale_grouped";
[array]$cardArray = @();

foreach ($card in ($cardCollection | where { $_.edition -ne 6 }))
{
    $cardKey = [string]::Format("{0}::{1}", $card.card_detail_id, $card.gold);
    $tempCard = $cardArray | where { $_.Key -eq $cardKey } | select -First 1;
    if ($tempCard -eq $null)
    {
        $responseCardInfo = Invoke-RestMethod -Method Get -Uri ([string]::Format("https://api2.splinterlands.com/cards/find?ids={0}", $card.uid));
        $cardSaleGroup = ($cardsForSale | where { ($_.card_detail_id -eq $card.card_detail_id) -and ($_.gold -eq $card.gold) });
        $cardArray += [PSCustomObject]@{ 
            Key = $cardKey
            Id = $card.card_detail_id
            Name = $responseCardInfo.details.name
            "Gold Foil" = $card.gold ? "Yes" : "No"
            "Estimated Value in $" = $cardSaleGroup.low_price_bcx -eq $null ? "unknown" : [string]::Format("{0:0.000}", $cardSaleGroup.low_price_bcx) 
        };
    }
    else 
    {
        $cardArray += $tempCard;
    }
}

$cardArray | select -Property Id, Name, "Gold Foil", "Estimated Value in $" | Export-Csv -Path "$outputDirectory\card collection($userName).csv" -Delimiter ';' -Force;