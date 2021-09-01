param (
    [string]$path = "T:\Shared Videos\YouTubePendingUpload\Surge2",
    [string]$pattern = "^.*\.mp4$"
 )

$state_file = [IO.Path]::Combine($path, "_last_upload_file.txt")
$desc_file = [IO.Path]::Combine($path, "_default_description.txt")

# https://evotec.xyz/getting-file-metadata-with-powershell-similar-to-what-windows-explorer-provides/
function Get-FileMetaData {
    <#
    .SYNOPSIS
    Small function that gets metadata information from file providing similar output to what Explorer shows when viewing file

    .DESCRIPTION
    Small function that gets metadata information from file providing similar output to what Explorer shows when viewing file

    .PARAMETER File
    FileName or FileObject

    .EXAMPLE
    Get-ChildItem -Path $Env:USERPROFILE\Desktop -Force | Get-FileMetaData | Out-HtmlView -ScrollX -Filtering -AllProperties

    .EXAMPLE
    Get-ChildItem -Path $Env:USERPROFILE\Desktop -Force | Where-Object { $_.Attributes -like '*Hidden*' } | Get-FileMetaData | Out-HtmlView -ScrollX -Filtering -AllProperties

    .NOTES
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline)][Object] $File,
        [switch] $Signature
    )
    Process {
        foreach ($F in $File) {
            $MetaDataObject = [ordered] @{}
            if ($F -is [string]) {
                $FileInformation = Get-ItemProperty -Path $F
            } elseif ($F -is [System.IO.DirectoryInfo]) {
                #Write-Warning "Get-FileMetaData - Directories are not supported. Skipping $F."
                continue
            } elseif ($F -is [System.IO.FileInfo]) {
                $FileInformation = $F
            } else {
                Write-Warning "Get-FileMetaData - Only files are supported. Skipping $F."
                continue
            }
            $ShellApplication = New-Object -ComObject Shell.Application
            $ShellFolder = $ShellApplication.Namespace($FileInformation.Directory.FullName)
            $ShellFile = $ShellFolder.ParseName($FileInformation.Name)
            $MetaDataProperties = [ordered] @{}
            0..400 | ForEach-Object -Process {
                $DataValue = $ShellFolder.GetDetailsOf($null, $_)
                $PropertyValue = (Get-Culture).TextInfo.ToTitleCase($DataValue.Trim()).Replace(' ', '')
                if ($PropertyValue -ne '') {
                    $MetaDataProperties["$_"] = $PropertyValue
                }
            }
            foreach ($Key in $MetaDataProperties.Keys) {
                $Property = $MetaDataProperties[$Key]
                $Value = $ShellFolder.GetDetailsOf($ShellFile, [int] $Key)
                if ($Property -in 'Attributes', 'Folder', 'Type', 'SpaceFree', 'TotalSize', 'SpaceUsed') {
                    continue
                }
                If (($null -ne $Value) -and ($Value -ne '')) {
                    $MetaDataObject["$Property"] = $Value
                }
            }
            if ($FileInformation.VersionInfo) {
                $SplitInfo = ([string] $FileInformation.VersionInfo).Split([char]13)
                foreach ($Item in $SplitInfo) {
                    $Property = $Item.Split(":").Trim()
                    if ($Property[0] -and $Property[1] -ne '') {
                        $MetaDataObject["$($Property[0])"] = $Property[1]
                    }
                }
            }
            $MetaDataObject["Attributes"] = $FileInformation.Attributes
            $MetaDataObject['IsReadOnly'] = $FileInformation.IsReadOnly
            $MetaDataObject['IsHidden'] = $FileInformation.Attributes -like '*Hidden*'
            $MetaDataObject['IsSystem'] = $FileInformation.Attributes -like '*System*'
            if ($Signature) {
                $DigitalSignature = Get-AuthenticodeSignature -FilePath $FileInformation.Fullname
                $MetaDataObject['SignatureCertificateSubject'] = $DigitalSignature.SignerCertificate.Subject
                $MetaDataObject['SignatureCertificateIssuer'] = $DigitalSignature.SignerCertificate.Issuer
                $MetaDataObject['SignatureCertificateSerialNumber'] = $DigitalSignature.SignerCertificate.SerialNumber
                $MetaDataObject['SignatureCertificateNotBefore'] = $DigitalSignature.SignerCertificate.NotBefore
                $MetaDataObject['SignatureCertificateNotAfter'] = $DigitalSignature.SignerCertificate.NotAfter
                $MetaDataObject['SignatureCertificateThumbprint'] = $DigitalSignature.SignerCertificate.Thumbprint
                $MetaDataObject['SignatureStatus'] = $DigitalSignature.Status
                $MetaDataObject['IsOSBinary'] = $DigitalSignature.IsOSBinary
            }
            [PSCustomObject] $MetaDataObject
        }
    }
}

# Get files in the directory
$files = Get-ChildItem -Path $path | Where-Object { $_.Name -match $pattern } | Sort-Object Name

$last_uploaded = ""
$uploadThisFile = $true
$uploadedAnyFiles = $false

if( Test-Path $state_file ) {
    $last_uploaded = Get-Content $state_file
    Write-Host "Last uploaded" $last_uploaded
    $uploadThisFile = $false
}

foreach( $fileinfo in $files ) {
    
    $name = $fileinfo.Name
    $basename = $fileinfo.BaseName

    if( $uploadThisFile ) {
        
        #Write-Host "Reading metadata for" $fileinfo.Name
        #$metadata = Get-FileMetaData -File $fileinfo.FullName
        #Write-Host ($metadata | Format-List | Out-String)
        #Write-Host "comments" $metadata['Comments']

        $gamecode = ""
        $title = ""
        if( $basename -match "(^.)*-\d\d\d\d\d\d\d\d\d\d\d\d\d\d - (.*)$") {
            $gamecode = $Matches[1]
            $title = $Matches[2]
        }

        # YouTube date format = ISO 8601 = YYYY-MM-DDThh:mm:ss.sssZ
        $recorded_date = ""
        if( $basename -match "^.*-(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d) - .*$") {
            $date = Get-Date -Year $Matches[1] -Month $Matches[2] -Day $Matches[3] -Hour $Matches[4] -Minute $Matches[5] -Second $Matches[6] -Millisecond 0
            $zdate = $date.ToUniversalTime().ToString("o").SubString(0, 10)
        }

        $part = ""
        if( $basename -match "^.*-\d\d\d\d\d\d\d\d\d\d\d\d\d\d - .*Pt (\d+)[,\s].*$") {
            $part = [int]$Matches[1]
            $thumbnail = "thumbnails\{0:000}.jpg" -f $part
            $fullthumbnail = [IO.Path]::Combine($path, $thumbnail)
            if( !(Test-Path $fullthumbnail) ) {
                $thumbnail = ""
            }
        }

        $description = ""
        if( Test-Path $desc_file ) {
            $description = Get-Content $desc_file
        }

        Write-Host "Now uploading" $name
        Write-Host "Title:" $title
        Write-Host "Recorded:" $zdate
        Write-Host "Thumbnail:" $thumbnail
        Write-Host "Part:" $part

        $fullname = [IO.Path]::Combine($path, $name)

        $cmd  = "C:\godev\vidup\vidup"
        $cmd += ' -filename "{0}"' -f $fullname
        $cmd += ' -title "{0}"' -f $title
        if( $description ) {
            $cmd += ' -description "{0}"' -f $description
        }
        $cmd += ' -recorded "{0}"' -f $zdate
        $cmd += ' -privacy public'
        if( $thumbnail ) {
            $cmd += ' -thumbnail "{0}"' -f $fullthumbnail
        }
        Write-Host $cmd
        Invoke-Expression $cmd

        $uploadedAnyFiles = $true
        Set-Content $state_file -Value $name
        return

    } else {
        
        if( $name -eq $last_uploaded) {
            # Upload the *next* file in the sequence
            $uploadThisFile = $true
        }

    }
}

if( !$uploadedAnyFiles ) {
    Write-Host "No files to upload"
}

