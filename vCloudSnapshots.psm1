function Get-CISnapshot
{
   <#
      .SYNOPSIS
      Gets a snapshot for a vCloud vApp or VM.
      .DESCRIPTION
      Gets a snapshot for a vCloud vApp or VM. vCloud Director 5.1 allows a single snapshot to be taken of VMs. You can get snapshots for vCloud VMs or vApps.
      .EXAMPLE
      Get-CIVapp "MyVApp" | Get-CISnapshot
      .EXAMPLE
      Get-CIVM "MyVM" | Get-CISnapshot
      .PARAMETER entity
      A VM or vApp returned from PowerCLI commands: Get-CIVM or Get-CIVapp
      .PARAMETER snapshotMemory
      Switch to Snapshot Memory of the VMs
      .PARAMETER quiesce
      Quiesce the filesystem before snapshot (Requires VMware tools)
    #>
    [CmdletBinding()]
    param
    (
        [parameter(Position=0,ValueFromPipeline=$true)]
        $entity
    )
    PROCESS
    {
        if (!$entity)
        {
            Get-CIVM | Get-CISnapshot
            return
        }
        $request = [System.Net.HttpWebRequest]::Create("$($entity.extensiondata.href)/snapshotSection")
        $request.Accept = "application/*+xml;version=5.1"
        $request.Headers.add("x-vcloud-authorization",$global:DefaultCIServers[0].SessionId)
        $response = $request.GetResponse()
        $streamReader = new-object System.IO.StreamReader($response.getResponseStream())
        [xml]$xmldata = $streamreader.ReadToEnd()
        $streamReader.close()
        $response.close()
        if ($xmldata.snapshotsection.snapshot)
        {
            $responseObj = new-object PSObject
            add-member -membertype NoteProperty -inputobject $responseObj -name "Entity" -value $entity.name
            # Apparently naming snapshots is not implemented in the API...
            #add-member -membertype NoteProperty -inputobject $responseObj -name "Name" -value $xmldata.snapshotsection.snapshot.name
            add-member -membertype NoteProperty -inputobject $responseObj -name "Size" -value $xmldata.snapshotsection.snapshot.size
            add-member -membertype NoteProperty -inputobject $responseObj -name "Created" -value $xmldata.snapshotsection.snapshot.created
            add-member -membertype NoteProperty -inputobject $responseObj -name "ExtensionData" -value $xmldata.snapshotsection

            return $responseObj
        }
        else {return}
    }
}

function Remove-CISnapshot
{
   <#
      .SYNOPSIS
      Removes a snapshot for a vCloud vApp or VM.
      .DESCRIPTION
      Removes a snapshot for a vCloud vApp or VM. vCloud Director 5.1 allows a single snapshot to be taken of VMs. You can remove snapshots for vCloud VMs or all VMs in a vApp.
      .EXAMPLE
      Get-CIVapp "MyVApp" | Remove-CISnapshot
      .EXAMPLE
      Get-CIVM "MyVM" | Remove-CISnapshot
      .PARAMETER entity
      A VM or vApp returned from PowerCLI commands: Get-CIVM or Get-CIVapp
    #>    
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="High")]
    param
    (
        [parameter(Position=0,ValueFromPipeline=$true)]
        $entity
    )
    PROCESS
    {
        if ($PSCmdlet.ShouldProcess("$($entity.name)"))
        {
            $request = [System.Net.HttpWebRequest]::Create("$($entity.extensiondata.href)/action/removeAllSnapshots")
            $request.Method = "POST"
            $request.Accept = "application/*+xml;version=5.1"
            $request.Headers.add("x-vcloud-authorization",$global:DefaultCIServers[0].SessionId)
            $response = $request.GetResponse()
            $streamReader = new-object System.IO.StreamReader($response.getResponseStream())
            [xml]$xmldata = $streamreader.ReadToEnd()
            $streamReader.close()
            $response.close()
        }
        return
    }
}

function New-CISnapshot
{
    <#
      .SYNOPSIS
      Creates a snapshot for a vCloud vApp or VM.
      .DESCRIPTION
      Creates a snapshot for a vCloud vApp or VM. vCloud Director 5.1 allows a single snapshot to be taken of VMs. Snapshotting a vApp snapshots all VMs within that vApp.
      .EXAMPLE
      Get-CIVapp "MyVApp" | New-CISnapshot
      .EXAMPLE
      Get-CIVM "MyVM" | New-CISnapshot
      .PARAMETER entity
      A VM or vApp returned from PowerCLI commands: Get-CIVM or Get-CIVapp
      .PARAMETER snapshotMemory
      Switch to Snapshot Memory of the VMs
      .PARAMETER quiesce
      Quiesce the filesystem before snapshot (Requires VMware tools)
     #>
    [CmdletBinding()]
    param
    (
        [parameter(Position=0,ValueFromPipeline=$true)]
        $entity,
        [parameter()]
        [switch]$snapshotMemory,
        [parameter()]
        [switch]$quiesce = $true
    )
    PROCESS
    {
        $request = [System.Net.HttpWebRequest]::Create("$($entity.extensiondata.href)/action/createSnapshot")
        $request.Method = "POST"
        $request.Accept = "application/*+xml;version=5.1"
        $request.Headers.add("x-vcloud-authorization",$global:DefaultCIServers[0].SessionId)
        
        $request.ContentType = "application/vnd.vmware.vcloud.createSnapshotParams+xml"

        # build our XML
        [xml]$postData = '<?xml version="1.0" encoding="UTF-8"?><vcloud:CreateSnapshotParams xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" />'
        $xmlName = $postData.CreateAttribute("name")
        $xmlMemory = $postData.CreateAttribute("memory")
        $xmlQuiesce = $postData.CreateAttribute("quiesce")
        
        $xmlName.Value = "Snapshot" # It doesn't appear that naming a snapshot does anything in vCD.
        $xmlMemory.Value = $snapshotMemory.toString().toLower()
        $xmlQuiesce.Value = $quiesce.toString().toLower()

        $postData.CreateSnapshotParams.Attributes.Append($xmlName) | Out-Null
        $postData.CreateSnapshotParams.Attributes.Append($xmlMemory) | Out-Null
        $postData.CreateSnapshotParams.Attributes.Append($xmlQuiesce) | Out-Null

        [byte[]]$xmlEnc = [System.Text.Encoding]::UTF8.GetBytes($postData.OuterXml)
        $request.ContentLength = $xmlEnc.length
        [System.IO.Stream]$requestStream = $request.GetRequestStream()
        $requestStream.write($xmlEnc, 0, $xmlEnc.Length)
        $requestStream.Close()

        $response = $request.GetResponse()
        $streamReader = new-object System.IO.StreamReader($response.getResponseStream())
        [xml]$xmldata = $streamreader.ReadToEnd()
        $streamReader.close()
        $response.close()

        # This is just temporary. Goal would be to check task success, then return snapshot or failure msg.
        return $entity | Get-CISnapshot
    }
}

function Set-CISnapshot
{
   <#
      .SYNOPSIS
      Sets options for a snapshot for a vCloud vApp or VM.
      .DESCRIPTION
      Sets options for a snapshot for a vCloud vApp or VM. vCloud Director 5.1 allows a single snapshot to be taken of VMs. You can set snapshot options for vCloud VMs or all VMs in a vApp.
      .EXAMPLE
      Get-CIVapp "MyVApp" | Set-CISnapshot -revertToCurrent
      .EXAMPLE
      Get-CIVM "MyVM" | Get-CISnapshot -revertToCurrent
      .PARAMETER entity
      A VM or vApp returned from PowerCLI commands: Get-CIVM or Get-CIVapp
      .PARAMETER revertToCurrent
      Reverts VM to snapshot.
    #>  
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="High")]
    param
    (
        [parameter(Position=0,ValueFromPipeline=$true)]
        $entity,
        [parameter()]
        [switch]$revertToCurrent
    )
    PROCESS
    {
        if ($PSCmdlet.ShouldProcess("$($entity.name)"))
        {
            $request = [System.Net.HttpWebRequest]::Create("$($entity.extensiondata.href)/action/revertToCurrentSnapshot")
            $request.Method = "POST"
            $request.Accept = "application/*+xml;version=5.1"
            $request.Headers.add("x-vcloud-authorization",$global:DefaultCIServers[0].SessionId)


            $response = $request.GetResponse()
            $streamReader = new-object System.IO.StreamReader($response.getResponseStream())
            [xml]$xmldata = $streamreader.ReadToEnd()
            $streamReader.close()
            $response.close()


        }
        return
    }
}