Param(
    [Parameter(Mandatory=$True)]
    [string]$userName,
    [Parameter(Mandatory=$false)]
    [switch]$includeGladiusCards, 
    [Parameter(Mandatory=$false)]
    [string]$outputDirectory = $PSScriptRoot
)

Write-Progress -Activity 'Step 1' -Status "Try getting player $userName card collection..." -PercentComplete 0;
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

$cardCollection = ($cardCollection | where { $includeGladiusCards -or ($_.edition -ne 6) });
$stepCounter = 0;

Write-Progress -Activity 'Step 2' -Status 'Gathering card information...' -PercentComplete 0;
foreach ($card in $cardCollection)
{
    $cardKey = [string]::Format("{0}::{1}::{2}", $card.card_detail_id, $card.gold, $card.xp);
    $tempCard = $cardArray | where { $_.Key -eq $cardKey } | select -First 1;
    if ($tempCard -eq $null)
    {
        $responseCardInfo = Invoke-RestMethod -Method Get -Uri ([string]::Format("https://api2.splinterlands.com/cards/find?ids={0}", $card.uid));
        
        $cardSaleGroup = $null;
        $lowPriceBcx = -1.0;
        $cardSaleGroup = ($cardsForSale | where { ($_.card_detail_id -eq $card.card_detail_id) -and ($_.gold -eq $card.gold) -and ($_.level -eq $card.level) });
        if ($cardSaleGroup -eq $null)
        {
            $cardSaleGroup = ($cardsForSale | where { ($_.card_detail_id -eq $card.card_detail_id) -and ($_.gold -eq $card.gold) });
            $lowPriceBcx = $cardSaleGroup.low_price_bcx * $card.xp;
        }
        else 
        {
            $lowPriceBcx = $card.level -gt 1 ? $cardSaleGroup.low_price_bcx : $cardSaleGroup.low_price_bcx * $card.xp;
        }

        $cardArray += [PSCustomObject]@{ 
            Key = $cardKey
            Id = $card.card_detail_id
            Name = $responseCardInfo.details.name
            XP = $card.xp
            "Gold Foil" = $card.gold ? "Yes" : "No"
            "Estimated Value in $" = $lowPriceBcx -lt 0.0 ? "unknown" : [string]::Format("{0:0.000}", $lowPriceBcx) 
        };
    }
    else 
    {
        $cardArray += $tempCard;
    }
    Write-Progress -Activity 'Step 2' -Status 'Gathering card information...' -PercentComplete (((++$stepCounter) / $cardCollection.Count) * 100);
}

$outputFilePath = "$outputDirectory\card collection ($userName).csv";
Write-Progress -Activity 'Step 3' -Status "Export card collection..." -PercentComplete 0;
$cardArray | select -Property Id, Name, XP, "Gold Foil", "Estimated Value in $" | Export-Csv -Path $outputFilePath -Delimiter ';' -Force;