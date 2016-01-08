xquery version "1.0-ml";

module namespace bir = "http://www.bir.gov.ph/ml/lib";

declare variable $LINESEP as xs:string := "&#x0d;";

declare variable $MONTHS := ("jan","feb","mar","apr","may","june","july","aug","sept","oct","nov","dec");

declare variable $DOUBLE-QUOTE := fn:string-to-codepoints('"');

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
  else if (fn:matches($string, "\d{2}-\d{2}-\d{4}")) 
  then let $dates := fn:tokenize($string,"-")
    return fn:concat($dates[3],"-",$dates[2],"-",$dates[1])
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

declare function bir:escapeSemiColonInString(
  $string as xs:string
) as item()
{
    let $quote-positions := fn:index-of(fn:string-to-codepoints($string),$DOUBLE-QUOTE)
    return if ($quote-positions and fn:count($quote-positions) eq 2)
        then fn:concat(fn:substring($string,1,$quote-positions[1]),
            fn:replace(fn:substring($string,$quote-positions[1]+1,$quote-positions[2] - $quote-positions[1]),";",","),
            fn:substring($string,$quote-positions[2]+1))
        else $string
};

declare function bir:clean-string(
    $str as xs:string
) as xs:string
{
    fn:replace($str,"\(CONTINUATION\)","","i")
};

declare function bir:cleanClass($str as xs:string) as xs:string
{
    fn:replace($str,"[\*_]","")
};

declare function bir:simplify($str as xs:string) as xs:string
{
  fn:normalize-space(fn:replace(fn:replace($str, '" ', ""), ' "', ""))
};

declare function bir:create-rev(
  $val as xs:string
) as element()*
{
  let $field := fn:normalize-space($val)
  return (
    try {
      element rev {xs:decimal(fn:replace($val,",",""))}
    } catch ($exception) {
      element rev { 0.0 },
      element note {$val}
    }
  )
};

declare variable $page-patterns := (
    "\(page \d+\)",
    "\(see page \d+\)",
    "\(seen in page \d+\)"
);

declare function bir:cleanupNotes(
    $str as xs:string,
    $patterns as xs:string*
) as xs:string
{
    if (fn:empty($patterns)) then $str
    else bir:cleanupNotes(fn:normalize-space(fn:replace($str,$patterns[1],"")),$patterns[position() gt 1])
};

(:declare variable $regexNr as xs:string := "RD[O]?\sN?[oO0]?\.[^\d]*(\d+[-]?[A-Za-z]*).*";
declare variable $regexName as xs:string := "RD[O]?\sN[oO0].[^\d]*\d+[-]?[A-Za-z]*(.+)";:)

declare variable $regexNr as xs:string := "RD[O]?\sN?[oO0]?[^\d]*(\d+[-]?[A-Za-z]*).*";
declare variable $regexName as xs:string := "RD[O]?\sN?[oO0]?[^\d]*\d+[-]?[A-Za-z]*(.*)";

declare function bir:getRDONr(
  $line as xs:string
) as xs:string*
{
    fn:replace($line,$regexNr,"$1")
};

declare function bir:getRDOName(
  $line as xs:string
) as xs:string*
{
    let $raw-name := fn:normalize-space(fn:replace(fn:replace($line,$regexName,"$1"),";",""))
    (: strip off any leading - followed by white-space :)
    let $name :=  if (fn:starts-with($raw-name,"-")) then fn:normalize-space(fn:substring-after($raw-name,"-")) else $raw-name
    return $name
};

declare function bir:load-file(
    $params as map:map,
    $collection as xs:string
) as node()*
{
    let $file := map:get($params, "fileName")
    let $start-date := map:get($params,"start")
    let $end-date := map:get($params,"end")
    let $do-no := map:get($params,"do-no")
    let $revision := map:get($params,"revision")
    let $sec := map:get($params,"sec")
    
    let $_ := xdmp:log(fn:concat("Processing file ", $file),"debug")
    let $iso-start-date := bir:iso-date($start-date)
    let $iso-end-date := bir:iso-date($end-date)
    
    let $sheet := fn:tokenize($file,"\.")[last()-2]
    let $doc := xdmp:document-get($file)
    
    let $map := map:map()
    let $doubles := map:map() 
    let $rdo-nr := ""
    let $rdo-label := ""
    let $rdo-note := ""
    let $city := ""
    let $barangay := ""
    let $street := ""
    let $vicinity := ""
    let $class := ""
    let $rev := 0.0
    let $condomode := fn:false()
    let $skip-note := fn:false()
    let $note := ""
    let $skip := fn:false()
    let $_ :=
        for $raw-line at $i in fn:tokenize($doc, $LINESEP)
        let $line := fn:normalize-space($raw-line)
		let $_ := xdmp:log(fn:concat("Line: ", $line),"debug")
        where fn:not(
            $line eq "" or 
            fn:starts-with($line,";;;") or 
            fn:starts-with($line,"-;-;-;") or 
            fn:starts-with(fn:upper-case($line),"STREET/SUBDIVISION") or 
            fn:starts-with(fn:upper-case($line),"CONDOMINIUMS/TOWNHOUSES;") or 
            fn:starts-with(fn:upper-case($line),"CONDOMINIUMS &amp;TOWNHOUSES;V I C I N I T Y;")
        ) 
        return (
                if (fn:starts-with(fn:upper-case($line), "RDO NO.") or 
                    fn:starts-with(fn:upper-case($line), "RDO N0.") or 
                    fn:starts-with(fn:upper-case($line), "RD NO.") or 
                    fn:starts-with(fn:upper-case($line), "RDO:"))
                then (
					let $_ := xdmp:log(" --- RDO","debug")
                    let $fields := fn:tokenize($line,";")
                    let $modified-line := fn:string-join($fields," ")
                    let $nr := bir:getRDONr($fields[2])
                    let $label := $fields[2](:bir:getRDOName($fields[2]):)
                    let $rnote := fn:normalize-space($fields[5])
                    return (
                        xdmp:set($skip, fn:true()),
                        xdmp:set($skip-note, fn:false()),
                        xdmp:set($rdo-nr, $nr),
                        xdmp:set($rdo-label,$label),
                        xdmp:set($rdo-note,$rnote),
                        xdmp:set($city, $label),
                        xdmp:set($barangay,""),
                        xdmp:set($street,""),
                        xdmp:set($vicinity,""),
                        xdmp:set($class,""),
                        xdmp:set($rev,"0.0"),
                        xdmp:set($note,""),
                        xdmp:set($condomode,fn:false())
                    )
                )
                else if (fn:starts-with($line, "MUNICIPALITY/CITY:") or 
                    fn:starts-with($line, "CITY/MUNICIPALITY:") or
                    fn:starts-with($line, "CITY / MUNICIPALITY:"))
                then (
					let $_ := xdmp:log(" --- MUNICIPALITY ","debug")
                    let $fields := fn:tokenize($line, ";")
                    let $city-name := fn:normalize-space($fields[2])
                    return (
                        xdmp:set($skip, fn:false()),
                        xdmp:set($skip-note,fn:false()),
                        xdmp:set($city, $city-name),
                        xdmp:set($street, ""), 
                        xdmp:set($vicinity, ""),
                        xdmp:set($class, ""), 
                        xdmp:set($rev, "0.0"), 
                        xdmp:set($note,""),
                        xdmp:set($condomode, fn:false())
                    )
                )
                else if (fn:starts-with($line, "BARANGAY:") 
                or fn:starts-with($line, "BARANGAY :") 
                or fn:starts-with($line, "BARANGAYS:"))
                then (
					let $_ := xdmp:log(" --- BARANGAY ","debug")
                    let $fields := fn:tokenize($line, ";")
                    let $extract := xdmp:set($barangay,fn:normalize-space(bir:clean-string($fields[2])))
                    return (
                        xdmp:set($skip, fn:false()),
                        xdmp:set($skip-note,fn:false()),
                        xdmp:set($street, ""), 
                        xdmp:set($vicinity, ""),
                        xdmp:set($class, ""), 
                        xdmp:set($rev, "0.0"), 
                        xdmp:set($note,""),
                        xdmp:set($condomode, if (fn:starts-with(fn:upper-case($barangay),"CONDOMINIUM")) then fn:true() else fn:false())
                    )
                )
                else if (fn:starts-with($line, "CONDOMINIUMS AND TOWNHOUSES") or fn:starts-with($line, "CONDOMINIUMS &amp; TOWNHOUSES"))
                then (
					let $_ := xdmp:log(" --- CONDOMINIUMS AND TOWNHOUSES ","debug")
					return (
                    xdmp:set($barangay,"CONDOMINIUMS AND TOWNHOUSES"),
                    xdmp:set($street, ""), 
                    xdmp:set($skip-note,fn:false()),
                    xdmp:set($vicinity, ""),
                    xdmp:set($class, ""), 
                    xdmp:set($rev, "0.0"), 
                    xdmp:set($note,""),
                    xdmp:set($condomode, fn:true()))
                )
                else if ($skip eq fn:true()) then ()
                else if (fn:starts-with($line, "***CONDO***") or fn:starts-with($line, "LIST OF CONDOMINIUMS:"))
                then (xdmp:set($street, ""), 
					let $_ := xdmp:log(" --- *** CONDO *** ","debug")
					return (
                    xdmp:set($skip-note,fn:false()),
                    xdmp:set($vicinity, ""),
                    xdmp:set($class, ""), 
                    xdmp:set($rev, "0.0"), 
                    xdmp:set($note,""),
                    xdmp:set($condomode, fn:true())
					)
                )
                else if (fn:starts-with(fn:upper-case($line),";;Effectivity Date;") or fn:matches(fn:upper-case($line),";;\d+-[A-Z]+-\d+;"))
                then (
					let $_ := xdmp:log(" --- effectivity date","debug")
					return ()
				)
                else if (fn:starts-with(fn:upper-case($line), ";V I C I N I T Y;") or
                    fn:starts-with(fn:upper-case($line), "STREET/SUBDIVISION;") or 
                    fn:starts-with(fn:upper-case($line), "STREET NAME/;") or 
                    fn:starts-with(fn:upper-case($line), "SUBDIVISION;") or 
                    fn:starts-with(fn:upper-case($line), "SUBDIVISIONS;") or 
                    fn:starts-with(fn:upper-case($line), "ZONE : "))
                then (
					let $_ := xdmp:log(" --- VICINITY ","debug")
					return ()
				)
                else if (fn:starts-with(fn:upper-case($line), "PER RDO'S JUSTIFICATION"))
                then (xdmp:log("Justification Note FOUND","debug"),
                    xdmp:set($skip-note,fn:true()))
                else if (fn:starts-with(fn:upper-case($line), "ZONE "))
                then (xdmp:log("Zone Note FOUND","debug"),
                    xdmp:set($skip-note,fn:true()))
                else if (fn:starts-with(fn:upper-case($line), "NOTE"))
                then (xdmp:log("NOTE FOUND","debug"),
                    xdmp:set($skip-note,fn:true()))
                else if (fn:starts-with(fn:upper-case($line), "APD*") or
                    fn:starts-with(fn:upper-case($line), "*APD")
                )
                then (xdmp:log("APD* FOUND","debug"),
                    xdmp:set($skip-note,fn:true()))
                else if (fn:starts-with(fn:upper-case($line), "*ZONE"))
                then (xdmp:log("*ZONE FOUND","debug"),
                    xdmp:set($skip-note,fn:true()))
                else if ($skip-note)
                then (
					let $_ := xdmp:log(" --- SKIP ","debug")
					return ()
				)
                else if (fn:starts-with($line, "*"))
                then (
					let $_ := xdmp:log(" --- SKIP ","debug")
					return ()
				)
                else
					let $_ := xdmp:log(" --- process line ","debug")
                    let $escapedLine := bir:escapeSemiColonInString($line)
                    let $fields := tokenize($escapedLine, ";")
                    let $fields := for $field in $fields return fn:normalize-space($field)
                    let $extract := (
                        if ($fields[1]) 
                        then (
                            xdmp:set($street, bir:simplify($fields[1])),
                            xdmp:set($vicinity, ""), 
                            xdmp:set($class, ""), 
                            xdmp:set($note,""),
                            xdmp:set($rev, "0.0") (: clear rightward data :)
                        ) else (),
                        if ($fields[2]) 
                        then (
                            xdmp:set($vicinity, bir:simplify($fields[2])),
                            xdmp:set($class, ""), 
                            xdmp:set($rev, "0.0") (: clear rightward data :)
                        ) else (),
                        if ($fields[3]) 
                        then (
                            xdmp:set($class, bir:cleanClass(bir:simplify($fields[3]))),
                            xdmp:set($rev, "0.0") (: clear rightward data :)
                        ) else (),
                        if ($fields[4]) 
                        then xdmp:set($rev, bir:simplify($fields[4])) 
                        else (),
                        if ($fields[5]) 
                        then xdmp:set($note, bir:cleanupNotes(bir:simplify($fields[5]),$page-patterns)) 
                        else ()
                    )
                    let $condo-string := if ($condomode) then "CONDO" else "STREET"
                    let $summary := string-join(($rdo-nr, $rdo-label, $city, $barangay, $street, $vicinity, $class, $condo-string,$sheet), "/")
                    let $uri := concat("/", xdmp:url-encode($summary), ".xml")
                    let $node :=
                        element listing {
                            attribute uri {$uri },
                            attribute index {$i },
                            element rdo {
                                attribute nr { $rdo-nr },
                                if ($rdo-note ne "") then attribute note { $rdo-note } else (),
                                $rdo-label
                            },
                            element city { $city },
                            element barangay { $barangay },
                            if ($condomode)
                                then element condo { $street }
                                else element street { $street },
                            element vicinity { $vicinity },
                            element class { $class },
                            (:element rev { $rev },:)
                            bir:create-rev($rev),
                            if ($note ne "") then element note { $note } else (),
                            element start-date {
                                attribute iso-date { $iso-start-date },
                                $start-date
                            },
                            element end-date {  
                                attribute iso-date { $iso-end-date },
                                $end-date
                            },
                            element do-no { $do-no },
                            element revision { $revision }
                        }
                    return 
                        if (map:contains($map, $uri)) then (
                            xdmp:log(fn:concat("File ", $uri, "already exists, skipping this one"),"debug"),
                            map:put($doubles,$uri,$uri)
                        )
                        else if ($rev ne "") then ( 
                            map:put($map,$uri,$uri),
                            xdmp:document-insert($uri,
                                $node,
                                ($sec),
                                $collection)
                        )
                        else (
                            xdmp:log(fn:concat("File ",$uri," has empty amount, moved to collection ERROR"),"debug"),
                            map:put($map,$uri,$uri),
                            xdmp:document-insert($uri,
                                $node,
                                ($sec),
                                "ERROR")
                        )
            )
    let $_ := 
        if (map:count($doubles) > 0) 
        then xdmp:document-insert(fn:concat("/doubles",$file),
            element doubles {
                for $k in map:keys($doubles)
                return element line { $k }
            },
            ($sec),"DOUBLES")
        else ()
    return xdmp:log(fn:concat("DOUBLES:: for file ",$file," is ", map:count($doubles)),"debug")
};