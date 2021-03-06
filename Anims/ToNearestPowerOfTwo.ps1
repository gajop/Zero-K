# Functions:
# 1) Extend or Trim PNG images into power-of-2 size (with transparent background & transparent enabled PNG32 format),
#    - while try to maintain Hotspots, dimension and aspect ratio across a cursor type (eg: cursorrevive,cursornormal,ect).
# 2) Provide a reusable code.
# written by "xponen", 30/April/2015


# ----------------------------------------
# Configuration
$srcfolder = "C:\Users\User\DOCUME~1\MYGAME~1\Spring\games\ZERO-K~1.SDD\Anims\"
$destfolder = "C:\Users\User\DOCUME~1\MYGAME~1\Spring\games\ZERO-K~1.SDD\Anims\Test\"
$im_convert_exe = "C:\PROGRA~1\IMAGEM~1.1-Q\convert.exe"
$src_filter = "*.png"
$dest_ext = "png"
$logfile = "C:\Users\User\DOCUME~1\MYGAME~1\Spring\games\ZERO-K~1.SDD\Anims\Test\convert_data.txt"
$logfileB = "C:\Users\User\DOCUME~1\MYGAME~1\Spring\games\ZERO-K~1.SDD\Anims\Test\convert_datab.txt"
# ----------------------------------------

#Limitation:
# 1) Output folder need to be empty to avoid recursive issue
# 2) ImageMagick need DOS shortpath 
#    (tips:press "Shift + RightClick", click "open cmd prompt..", paste: "for %I in (.) do echo %~sI", press "Enter" )
# 3) input image is assumed to be PNG32 (8-bit depth with transparency), and srgb colorspace, and output PNG32 as well

#tool: http://www.imagemagick.org/ , MS PowerShell
#Source http://viziblr.com/news/2012/1/11/recursive-batch-image-conversion-with-powershell-and-imagema.html

# ---------FUNCTIONS/METHODS--------------
Function CropImage($imagePath, $outputPath,$NWCrop,$oW, $oH,$nW,$nH)
{
    # http://www.imagemagick.org/Usage/crop/#chop
    if ($NWCrop)
    {
        # Trim bottom-right border
        $bottom = $oH-$nW
        $right = $oW-$nH
        $cmdline =  $im_convert_exe `
                + " `"" + $imagePath  + "`"" `
                + " -gravity southeast -chop " + ($right) + "x" +($bottom) `
                + " png32:`"" + $outputPath + "`" "
        invoke-expression -command $cmdline
        
    } else {
        # Trim all border
        $bottom = [Math]::Ceiling(($oH-$nH)/2)
        $right = [Math]::Ceiling(($oW-$nW)/2)
        $top = [Math]::Floor(($oH-$nH)/2)
        $left = [Math]::Floor(($oW-$nW)/2)
        $cmdline =  $im_convert_exe `
                + " `"" + $imagePath  + "`"" `
                + " -gravity southeast -chop " + $right + "x" +$bottom `
                + " -gravity northwest -chop " + $left + "x" +$top `
                + " png32:`"" + $outputPath + "`" "
        invoke-expression -command $cmdline
    }
    # Note: "png32:" (or "-type TruecolorMatte") to force enable transparency channel.
    # http://www.imagemagick.org/Usage/formats/#png_quality
}

Function ExtendImage($imagePath, $outputPath,$newHotspot, $newWidth, $newHeight)
{
    #http://www.imagemagick.org/Usage/crop/#splice
    # Add bottom-right border
    if ($newHotspot -Match "NorthWest"){
        $cmdline =  $im_convert_exe `
                    + " `"" + $imagePath  + "`"" `
                    + " -background none" `
                    + " -gravity southeast -splice " + $newWidth + "x" +$newHeight `
                    + " png32:`"" + $outputPath + "`" "
        invoke-expression -command $cmdline
    }else {
        # http://www.johndcook.com/blog/2008/05/19/rounding-and-integer-division-in-powershell/
        # http://www.computerperformance.co.uk/powershell/powershell_math.htm
        # Add border on all sides
        $bottom = [Math]::Ceiling($newHeight/2)
        $right = [Math]::Ceiling($newWidth/2)
        $top = [Math]::Floor($newHeight/2)
        $left = [Math]::Floor($newWidth/2)
        $cmdline =  $im_convert_exe `
                    + " `"" + $imagePath  + "`"" `
                    + " -background none" `
                    + " -gravity northwest -splice " + $left + "x" +$top `
                    + " -gravity southeast -splice " + $right + "x" +$bottom `
                    + " png32:`"" + $outputPath + "`""
        invoke-expression -command $cmdline
    }
}

Function ReadImageDimension($_srcname)
{
    # Invoke ImageMagick to output image info
    #http://www.fmwconcepts.com/imagemagick/tidbits/image.php#power2_pad
    $test0= $im_convert_exe + " `"" + $_srcname  + "`"" +" -ping -format `"wxh`"" + $logfileB
    invoke-expression -command $test0
    
    #https://technet.microsoft.com/en-us/library/ee692806.aspx
    # Read dimension from debug file
    $a = (Get-Content $logfileB –totalcount 1).Split(", ")
    [int]$w = [convert]::ToInt32($a[4], 10)
    [int]$h = [convert]::ToInt32($a[5], 10)
    
    # Scan where image actually begin/end (from debug file)
    $first = 1
    $xMin = 999
    $xMax = -1
    $yMin = 999
    $yMax = -1
    foreach ($lines in $(Get-Content $logfileB))
    {
        #skip header
        if ($first -eq 0)
        {
            $line = $lines.Split(":")
            # find non-transparent pixel. assuming #xxxxxx00 is transparent (for 8-bit colour)
            # http://www.imagemagick.org/Usage/files/#txt
            if (-not ($line[1] -Match "#\d\d\d\d\d\d00 "))
            {
                $coord =  $line[0].Split(",")
                [int]$x = [convert]::ToInt32($coord[0], 10)
                [int]$y = [convert]::ToInt32($coord[1], 10)
                # http://www.powershellpro.com/powershell-tutorial-introduction/powershell-tutorial-conditional-logic/
                if ($x -lt $xMin) { $xMin = $x }
                if ($x -gt $xMax) { $xMax = $x }
                if ($y -lt $yMin) { $yMin = $y }
                if ($y -gt $yMax) { $yMax = $y }
            }
        }
        $first = 0
    }
    
    return $w, $h, $xMin, $xMax, $yMin, $yMax
}

$spd_size = 0
$spd_result = 0
Function NextPow2($oriW, $oriH)
{
    #http://stackoverflow.com/questions/466204/rounding-up-to-nearest-power-of-2
    if ($spd_size -eq $oriW) {
        $pow2w = $spd_result
    } else {
        $pow2w = 1
        do {
          $pow2w*=2
        }
        while ($pow2w-lt$oriW)
        $spd_size = $oriW
        $spd_result = $pow2w
    }
    if ($spd_size -eq $oriH) {
        $pow2h = $spd_result
    } else {
        $pow2h = 1
        do {
          $pow2h*=2
        }
        while ($pow2h-lt $oriH)
        $spd_size = $oriH
        $spd_result = $pow2h
    }
    return $pow2w,$pow2h
}

Function ReadHotspotInfo($folder,$cursorType)
{
    # Read image's hotspot
    $hotspot = "Center"
    $crsrConf = $folder + "\" + $cursorType + ".txt"
    if (test-path ($crsrConf))
    {
        $a = (Get-Content $crsrConf –totalcount 1).Split(" ")
        if ($a[1] -Match "TopLeft"){
           $hotspot = "NorthWest"
        }
    }else 
    {
        #default hotspot, see Spring/rts/Game/UI/MouseHandler.cpp:LoadCursors()
        if ($cursorType -Match "cursornormal"){
           $hotspot = "NorthWest"
        }
    }

    return $hotspot
}
# ----------------------------------------

# -----------EXECUTION--------------------

# Get cursor sets (eg: cursorreclaim, cursorunload)
[System.Collections.ArrayList]$IconType  = @()
foreach ($srcitem in $(Get-ChildItem $srcfolder -include $src_filter -recurse))
{
    $srcname = $srcitem.fullname
    $_srcFolder = [System.IO.Path]::GetDirectoryName($srcname)
    $cursorName = [System.IO.Path]::GetFileNameWithoutExtension($srcname)
    $cursorName = ($cursorName.Split("_"))[0]
    $truncName = $_srcFolder + "\" + $cursorName
    if (-not $IconType.Contains($truncName)) {
        # use Collection list, ref: http://www.jonathanmedd.net/2014/01/adding-and-removing-items-from-a-powershell-array.html
        $IconType.Add($truncName)
    }
}

# Speedup
# Hash table: http://ss64.com/ps/syntax-hash-tables.html
$imgWidth  = @{}
$imgHeight  = @{}
$imgXmax  = @{}
$imgXmin  = @{}
$imgYmax  = @{}
$imgYmin  = @{}

#Echo Info
$fp = New-Item -ItemType file $logfile -force
$count=0
# Perform conversion
foreach ($srcPath in $IconType)
{
    $info = [string]::Format( "`t Scanning dimensions of: {0}", $srcPath)
    echo $info

    # Get folder & icontype name
    $srcPath =  $srcPath + ".abc"
    $_srcFolder = [System.IO.Path]::GetDirectoryName( $srcPath )
    $cursorName = [System.IO.Path]::GetFileNameWithoutExtension($srcPath) + $src_filter

    # Weighted TopLeft or Center?
    $cmnHotspot = ReadHotspotInfo $_srcFolder ([System.IO.Path]::GetFileNameWithoutExtension($srcPath))

    # Get common Pow2 size
    $maxCmnW = -1
    $maxCmnH = -1
    foreach ($srcitem in $(Get-ChildItem $_srcFolder -filter $cursorName))
    {
        $srcname = $srcitem.fullname
        
        # Find the next closest power-of-2
        $w,$h,$xMin, $xMax, $yMin, $yMax = ReadImageDimension $srcname
        $pow2w,$pow2h = NextPow2 $w $h
        
        # Reuse value later
        $imgWidth.Add($srcname, $w)
        $imgHeight.Add($srcname, $h)
        $imgXmax.Add($srcname, $xMax)
        $imgXmin.Add($srcname, $xMin)
        $imgYmax.Add($srcname, $yMax)
        $imgYmin.Add($srcname, $yMin)
        
        # Extend or trim? (checking for trim)
        $prv_pow2w = $pow2w/2
        $prv_pow2h = $pow2h/2
        $cropSide =  (($xMax  - ($w - $prv_pow2w)/2) -lt $prv_pow2w) -and (($xMin - ($w - $prv_pow2w)/2) -gt 0)
        $cropUpDown = (($yMax - ($h - $prv_pow2h)/2) -lt $prv_pow2h) -and (($yMin - ($h - $prv_pow2h)/2) -gt 0)
        $cropRight = ($xMax -lt $prv_pow2w) 
        $cropBottom = ($yMax -lt $prv_pow2h)
        $cropNW = $cropRight -and $cropBottom -and ($cmnHotspot -Match "NorthWest")
        $cropCenter = $cropUpDown -and $cropSide -and ($cmnHotspot -Match "Center")

        if ($cropNW -or $cropCenter) {
            $pow2w = $prv_pow2w
            $pow2h = $prv_pow2h
        }
        
        # What is common pow2 size?
        if ($pow2w -gt $maxCmnW) { $maxCmnW = $pow2w }
        if ($pow2h -gt $maxCmnH) { $maxCmnH = $pow2h }
        
        # Show progress
        $partial = $srcitem.FullName.Substring( $srcfolder.Length )
        $info = [string]::Format( "{0} `t {1}x{2}",$partial, $pow2w,$pow2h)
        echo $info
    }
    
    # Conversion
    foreach ($srcitem in $(Get-ChildItem $_srcFolder -filter $cursorName))
    {
        $srcname = $srcitem.fullname
        
        # Construct the filename and filepath for the output
        $partial = $srcitem.FullName.Substring( $srcfolder.Length )
        $destname = $destfolder + $partial
        $destname= [System.IO.Path]::ChangeExtension( $destname , $dest_ext )
        $destpath = [System.IO.Path]::GetDirectoryName( $destname )
    
        # image dimensions & resize target
        $w = $imgWidth.($srcname)
        $h = $imgHeight.($srcname)
        $xMax = $imgXmax.($srcname)
        $xMin = $imgXmin.($srcname)
        $yMax = $imgYmax.($srcname)
        $yMin = $imgYmin.($srcname)
        $pow2w = $maxCmnW
        $pow2h = $maxCmnH
        $hotspot = $cmnHotspot
    
        # Skip good images
        $needChange = (-not ($pow2h -eq $h -and $pow2w -eq $w))
        if ($needChange)
        {
            # Extend or trim? (checking for trim)
            # http://www.powershellpro.com/powershell-tutorial-introduction/powershell-tutorial-conditional-logic/
            $cropSide =  (($xMax  - ($w - $pow2w)/2) -lt $pow2w) -and (($xMin - ($w - $pow2w)/2) -gt 0)
            $cropUpDown = (($yMax - ($h - $pow2h)/2) -lt $pow2h) -and (($yMin - ($h - $pow2h)/2) -gt 0)
            $cropRight = ($xMax -lt $pow2w) 
            $cropBottom = ($yMax -lt $pow2h)
            $shrink = ($pow2w -le $w) -and ($pow2h -le $h)
            $cropNW = $cropRight -and $cropBottom -and $shrink -and ($hotspot -Match "NorthWest")
            $cropCenter = $cropUpDown -and $cropSide -and $shrink -and ($hotspot -Match "Center")
        
            # Create the destination path if it does not exist
            if (-not (test-path $destpath))
            {
                New-Item $destpath -type directory | Out-Null
            }
            
            # Crop or extend to target pow2?
            if ($cropNW -or $cropCenter) {
            
                if ($cropNW){ $action = "NWCROP" }
                else { $action = "CECROP" }
                CropImage $srcname $destname $cropNW $w $h $pow2w $pow2h
            } else {
            
                if ($hotspot -Match "NorthWest"){ $action = "NWEXTEND" }
                else { $action = "CEEXTEND" }
                ExtendImage $srcname $destname $hotspot ($pow2w-$w) ($pow2h-$h)
            }

            # Get information about the output file    
            $destitem = Get-item $destname

            # Show and record information comparing the input and output files
            $info = [string]::Format( "{0} `t {1} `t {2} `t {3} `t {4}byte `t {5}byte `t {6}x{7} `t {8}x{9}", $count, 
        	$action, $srcname, $destname, $srcitem.Length ,  $destitem.Length,$w,$h,$pow2w,$pow2h)
            echo $info
            Add-Content $fp $info

        }
        $count=$count+1
    }
}