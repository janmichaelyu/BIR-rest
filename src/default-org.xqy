xquery version "1.0-ml";

declare default collation "http://marklogic.com/collation/en/MO";
declare option xdmp:mapping "false";

declare variable $fields := ( "rdo", "barangay", "street", "condo", "vicinity", "class" ,"date");

declare function local:pretty-class(
    $s
) as xs:string
{
    if ($s = "RR") then "RR (Residential Regular)"
    else if ($s = "CR") then "CR (Commercial Regular)"
    else if ($s = "RC") then "RC (Residential Condominium)"
    else if ($s = "CC") then "CC (Commercial Condominium)"
    else if ($s = "CL") then "CL (Cemetery Lot)"
    else if ($s = "A") then "A (Agricultural)"
    else if ($s = "GL") then "GL (Government Land)"
    else if ($s = "GP") then "GP (General Purposes)"
    else if ($s = "GP*") then "GP* (General Purposes)"
    else if ($s = "I") then "I (Industrial)"
    else if ($s = "X") then "X (Institutional)"
    else if ($s = "APD") then "APD (Area for Priority Development)"
	else $s
};

declare function local:commify(
    $s
) as xs:string
{
    let $s := string(xs:integer(xs:double($s)))
    return
        if(string-length($s) <= 3)
        then $s
        else concat(local:commify(substring($s, 1, string-length($s)-3)), ",", substring($s, string-length($s)-2, 3))
};

declare function local:make-query(
  $fields as xs:string*
)
{
  cts:and-query((
    for $field in $fields
    let $param := xdmp:get-request-field($field)
    return if ($param) then cts:element-value-query(xs:QName($field), $param) else (),
    cts:collection-query(("listings"))
  ))
};

declare function local:combo(
  $name as xs:string,
  $param as xs:string?,
  $q as cts:query
)
{
  (: http://www.scriptol.com/html5/combobox.php :)
  let $q := local:make-query(for $field in $fields where not($field = $name) return $field)
  let $count := count(cts:element-values(xs:QName($name), "", (), $q))
  let $notapplicable := 
    (
      ($name = "condo" and (xdmp:get-request-field("street") or $count = 0)) or
      ($name = "street" and (xdmp:get-request-field("condo") or $count = 0)) or
      ($name = "vicinity" and (not(xdmp:get-request-field("street") or xdmp:get-request-field("condo")) or $count = 0))
    )
  return
  <tr>
  <td>{ upper-case($name) }:</td>
  <td><select id="{$name}" name="{$name}" onChange="comboact(this, '{$name}')" style="width: 300px">>
  {
    let $opts := if ($notapplicable) then "N/A" else ("(select)", cts:element-values(xs:QName($name), "", (), $q))
    for $opt in $opts
    return
    <option>{ attribute value { if ($opt = ("(select)", "N/A")) then "" else $opt },
              if ($opt = $param or $count = 1) then attribute selected { "" } else (),
              if ($name = "class") then local:pretty-class($opt) else $opt
    }</option>
  }
  </select></td>
  </tr>
};

xdmp:set-response-content-type("text/html"),

let $rdo := xdmp:get-request-field("rdo")
let $barangay := xdmp:get-request-field("barangay")
let $street := xdmp:get-request-field("street")
let $condo := xdmp:get-request-field("condo")
let $vicinity := xdmp:get-request-field("vicinity")
let $class := xdmp:get-request-field("class")
let $sqm := xs:integer(xdmp:get-request-field("sqm", "1"))

let $q :=
  cts:and-query((
    if ($rdo) then cts:element-value-query(xs:QName("rdo"), $rdo) else (),
    if ($barangay) then cts:element-value-query(xs:QName("barangay"), $barangay) else (),
    if ($street) then cts:element-value-query(xs:QName("street"), $street) else (),
    if ($condo) then cts:element-value-query(xs:QName("condo"), $condo) else (),
    if ($vicinity) then cts:element-value-query(xs:QName("vicinity"), $vicinity) else (),
    if ($class) then cts:element-value-query(xs:QName("class"), $class) else (),
    cts:collection-query(("listings"))
  ))

return
<html>
<head>
<script>
  function comboact(thelist, theinput) {{
    theform = document.getElementById("myForm");

    if (theinput === "rdo") {{
      //if (document.getElementById('rdo').selectedIndex == 0) {{
        document.getElementById('barangay').selectedIndex = 0;
        document.getElementById('street').selectedIndex = 0;
        document.getElementById('condo').selectedIndex = 0;
        document.getElementById('vicinity').selectedIndex = 0;
        document.getElementById('class').selectedIndex = 0;
      //}}
    }}
    else if (theinput === "barangay") {{
      //if (document.getElementById('barangay').selectedIndex == 0) {{
        document.getElementById('rdo').selectedIndex = 0;
        document.getElementById('street').selectedIndex = 0;
        document.getElementById('condo').selectedIndex = 0;
        document.getElementById('vicinity').selectedIndex = 0;
        document.getElementById('class').selectedIndex = 0;
      //}}
    }}
    else if (theinput === "street") {{
      //if (document.getElementById('street').selectedIndex == 0) {{
        document.getElementById('condo').selectedIndex = 0;
        document.getElementById('vicinity').selectedIndex = 0;
        document.getElementById('class').selectedIndex = 0;
      //}}
    }}
    else if (theinput === "condo") {{
      //if (document.getElementById('condo').selectedIndex == 0) {{
        document.getElementById('street').selectedIndex = 0;
        document.getElementById('vicinity').selectedIndex = 0;
        document.getElementById('class').selectedIndex = 0;
      //}}
    }}
    else if (theinput === "vicinity") {{
      //if (document.getElementById('vicinity').selectedIndex == 0) {{
        document.getElementById('class').selectedIndex = 0;
      //}}
    }}
/*
    else if (theinput === "class") {{
      //if (document.getElementById('class').selectedIndex == 0) {{
        document.getElementById('vicinity').selectedIndex = 0;
      //}}
    }}
*/

/*
      theinput = document.getElementById(theinput);
      var idx = thelist.selectedIndex;
      thelist.selectedIndex = 0;
*/
    theform.submit();

/*
    theinput = document.getElementById(theinput);
    var idx = thelist.selectedIndex;
    var content = thelist.options[idx].innerHTML;
    theinput.value = content;
*/
  }}
</script>
</head>
<body>
<img src="header_image.jpg" />
<h3>
Please select your location to view the zonal value
</h3>
<form id="myForm">
<table>
{ local:combo("rdo", $rdo, $q) }
{ local:combo("barangay", $barangay, $q) }
{ local:combo("street", $street, $q) }
{ local:combo("condo", $condo, $q) }
{ local:combo("vicinity", $vicinity, $q) }
{ local:combo("class", $class, $q) }
<hr><td>SQ METERS:</td><td><input type="text" name="sqm" value="{ $sqm }" style="width: 300px"/></td></hr>
</table>
<!--
<input type="submit" value="submit" />
-->
</form>
<form action="">
<input type="submit" value="Clear" />
</form>
{
  let $rev :=
    let $hits := xdmp:estimate(cts:search(doc(), $q))
    return
    if ($hits = 1)
    then
    cts:search(doc(), $q)//rev
    else
    ()
  let $rev := if (ends-with($rev, ".00")) 
    then substring-before($rev, ".00") 
    else if (ends-with($rev, ",00"))
    then  substring-before($rev, ",00") 
    else $rev
  return
  if ($rev) then 
    <div style="font-size: 40px;">
    {
      if (not($rev castable as xs:float)) then $rev
      else if ($sqm = 1) then concat("Zonal value: Php ", local:commify($rev))
      else concat("Zonal value: Php ", local:commify($rev), " x ", local:commify($sqm), "sqm = Php ", local:commify($sqm*xs:float($rev)))
    }
    </div>
  else ()
}
</body>
</html>
