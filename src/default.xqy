xquery version "1.0-ml";

declare default collation "http://marklogic.com/collation/en/MO";
declare option xdmp:mapping "false";

declare variable $format-string as xs:string := "#,###.00";

declare variable $fields := ( "rdo", "city", "barangay", "street", "condo", "vicinity", "class" );
declare variable $initial-fields := ("rdo", "city","barangay");

declare variable $labels := ( "RDO", "City/Municipality", "Barangay", "Street/Subdivision", "Condo/Townhouse", "Vicinity", "Class" );
declare variable $counters := map:map();

declare variable $options := ("case-sensitive","diacritic-sensitive","punctuation-sensitive","whitespace-insensitive","unstemmed","unwildcarded");
(:
declare variable $fields := ( "rdo", "barangay", "street", "condo", "vicinity", "class" );
declare variable $labels := ( "RDO", "Barangay", "Street", "Condo/Townhouse", "Vicinity", "Class" );
:)

declare function local:pretty-class(
    $code as xs:string
) as xs:string
{
    let $result := cts:search(/classifications, cts:element-range-query(xs:QName("code"),"=", $code),"unfiltered")//classification[code eq $code]
    return if (fn:empty($result)) then $code else fn:concat($code," (", $result[1]//name,")")
};

declare function local:commify(
    $s
) as xs:string
{
    let $s := fn:string(xs:integer(xs:double($s)))
    return
        if(fn:string-length($s) <= 3)
        then $s
        else fn:concat(local:commify(substring($s, 1, fn:string-length($s)-3)), ",", fn:substring($s, fn:string-length($s)-2, 3))
};

declare function local:make-query(
    $name as xs:string,
    $fields as xs:string*,
    $date-q as cts:query?,
    $params as map:map
) as cts:query
{
    xdmp:trace("bir-query",fn:concat("in make-query::",fn:string-join($fields, ","))),
    cts:and-query((
        for $field in $fields
(:        let $param := xdmp:get-request-field($field):)
        let $param := map:get($params,$field)
        let $_ := xdmp:trace("bir-query",fn:concat("field ", $field,"=",$param))
        return if ($param) then cts:element-value-query(xs:QName($field), $param, $options) else (),
        $date-q,
        cts:collection-query(("listings"))
    ))
};


declare function local:combobox(
    $name as xs:string,
    $param as xs:string?,
    $date-q as cts:query?,
    $params as map:map
) as node()
{
    (: http://www.scriptol.com/html5/combobox.php :)
    let $_ := xdmp:trace("bir-query",fn:concat("In local:combobox with name =", $name))
    let $q := local:make-query($name,for $field in fn:subsequence($fields, 1, fn:index-of($fields,$name)-1) return $field, $date-q, $params)
    let $_ := xdmp:trace("bir-query",fn:concat("combo-query=", $q))

    (: get nr of hits for initial-fields :)
    let $initial-fields-count := fn:sum(      
                for $f in $initial-fields
                let $cnt := map:get($counters,$f)
                return $cnt)
    (: only execute the query when one of rdo, city or barangay has a count of 1:)
    let $vals :=
        (: field not one of the initial ones? :)
        if (fn:empty(fn:index-of($initial-fields,$name))) 
        then ( 
            if ($initial-fields-count eq 3) 
            then cts:element-values(xs:QName($name), "", (), $q) 
            else if (($name eq "street" and map:get($counters,"rdo") eq 1 and map:get($counters,"city") eq 1) or
                    ($name eq "condo" and map:get($counters,"rdo") eq 1 and map:get($counters,"city") eq 1))
            then cts:element-values(xs:QName($name), "", (), $q)
            else ()
        )
        else cts:element-values(xs:QName($name), "", (), $q)
    
    let $count := fn:count($vals)
    let $_ := map:put($counters,$name,if ($param ne "") then 1 else $count)
    let $_ := if ($count eq 1) then map:put($params,$name,$vals) else ()
    let $_ := 
        for $key in map:keys($counters) 
        return xdmp:trace("bir-query",fn:concat("local:combobox::key[",$key,"] has value[",map:get($counters,$key),"]"))
    let $notapplicable := (
      ($name = "condo" and (map:contains($params,"street") or $count = 0)) or
      ($name = "street" and (map:contains($params,"condo") or $count = 0)) or
      ($name = "vicinity" and (not(map:contains($params,"street") or map:contains($params,"condo")) or $count = 0)) or
(:      ($name = "vicinity" and $count = 0) or :)
      ($name = "class" and $count = 0)
    )
    let $next-field := $fields[fn:index-of($fields,$name) + 1]
    let $next2-field := $fields[fn:index-of($fields,$name) + 2]
    let $extra-vals := 
        if ($next-field eq "street" and $param eq "" and map:contains($params,"street")) 
        then (
            let $q-extra := cts:element-value-query(xs:QName("street"), map:get($params,"street"), $options)
            return (
                cts:element-values(xs:QName($name),"",(),cts:and-query(($q, $q-extra)))
            )
        ) else if ($next2-field eq "condo" and $param eq "" and map:contains($params,"condo")) 
        then (
            let $q-extra := cts:element-value-query(xs:QName("condo"), map:get($params,"condo"), $options)
            return (
                cts:element-values(xs:QName($name),"",(),cts:and-query(($q, $q-extra)))
            )
        ) else ()
    let $extra-vals-cnt := fn:count($extra-vals)
    let $_ := if ($extra-vals-cnt != 0) then map:put($counters,$name,$extra-vals-cnt) else ()
    let $vals := if ($extra-vals-cnt > 1) then $extra-vals else $vals
    let $param := if ($extra-vals-cnt = 1) then $extra-vals else $param
    return 
        <div class="form-group">
            <label for="{$name}" class="col-sm-2 control-label">{ $labels[fn:index-of($fields,$name)] }:</label>
            <div class="col-sm-10">
                <select id="{$name}" name="{$name}" class="col-sm-6">
                {
                    let $opts := if ($notapplicable) then "N/A" else ("(select)", $vals)
                    for $opt in $opts
                    where (if ($name eq "vicinity") then $opt ge ""  else $opt ne "")
                    return
                    <option> {
                        attribute value { if ($opt = ("(select)", "N/A")) then "" else if ($opt eq "") then " " else $opt },
                        if ($name eq "vicinity" and $param eq " " and $opt eq "")
                        then attribute selected { ""}
                        else if (($param ne "" and $opt eq $param) or $count = 1) 
                        then attribute selected { "" }
                        else (),
                        if ($name = "class") then local:pretty-class($opt) else if ($opt eq "") then "&#160;" else $opt
                    }</option>
                }
                </select>
            </div>
        </div>
};

xdmp:set-response-content-type("text/html"),
(:xdmp:add-response-header("Cache-Control", "max-age=3600, public"),:)
let $_ := map:clear($counters)
let $rdo := xdmp:get-request-field("rdo")
let $city := xdmp:get-request-field("city")
let $barangay := xdmp:get-request-field("barangay")
let $street := xdmp:get-request-field("street")
let $condo := xdmp:get-request-field("condo")
let $vicinity := xdmp:get-request-field("vicinity")
let $class := xdmp:get-request-field("class")
let $sqm := xs:decimal(xdmp:get-request-field("sqm","1"))
(:let $date := xdmp:get-request-field("date",fn:substring(xs:string(fn:current-date()),1,10)):)
let $date := xdmp:get-request-field("date")
let $hitCounts := map:map()
let $params := map:new((
    if ($rdo) then map:entry("rdo",$rdo) else (),
    if ($city) then map:entry("city",$city) else (),
    if ($barangay) then map:entry("barangay",$barangay) else (),
    if ($street) then map:entry("street",$street) else (),
    if ($condo) then map:entry("condo",$condo) else (),
    if ($vicinity) then map:entry("vicinity",fn:normalize-space($vicinity)) else (),
    if ($class) then map:entry("class",$class) else (),
    if ($date) then map:entry("date",xs:date($date)) else ()
))
let $_ := xdmp:trace("bir-query","Start of page")
let $_ := xdmp:trace("bir-query",$params)
let $_ := xdmp:trace("bir-query",fn:concat("vicinity=[",$vicinity,"]"))
let $_ := xdmp:trace("bir-query","=======")

let $date-q := if (fn:empty($date) or $date eq "") then () 
    else cts:and-query((
        cts:element-attribute-range-query(xs:QName("start-date"),xs:QName("iso-date"),"<=",xs:date($date)),
        cts:element-attribute-range-query(xs:QName("end-date"),xs:QName("iso-date"),">=",xs:date($date))
    ))
let $q :=
    cts:and-query((
        if ($rdo) then cts:element-value-query(xs:QName("rdo"), $rdo, $options) else (),
        if ($city) then cts:element-value-query(xs:QName("city"), $city, $options) else (),
        if ($barangay) then cts:element-value-query(xs:QName("barangay"), $barangay, $options) else (),
        if ($street) then cts:element-value-query(xs:QName("street"), $street, $options) else (),
        if ($condo) then cts:element-value-query(xs:QName("condo"), $condo, $options) else (),
        if ($vicinity) then cts:element-value-query(xs:QName("vicinity"), $vicinity, $options) else (),
        if ($class) then cts:element-value-query(xs:QName("class"), $class, $options) else ()
    ))
  
return
<html lang="en">
<head>
    <meta charset="utf-8"/>
    <meta http-equiv="X-UA-Compatible" content="IE=edge"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
    <title>Zonal Values - Bureau of Internal Revenue</title>

    <!-- Bootstrap -->
    <link href="/bootstrap-3.2.0/css/bootstrap.min.css" rel="stylesheet"/>

    <link rel="stylesheet" href="/js/datepicker/css/datepicker.css"/>
    <link rel="stylesheet" href="/jquery-ui/1.9.2/css/custom-theme/jquery-ui-1.9.2.css"/>
    <!-- HTML5 Shim and Respond.js IE8 support of HTML5 elements and media queries -->
    <!-- WARNING: Respond.js doesn't work if you view the page via file:// -->
    <!--[if lt IE 9]>
      <script src="https://oss.maxcdn.com/html5shiv/3.7.2/html5shiv.min.js"></script>
      <script src="https://oss.maxcdn.com/respond/1.4.2/respond.min.js"></script>
    <![endif]-->
    <style>
        .ui-autocomplete-input {{
            width: 60%;
        }}
        .ui-button {{
            height: 25px;
            display: inline-flex;
        }}
        .form-group {{
            margin-bottom: 5px;
        }}
        .control-label {{
            padding-top: 3px;
        }}
        .zonal-value {{
            outline: #gray solid 2px !important;
            font-size: x-large;
            padding: 0.2em;
            background: lightgray;
        }}
        .zonal-color {{
            color: rgb(28,148,196);
        }}
        .zonal-button {{
            background-color: white;
            width:100%;
            margin:0;
        }}
    </style>
</head>
<body>
    <div class="container-fluid">
    <a href="/default.xqy"><img src="header_image.jpg" /></a>
    <h3 class="center">Please complete the form to view the zonal value</h3>
    <form class="form-horizontal ui-widget" role="form" id="zonalForm">
        <div class="form-group">
            <label class="col-sm-2 control-label" for="date">Transaction Date:</label>
            <div class="col-sm-2">
                <input class="ui-widget ui-corner-left ui-corner-right zonal-color" id="date" type="text" name="date" value="{ $date }" data-date-format="yyyy-mm-dd" required="required"/>
            </div>
        </div>
        { if ($date) then local:combobox("rdo",$rdo,$date-q,$params)  else ()}
        { if ($date) then local:combobox("city",$city,$date-q,$params) else ()}
		{ if ($date) then local:combobox("barangay",$barangay,$date-q,$params) else ()}
		{ if ($date) then local:combobox("street",$street,$date-q,$params) else ()}
		{ if ($date) then local:combobox("condo",$condo,$date-q,$params) else ()}
		{ if ($date) then local:combobox("vicinity",$vicinity,$date-q,$params) else ()}
		{ if ($date) then local:combobox("class",$class,$date-q,$params) else ()}
        { if ($date) then <div class="form-group">
            <label class="col-sm-2 control-label">SQ Meters:</label>
            <div class="col-sm-2">
                <input id="sqm" type="text" name="sqm" value="{ $sqm }" class="ui-widget ui-corner-left ui-corner-right zonal-color"/>
            </div>
        </div>
         else () }
    </form>
    <form  class="form-horizontal ui-widget" role="form" id="clearZonal">
        <div class="form-group">
            <div class="col-sm-offset-2 col-sm-2">
                <input type="submit" class="ui-widget ui-corner-left ui-corner-right zonal-color zonal-button" value ="Clear"/>
            </div>
        </div>
    </form>
    { 
        let $_ := for $key in map:keys($counters) return xdmp:trace("bir-query",fn:concat("key[",$key,"] has value[",map:get($counters,$key),"]"))
        let $_ := xdmp:trace("bir-query",<q>{$q}</q>)
        let $hits := cts:search(fn:collection("listings"), 
            cts:and-query(($q,$date-q)),"unfiltered")
        let $nr_of_hits := if (fn:empty($hits)) then 0 else cts:remainder($hits[1])
        let $_ := xdmp:trace("bir-query",fn:concat("NR OF HITS:",$nr_of_hits))
        let $listings :=
            if ($nr_of_hits = 1 or
                fn:max(for $key in map:keys($counters) return map:get($counters,$key)) eq 1)
            then (cts:search(fn:collection("listings"), 
                cts:and-query(($q,if (fn:empty($date) or $date eq "") then () else $date-q)),"unfiltered"),
                xdmp:trace("bir-query",fn:concat("GET_LISTINGS::cts:search(fn:collection('listings'), 
                    cts:and-query((",$q,',',if (fn:empty($date) or $date eq "") then '()' else $date-q, '))',",'unfiltered')")))
            else ()
        return if (fn:empty($listings)) then ()
            else
                <table class="table">
                    <thead>
                        <tr>
                            <th class="col-sm-1">DO No.</th>
                            <th class="col-sm-1">Rev.</th>
                            <th class="col-sm-1">Effectivity<br/>Start Date</th>
                            <th class="col-sm-1">Effectivity<br/>End Date</th>
                            <th class="col-sm-2">Zonal Value</th>
                            <th class="col-sm-2">Note</th>
                        </tr>
                    </thead>
                    <tbody> {
                        for $listing in $listings
                        let $_ := xdmp:log($listing,"debug")
                        let $rnote := $listing//rdo/@note/fn:string()
                        let $rev := $listing//rev
                        let $start-date := fn:string($listing//start-date)
                        let $end-date := fn:string($listing//end-date)
                        let $sort-date := $listing//start-date/@iso-date
                        let $do-nr := $listing//do-no/text()
                        let $revision := $listing//revision/text()
                        let $notes := $listing//note
                        order by $sort-date descending
                        return
                            if ($rev) then 
                                <tr>
                                    <td class="col-sm-1"><strong>{ $do-nr }</strong></td>
                                    <td class="col-sm-1"><strong>{ $revision }</strong></td>
                                    <td class="col-sm-1"><strong>{ $start-date }</strong></td>
                                    <td class="col-sm-1"><strong>{ $end-date }</strong></td>
                                    <td class="col-sm-2">
                                    {
                                        if ($sqm = 1) 
                                            then <strong>Php <span class="zonal-value">{ fn:format-number($rev,$format-string) }</span></strong>
                                            else (<strong>{ fn:concat("Php ", fn:format-number($rev,$format-string), " x ", fn:format-number($sqm,$format-string), " sqm = Php ") }
                                                <span class="zonal-value">{ fn:format-number($sqm*$rev,$format-string) }</span></strong>)
                                    }
                                    </td>
                                    <td class="col-sm-2">
                                    {
                                        if (fn:empty($rnote)) then () else <p>{$rnote}</p>,
                                        for $note in $notes return <p>{$note/text()}</p>
                                    }
                                    </td>
                                </tr>
                            else ()
                    }</tbody>
                </table>
    }
    </div>
    <!-- jQuery (necessary for Bootstrap's JavaScript plugins) -->
    <script src="/jquery/1.11.1/jquery-1.11.1.min.js"></script>
    <!-- Include all compiled plugins (below), or include individual files as needed -->
    <script src="/bootstrap-3.2.0/js/bootstrap.min.js"></script>
    <script src="/jquery-ui/1.9.2/js/jquery-ui-1.9.2.min.js"></script>
    <script src="/js/datepicker/js/bootstrap-datepicker.js"></script>
    <script src="/js/custom-combobox.js"></script>
    <script>
        $(function () {{
            { 
                for $field in $fields
                return fn:concat(
                    "$('#",$field,"').combobox({&#xa;",
                    "select: function (event, ui) {&#xa;",
                    fn:string-join(
                    for $fld in fn:subsequence($fields,fn:index-of($fields,$field)+1)
                    where fn:not(($field eq "barangay" and $fld eq "street" and $street ne "") or 
                        ($field eq "barangay" and $fld eq "condo" and $condo ne ""))
                    return fn:concat("$('#",$fld," :selected').removeAttr('selected');"),"&#xa;"),
                    "$('#zonalForm').submit();&#xa;",
                    "}&#xa;});&#xa;")
            }
            $('#city').on("change", function (e) {{
                alert("city changed");
            }});
            $('#date').datepicker({{
                    onRender: function(date) {{
                        return date.valueOf();
                    }}
                }}).on('changeDate', function(ev) {{
                    if (ev.viewMode === "days") {{
                        $('#date').datepicker('hide');
                        $("#zonalForm").submit();
                    }}
                }}).keyup(function(e) {{
                    if(e.keyCode == 8 || e.keyCode == 46) {{
                        $('#date').val('');
                        $("#zonalForm").submit();
                    }}
                }}).data('datepicker');
            $('#sqm').on('keypress', function(e) {{
                if (e.keyCode == 13) {{
                    $("#zonalForm").submit();
                }}
            }});
        }});
    </script>
  </body>
</html>
