function Get-MultiTouchMaximum
{
    <#
    .Synopsis
    Gets the number of fingers that can be used on a multitouch device.

    .Description
    Gets the number of fingers that can be used on a multitouch device. This
    function does not have any parameters.

    .Notes
    This function uses the GetSystemMetrics function with an index of 95 (SM_MaximumTouches).

    .Example
    Get-MultiTouchMaximum       

    .Link
    http://msdn.microsoft.com/en-us/library/ms724385(VS.85).aspx
    #>
    param()
    $script:SystemMetrics::GetSystemMetrics(95)
}