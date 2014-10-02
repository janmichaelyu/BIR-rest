xquery version "1.0-ml";

module namespace bir = "http://www.bir.gov.ph/ml/lib";

declare variable $LINESEP as xs:string := "&#x0d;";

declare variable $MONTHS := ("jan","feb","mar","apr","may","june","july","aug","sept","oct","nov","dec");

declare function bir:month2nr($string as xs:string) as xs:string
{
  fn:format-number(fn:index-of($MONTHS,$string),"00")
};

declare function bir:iso-date(
  $string as xs:string
) as xs:string
{
  if (fn:matches($string, "\d{2}/\d{2}/\d{4}")) 
  then let $dates := fn:tokenize($string,"/")
    return fn:concat($dates[3],"-",$dates[1],"-",$dates[2])
  else if (fn:matches($string, "\d{2}-[A-Za-z]+-\d{2}")) 
  then let $dates := fn:tokenize($string,"-")
    let $year-prefix := if (xs:integer($dates[3]) > 35) then "19" else "20"
    return fn:concat($year-prefix,$dates[3],"-",bir:month2nr($dates[2]),"-",$dates[1])
  else if (fn:matches($string, "\d{2}-\d{2}-\d{2}")) 
  then let $dates := fn:tokenize($string,"-")
    let $year-prefix := if (xs:integer($dates[3]) > 35) then "19" else "20"
    return fn:concat($year-prefix,$dates[3],"-",$dates[2],"-",$dates[1])
  else if (fn:matches(fn:lower-case($string), "present")) 
  then "2050-01-01"
  else $string
};

declare function bir:clean-string(
    $str as xs:string
) as xs:string
{
    fn:replace($str,"(CONTINUATION)","")
};

declare function bir:simplify($str as xs:string) as xs:string
{
  fn:normalize-space(fn:replace(fn:replace($str, '" ', ""), ' "', ""))
};

declare function bir:load-file(
    $params as map:map,
    $collection as xs:string
) as node()*
{
    let $file := map:get($params, "fileName")
    let $start-date := map:get($params,"start")
    let $end-date := map:get($params,"end")
    let $sec := map:get($params,"sec")
    
    let $_ := xdmp:log(fn:concat("Processing file ", $file),"debug")
    let $iso-start-date := bir:iso-date($start-date)
    let $iso-end-date := bir:iso-date($end-date)
    
    let $sheet := fn:tokenize($file,"\.")[last()-2]
    let $doc := xdmp:document-get($file)
    
    let $map := map:map()
    let $rdo-nr := ""
    let $rdo-label := ""
    let $barangay := ""
    let $street := ""
    let $vicinity := ""
    let $class := ""
    let $rev := 0.0
    let $condomode := fn:false()
    let $note := fn:false()
    let $skip := fn:false()
    for $raw-line at $i in fn:tokenize($doc, $LINESEP)
    let $line := fn:normalize-space($raw-line)
    return (
        if ($line = "")
        then ()
        (: RDO No. /NAME           :          44 - TAGUIG/PATEROS      ;;;;;:)
        else if (fn:starts-with(fn:upper-case($line), "RDO NO.") or fn:starts-with(fn:upper-case($line), "RD NO."))
        then (
            let $fields := fn:tokenize($line, ";")
            let $nr_sep :=
            if (fn:contains($fields[1],":")) then ":"
            else if (fn:starts-with(fn:upper-case($fields[1]), "RD NO.")) 
            then "RD NO." 
            else "RDO NO."
                let $subfields := fn:tokenize(fn:upper-case($fields[1]),"-")
                let $nr := fn:normalize-space(fn:substring-after($subfields[1],$nr_sep))
                let $label := fn:concat($nr, ". ",
                if ($subfields[2]) 
                then fn:normalize-space(fn:string-join($subfields[position() ge 2]," - ")) 
                else fn:normalize-space($fields[2])) 
                return (
                    xdmp:set($skip, fn:true()),
                    xdmp:set($note, fn:false()),
                    xdmp:set($rdo-nr, $nr),
                    xdmp:set($rdo-label,$label),
                    xdmp:set($barangay,""),
                    xdmp:set($street,""),
                    xdmp:set($vicinity,""),
                    xdmp:set($class,""),
                    xdmp:set($rev,0.0),
                    xdmp:set($condomode,fn:false())(:,
                    xdmp:log(fn:concat("RDO NR=",$rdo-nr," label=",$rdo-label),"debug"):)
                )
        )
        else if (fn:starts-with($line, "BARANGAY:") 
        or fn:starts-with($line, "BARANGAY :") 
        or fn:starts-with($line, "BARANGAYS:"))
        then (
            let $fields := fn:tokenize($line, ";")
            let $extract := (
                if ($fields[1])
                then (
                    let $recs := fn:tokenize($fields[1],":")
                    return xdmp:set($barangay, bir:clean-string(fn:normalize-space($recs[2])))
                )
                else ()
            )
            return (
                xdmp:set($skip, fn:false()),
                xdmp:set($note,fn:false()),
                xdmp:set($street, ""), 
                xdmp:set($vicinity, ""),
                xdmp:set($class, ""), 
                xdmp:set($rev, ""), 
                xdmp:set($condomode, fn:false())
            )
        )
        else if ($skip eq fn:true()) then ()
        else if (starts-with($line, "***CONDO***"))
        then (xdmp:set($street, ""), 
            xdmp:set($note,fn:false()),
            xdmp:set($vicinity, ""),
            xdmp:set($class, ""), 
            xdmp:set($rev, ""), 
            xdmp:set($condomode, fn:true())
        )
        else if (fn:starts-with(fn:upper-case($line), ";V I C I N I T Y;") or
            fn:starts-with(fn:upper-case($line), "STREET NAME/;") or 
            fn:starts-with(fn:upper-case($line), "SUBDIVISION;") or 
            fn:starts-with(fn:upper-case($line), "SUBDIVISIONS;") or 
            fn:starts-with(fn:upper-case($line), "ZONE : "))
        then ()
        else if (fn:starts-with(fn:upper-case($line), "NOTE"))
        then (xdmp:log("NOTE FOUND","debug"),
            xdmp:set($note,fn:true()))
        else if (fn:starts-with(fn:upper-case($line), "APD*") or fn:starts-with(fn:upper-case($line), " APD*"))
        then (xdmp:log("APD* FOUND","debug"),
            xdmp:set($note,fn:true()))
        else if (fn:starts-with(fn:upper-case($line), "*ZONE") or fn:starts-with(fn:upper-case($line), " *ZONE"))
        then (xdmp:log("*ZONE FOUND","debug"),
            xdmp:set($note,fn:true()))
        else if ($note)
        then ()
        else if (fn:starts-with($line, "*"))
        then ()
        else
            let $fields := tokenize($line, ";")
            let $fields := for $field in $fields return fn:normalize-space($field)
            let $extract := (
                if ($fields[1]) 
                then (
                    xdmp:set($street, bir:simplify($fields[1])),
                    xdmp:set($vicinity, ""), 
                    xdmp:set($class, ""), 
                    xdmp:set($rev, "") (: clear rightward data :)
                ) else (),
                if ($fields[2]) 
                then (
                    xdmp:set($vicinity, bir:simplify($fields[2])),
                    xdmp:set($class, ""), 
                    xdmp:set($rev, "") (: clear rightward data :)
                ) else (),
                if ($fields[3]) 
                then (
                    xdmp:set($class, bir:simplify($fields[3])),
                    xdmp:set($rev, "") (: clear rightward data :)
                ) else (),
                if ($fields[4]) 
                then xdmp:set($rev, bir:simplify($fields[4])) 
                else ()
            )
            let $summary := string-join(($rdo-label, $barangay, $street, $vicinity, $class, $sheet(:, $rev, string($condomode):)), "/")
            let $uri := concat("/", xdmp:url-encode($summary), ".xml")
            return 
                if (map:contains($map, $uri)) then
                  xdmp:log(fn:concat("File ", $uri, "already exists, skipping this one"),"debug")
                else if (fn:contains($rev,",")) then ( 
                    map:put($map,$uri,$uri),
                    xdmp:document-insert($uri,
                    <listing uri="{$uri}">
                      <rdo nr="{$rdo-nr}">{ $rdo-label }</rdo>
                      <barangay>{ $barangay }</barangay>
                      <start-date iso-date="{$iso-start-date}">{ $start-date }</start-date>
                      <end-date iso-date="{$iso-end-date}">{ $end-date }</end-date>
                      { if ($condomode) then <condo>{ $street }</condo> else <street>{ $street }</street> }
                      <vicinity>{ $vicinity }</vicinity>
                      <class>{ $class }</class>
                      <rev>{ $rev }</rev>
                    </listing>,
                    ($sec),
                    $collection)
                )
                else (
                    xdmp:log(fn:concat("File ",$uri," has no valid amount, moved to collection ERROR"),"debug"),
                    map:put($map,$uri,$uri),
                    xdmp:document-insert($uri,
                    <listing uri="{$uri}">
                      <rdo nr="{$rdo-nr}">{ $rdo-label }</rdo>
                      <barangay>{ $barangay }</barangay>
                      <start-date iso-date="{$iso-start-date}">{ $start-date }</start-date>
                      <end-date iso-date="{$iso-end-date}">{ $end-date }</end-date>
                      { if ($condomode) then <condo>{ $street }</condo> else <street>{ $street }</street> }
                      <vicinity>{ $vicinity }</vicinity>
                      <class>{ $class }</class>
                      <rev>{ $rev }</rev>
                    </listing>,
                    ($sec),
                    "ERROR")
                )
    )

};