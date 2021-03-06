function Write-TypeView
{
    <#
    .Synopsis
        Writes extended type view information
    .Description
        PowerShell has a robust, extensible types system.  With Write-TypeView, you can easily add extended type information to any type.
        This can include:  
            The default set of properties to display (-DefaultDisplay)
            Sets of properties to display (-PropertySet)
            Serialization Depth (-SerializationDepth)
            Virtual methods or properties to add onto the type (-ScriptMethod, -ScriptProperty and -NoteProperty)
            Method or property aliasing (-AliasProperty)
    .Link
        Out-TypeView
    .Link
        Add-TypeView
    #>
    [OutputType([string])]
    param(    
    # The name of the type
    #|Default MyCustomTypeName
    #|MaxLength 255
    [Parameter(Mandatory=$true,
        ValueFromPipelineByPropertyName=$true,
        Position=0)]
    [String]
    $TypeName,
    
    # A collection of virtual method names and the script blocks that will be used to run the virtual method.
    [ValidateScript({
        if ($_.Keys | ? {$_-isnot [string]}) {
            throw "Must provide the names of script methods"
        }
        if ($_.Values | ? {$_ -isnot [ScriptBlock]}) {
            throw "Must provide script blocks to handle each method"
        }
        return $true
    })]
    [Hashtable]$ScriptMethod,

    # A Collection of virtual property names and the script blocks that will be used to get the property values.
    [ValidateScript({
        if ($_.Keys | ? {$_ -isnot [string]}) {
            throw "Must provide the names of script properties"
        }
        if ($_.Values | ? {$_-isnot [ScriptBlock]} ) {
            throw "Must provide script blocks to handle each property"
        }
        return $true
    })]   
    [Hashtable]$ScriptProperty,    
    
    # A collection of fixed property values.
    [ValidateScript({
        if ($_.Keys | ? { $_-isnot [string] } ) {
            throw "Must provide the names of note properties"
        }
        return $true
    })]
    [Hashtable]$NoteProperty,

    # A collection of property aliases
    [ValidateScript({
        if ($_.Keys | ? { $_-isnot [string]}) {
            throw "Must provide the names of alias properties"
        }
        if ($_.Keys | ? {$_-isnot [string]}) {
            throw "Must provide the names of properties to alias"
        }
        return $true
    })]
    [Hashtable]$AliasProperty,

    # A collection of code methods.  A code method maps a 
    [ValidateScript({
        if ($_.Keys | ? {$_-isnot [string]}) {
            throw "Must provide the names of code methods"
        }
        if ($_.Values | ? {$_-isnot [Reflection.MethodInfo]}) {
            throw "Must provide the static method to run"
        }
        return $true
    })]
    [Hashtable]$CodeMethod,
    
    # Any code properties for an object
    [ValidateScript({
        if ($_.Keys |? {$_-isnot [string]}) {
            throw "Must provide the names of code properties"
        }
        if ($_.Values | ? {$_-isnot [Reflection.MethodInfo]}) {
            throw "Must provide the static method to run"
        }
        return $true
    })]
    [Hashtable]$CodeProperty,
    
    # The default display.  If only one propertry is used, 
    # this will set the default display property.  If more than one property is used, 
    # this will set the default display member set
    [string[]]$DefaultDisplay,
    
    # The ID property
    [string]$IdProperty,
    
    # The serialization depth.  If the type is deserialized, this is the depth of subpropeties
    # that will be stored.  For instance, a serialization depth of 3 would storage an object, it's
    # subproperties, and those objects' subproperties.  You can use the serialization depth 
    # to minimize the overhead of moving objects back and forth across the remoting boundary, 
    # or to ensure that you capture the correct information.      
    [int]$SerializationDepth = 2,
       
    # The reserializer type used for recreating a deserialized type
    [Type]$Reserializer,
    
    # Property sets define default views for an object.  A property set can be used with Select-Object
    # to display just that set of properties.
    [ValidateScript({
        if ($_.Keys | ? {$_ -isnot [string] } ) {
            throw "Must provide the names of property sets"
        }
        if ($_.Values | 
            Where-Object {$_ -isnot [string] -and  $_ -isnot [Object[]] }){
            throw "Must provide a name or list of names for each property set"
        }
        return $true
    })]
    [Hashtable]$PropertySet,
    
    
    # Will hide any properties in the list from a display
    [string[]]$HideProperty
    )
    
    
    process {
        $memberSetXml = ""
        
        #region Construct Member Set
        if ($psBoundParameters.ContainsKey('SerializationDepth') -or
            $psBoundParameters.ContainsKey('IdProperty') -or 
            $psBoundParameters.ContainsKey('DefaultDisplay')) {
            $defaultDisplayXml = if ($psBoundParameters.ContainsKey('DefaultDisplay')) {
$referencedProperties = "<Name>" + ($defaultDisplay -join "</Name>
                        <Name>") + "</Name>"
"                <PropertySet>
                    <Name>DefaultDisplayPropertySet</Name>
                    <ReferencedProperties>
                        $referencedProperties
                    </ReferencedProperties>
                </PropertySet>

"                            
            }
            $serializationDepthXml = if ($psBoundParameters.ContainsKey('SerializationDepth')) {
                "
                <NoteProperty>
                    <Name>SerializationDepth</Name>
                    <Value>$SerializationDepth</Value>
                </NoteProperty>"
            } else {$null } 
            
            $ReserializerXml = if ($psBoundParameters.ContainsKey('Reserializer'))  {
"
                <NoteProperty>
                    <Name>TargetTypeForDeserialization</Name>
                    <Value>$Reserializer</Value>
                </NoteProperty>

"                
            } else { $null }
            
            $memberSetXml = "
            <MemberSet>
                <Name>PSStandardMembers</Name>
                <Members>
                    $defaultDisplayXml
                    $serializationDepthXml
                    $reserializerXml                    
                </Members>
            </MemberSet>
            "
        }
        #endregion Construct Member Set
        
        #region PropertySetXml
        $propertySetXml  = if ($psBoundParameters.PropertySet) {
            foreach ($NameAndValue in $PropertySet.GetEnumerator()) {
                $referencedProperties = "<Name>" + ($NameAndValue.Value -join "</Name>
                    <Name>") + "</Name>"
            "<PropertySet>
                <Name>$([Security.SecurityElement]::Escape($NameAndValue.Key))</Name>
                <ReferencedProperties>
                    $referencedProperties
                </ReferencedProperties>
            </PropertySet>"                              
            }
        } else {
            ""
        }
        #endregion
                    


        #region Aliases        
        $aliasPropertyXml = if ($psBoundParameters.AliasProperty) {            
            foreach ($NameAndValue in $AliasProperty.GetEnumerator()) {
                $isHiddenChunk = if ($HideProperty -contains $NameAndValue.Key) {
                    'IsHidden="true"'
                } else { ""}
                
                "
            <AliasProperty $isHiddenChunk>
                <Name>$([Security.SecurityElement]::Escape($NameAndValue.Key))</Name>
                <ReferencedMemberName>$([Security.SecurityElement]::Escape($NameAndValue.Value))</ReferencedMemberName>
            </AliasProperty>"                              
            }
        } else {
            ""
        }
        #endregion Aliases
        $codeMethodXml = if ($psBoundParameters.CodeMethod) {
            foreach ($NameAndValue in $CodeMethod.GetEnumerator()) {
                $isHiddenChunk = if ($HideProperty -contains $NameAndValue.Key) {
                    'IsHidden="true"'
                } else { ""}
                
                "
            <CodeMethod $isHiddenChunk>
                <Name>$([Security.SecurityElement]::Escape($NameAndValue.Key))</Name>
                <CodeReference>
                    <TypeName>$($NameAndValue.Value.DeclaringType)</TypeName>
                    <MethodName>$($NameAndValue.Value.Name)</MethodName>
                </CodeReference>
            </CodeMethod>"                        
            }
        } else {
            ""
        }
        $codePropertyXml = if ($psBoundParameters.CodeProperty) {
            foreach ($NameAndValue in $CodeProperty.GetEnumerator()) {
                $isHiddenChunk = if ($HideProperty -contains $NameAndValue.Key) {
                    'IsHidden="true"'
                } else { ""}
                
                "
            <CodeProperty $IsHiddenChunk>
                <Name>$([Security.SecurityElement]::Escape($NameAndValue.Key))</Name>
                <CodeReference>
                    <TypeName>$($NameAndValue.Value.DeclaringType)</TypeName>
                    <MethodName>$($NameAndValue.Value.Name)</MethodName>
                </CodeReference>
            </CodeProperty>"                        
            }
        } else {
            ""
        }
        $NotePropertyXml = if ($psBoundParameters.NoteProperty) {
            foreach ($NameAndValue in $NoteProperty.GetEnumerator()) {
                $isHiddenChunk = if ($HideProperty -contains $NameAndValue.Key) {
                    'IsHidden="true"'
                } else { ""}
                
                "
            <NoteProperty $isHiddenChunk>
                <Name>$([Security.SecurityElement]::Escape($NameAndValue.Key))</Name>
                <Value>$([Security.SecurityElement]::Escape($NameAndValue.Value))</Value>
            </NoteProperty>"                        
            }
        } else {
            ""
        }               
        $scriptMethodXml = if ($psBoundParameters.ScriptMethod) {
            foreach ($methodNameAndCode in $ScriptMethod.GetEnumerator()) {
                $isHiddenChunk = if ($HideProperty -contains $methodNameAndCode.Key) {
                    'IsHidden="true"'
                } else { ""}
                "
            <ScriptMethod $isHiddenChunk>
                <Name>$($methodNameAndCode.Key)</Name>
                <Script>
                    $([Security.SecurityElement]::Escape($methodNameAndCode.Value))
                </Script>
            </ScriptMethod>"                        
            }
        } else {
            ""
        }
        
        #region Script Property
        $scriptPropertyXml = if ($psBoundParameters.ScriptProperty) {
            foreach ($propertyNameAndCode in $ScriptProperty.GetEnumerator()) {
                $isHiddenChunk = if ($HideProperty -contains $propertyNameAndCode.Key) {
                    'IsHidden="true"'
                } else { ""}
                "
            <ScriptProperty $isHiddenChunk>
                <Name>$($propertyNameAndCode.Key)</Name>
                <GetScriptBlock>
                    $([Security.SecurityElement]::Escape($propertyNameAndCode.Value))
                </GetScriptBlock>
            </ScriptProperty>"                        
            }
        }
        
        $innerXml = @($memberSetXml) + $propertySetXml + $aliasPropertyXml + $codePropertyXml + $codeMethodXml + $scriptMethodXml + $scriptPropertyXml + $NotePropertyXml
        
        $innerXml = ($innerXml  | ? {$_} ) -join ([Environment]::NewLine)
        "
    <Type>
        <Name>$TypeName</Name>
        <Members>
            $innerXml
        </Members>
    </Type>"                
    }

} 
