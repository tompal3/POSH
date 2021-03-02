
[CmdletBinding()]
Param(
    # PASSED PARAMETERS
    [Parameter(
        Position = 1,
        Mandatory = $TRUE,
        HelpMessage = 'The path of .ncc file'
    )]        
    [string]$FileName, 
    [Parameter(
        Position = 2,
        Mandatory = $FALSE,
        HelpMessage = 'output file path. (defaults to filepath)'
    )]
    [string]$OutFile = $FileName,
    [Parameter(
        Position = 3,
        Mandatory = $FALSE,
        HelpMessage = 'debug message'
    )]
    [switch]$WhatIf = $FALSE
)
 
# INITIALIZE VARIABLES
$ChangeHash = @()
$ToolRegex = [regex]::new('\(TOOL \d{1,3}')
$DescriptionRegex = [regex]::new('T\d{1,3} M6')
$Marker = $FALSE
$Content = Get-Content $FileName 

# NEW OBJECT FUNCTION
function New-LineObject {
    param (
        [string]$Line,
        [string]$NewStruct,
        [string]$ToolNumber
    )

    # NEW OBJECT 
    $LineObject = New-Object psobject -Property @{

    Line = $null
    NewStruct = $null
    ToolNumber = $null

    }

    # ATRIBUTES  
    $LineObject.Line = $Line
    $LineObject.NewStruct = $NewStruct 
    $LineObject.ToolNumber = $ToolNumber 
    
    # RETURN OBJECT
    return $LineObject
}

# FIRST LOOP TO GET CHANGABLE TOOLS
FOREACH ($Line in $Content)  { 
    IF ($Line -like "*(T-START)*") {
        $Marker=$TRUE
        CONTINUE
    }
    ELSEIF ($line -like "*(T-END)*") {
        $MARKER=$FALSE
        BREAK
    }
    IF ($Marker -EQ $TRUE -AND $Line -MATCH $ToolRegex) {
        # GET TOOL NUMBER AND TOOL DESCRIPTION
        $ToolNumber = ($ToolRegex.Match($Line).Value).Replace('(TOOL ','')
        $ToolDescription = $Line.Replace($ToolRegex.Match($Line).Value + " - ", "")

        # FORM NEW TOOL STRUCT
        $NewStruck = -JOIN ("(T:$ToolNumber)(00-00-00)(T:$ToolNumber $ToolDescription")

        # JOIN EVERYTHING TO NEW OBJECT
        $ChangeHash += New-LineObject -Line $Line -NewStruct $NewStruck -ToolNumber $ToolNumber

    }
}

# SECOND LOOP TO CHANGE TOOLSCHANGE LINE M6
FOREACH ($Line IN $Content) {
    if ($Line -match $DescriptionRegex) {

        # GET TOOL NUMBER 
        $ToolNumber = (($DescriptionRegex.Match($Line).Value).replace(' M6','')).Replace('T','')

        # FORM NEW TOOL DESCRIPTION
        $NewStruck = -JOIN (($Line.Split('(')[0]) , ($ChangeHash| where {$_.ToolNumber -eq $ToolNumber}).line)

        # JOIN EVERYTHING TO NEW OBJECT
        $ChangeHash += New-LineObject -Line $Line -NewStruct $NewStruck -ToolNumber $ToolNumber
        
    }

} 

# DO REPLACEMENT FOR EACH SEPARATE LINE OF FILE
$ChangedContent = FOREACH ($Line IN $Content) {
                        $ChangeHash | % {

                            # FOR EACH LINE LOOK IF IT IS CHANGABLE
                            IF ($Line -LIKE $_.Line) {

                                # DO REPLACMENT
                                $Line = $Line.Replace($_.Line, $_.NewStruct)

                                # PRINT THIS LINE IF DEBUG ON
                                IF ($WhatIf -EQ $TRUE) {
                                Write-Host "Changing line $($_.Line) TO $($_.NewStruct)" -BackgroundColor Black -ForegroundColor Green
                                }
                            }
                        }
                        $Line    
                    } 

# EXECUTE REPLACMENT
$ChangedContent | Set-Content -Path $OutFile -WhatIf:$WhatIf
