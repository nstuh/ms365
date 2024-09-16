Function Log-Message([String]$Message)
{
    Add-Content -Path C:\Temp\Log.txt $Message  # log dosyası path'i
}
Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell
Connect-SPOService -Url https://anadoluisuzu-admin.sharepoint.com 


$userPrincipalName = "adeotest@isuzu.com.tr"  ##site'ı indirilecek kullanıcının UPN'i
$admin = "XXXXX"  ## SharePoint Admin Hesabi gerekli.
$Prefix = "c:\Temp\" ## Download Path Olarak Girilecek.


Try {
    $OneDriveSiteUrl = (Get-SPOSite -IncludePersonalSite $true -Limit all | Where-Object { $_.Owner -eq $userPrincipalName }).Url
    connect-pnponline -url $OneDriveSiteUrl -Interactive
    Set-SPOUser -Site $OneDriveSiteUrl -LoginName $admin -IsSiteCollectionAdmin $true
    $Web = Get-PnPWeb 
    $url = $OneDriveSiteUrl
    $splitArray = $url.Split("/")
    $DownloadFolderName = $splitArray[-1]
    $pathforusers= $Prefix + "\" + $DownloadFolderName
    $DownloadPath = $pathforusers
    $List = Get-PnPList -Identity "Documents"
    Log-Message "$($DownloadFolderName) indirmesi denenmektedir. "
    #ilerleme cubugu
    $global:counter = 0
    $ListItems = Get-PnPListItem -List $List -PageSize 500 -Fields ID -ScriptBlock { Param($items) $global:counter += $items.Count; Write-Progress -PercentComplete `
                ($global:Counter / ($List.ItemCount) * 100) -Activity "OneDrive'dan veriler alinmaktadir:" -Status "$global:Counter - $($List.ItemCount)";}
    Write-Progress -Activity "OneDrive'dan tum veriler alinmistir." -Completed

    $SubFolders = $ListItems | Where {$_.FileSystemObjectType -eq "Folder" -and $_.FieldValues.FileLeafRef -ne "Forms"}
    $SubFolders | ForEach-Object {
        $LocalFolder = $DownloadPath +($_.FieldValues.FileRef.Substring($Web.ServerRelativeUrl.Length)) -replace "/","\"
        If (!(Test-Path -Path $LocalFolder)) {
                New-Item -ItemType Directory -Path $LocalFolder | Out-Null
        }
        Write-host -f Yellow "'$LocalFolder'"
    }

    $FilesColl =  $ListItems | Where {$_.FileSystemObjectType -eq "File"}

    $FilesColl | ForEach-Object {
        try{
            $FileDownloadPath = ($DownloadPath +($_.FieldValues.FileRef.Substring($Web.ServerRelativeUrl.Length)) -replace "/","\").Replace($_.FieldValues.FileLeafRef,'')
            [System.Uri]::EscapeDataString($_.FieldValues.FileRef)
            Get-PnPFile -ServerRelativeUrl $_.FieldValues.FileRef -Path $FileDownloadPath -FileName $_.FieldValues.FileLeafRef -AsFile -force
            Write-host -f Green "Dosya '$($_.FieldValues.FileRef)' icerisinden indirilmektedir"

        }
        catch
        {
            Log-Message "Hata: $($DownloadFolderName) Detay: $($_.Exception.Message)"
        }

        }

}
Catch {

            write-host "Hata: $($_.Exception.Message)" -foregroundcolor Red
            Log-Message "Hata: $($DownloadFolderName) Detay: $($_.Exception.Message)"
        }
Set-SPOUser -Site $OneDriveSiteUrl -LoginName $admin -IsSiteCollectionAdmin $false
