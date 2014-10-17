xquery version "1.0-ml";

declare default collation "http://marklogic.com/collation/en/MO";
declare option xdmp:mapping "false";

declare variable $fields := ( "rdo", "city", "barangay", "street", "condo", "vicinity", "class" );
declare variable $labels := ( "RDO", "City/Municipality", "Barangay", "Street/Subdivision", "Condo/Townhouse", "Vicinity", "Class" );
declare variable $counters := map:map();

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
    $fields as xs:string*
) as cts:query
{
    xdmp:log(fn:concat("in make-query::",fn:string-join($fields, ",")),"debug"),
    cts:and-query((
        for $field in $fields
        let $param := xdmp:get-request-field($field)
        return if ($param) then cts:element-value-query(xs:QName($field), $param) else (),
        cts:collection-query(("listings"))
    ))
};

declare function local:combobox(
    $name as xs:string,
    $param as xs:string?,
    $date-q as cts:query?
) as node()
{
    (: http://www.scriptol.com/html5/combobox.php :)
    let $_ := xdmp:log(fn:concat("field=", $name),"debug")
    let $q := local:make-query(for $field in fn:subsequence($fields, 1, fn:index-of($fields,$name)-1) return $field)
    let $_ := xdmp:log(fn:concat("query=", $q),"debug")
(:    let $vals := cts:element-values(xs:QName($name), "", (), cts:and-query(($q,$date-q))) :)
    let $vals := cts:element-values(xs:QName($name), "", (), $q)
    let $count := fn:count($vals)
    let $_ := map:put($counters,$name,if ($param ne "") then 1 else $count)
    let $_ := xdmp:log(fn:concat($name, "::count=", $count),"debug")
(:    let $notapplicable := ($count = 0) or ($count = 1 and $vals = ""):)
    let $notapplicable := (
      ($name = "condo" and (xdmp:get-request-field("street") ne "" or $count = 0)) or
      ($name = "street" and (xdmp:get-request-field("condo") ne "" or $count = 0)) or
      ($name = "vicinity" and ($count = 0 or ($count = 1 and $vals = "")))
    )

    return 
        <div class="form-group">
            <label for="{$name}" class="col-sm-2 control-label">{ $labels[fn:index-of($fields,$name)] }:</label>
            <div class="col-sm-10">
                <select id="{$name}" name="{$name}" class="col-sm-6">
                {
                    let $opts := if ($notapplicable) then "N/A" else ("(select)", $vals)
                    let $_ := xdmp:log(fn:concat("OPTS=",fn:string-join($opts[1 to 20],",")),"debug")
                    for $opt in $opts
                    where ($opt ne "")
                    return
                    <option value="{if ($opt = ("(select)", "N/A")) then "" else $opt }">{
                              if (($param ne "" and $opt = $param) or $count = 1) then attribute selected { "" } else (),
                              if ($name = "class") then local:pretty-class($opt) else $opt
                    }</option>
                }
                </select>
            </div>
        </div>
};

xdmp:set-response-content-type("text/html"),
xdmp:add-response-header("Cache-Control", "max-age=600"),
let $_ := map:clear($counters)
let $rdo := xdmp:get-request-field("rdo")
let $city := xdmp:get-request-field("city")
let $barangay := xdmp:get-request-field("barangay")
let $street := xdmp:get-request-field("street")
let $condo := xdmp:get-request-field("condo")
let $vicinity := xdmp:get-request-field("vicinity")
let $class := xdmp:get-request-field("class")
let $sqm := xs:integer(xdmp:get-request-field("sqm","1"))
(:let $date := xdmp:get-request-field("date",fn:substring(xs:string(fn:current-date()),1,10)):)
let $date := xdmp:get-request-field("date")
let $hitCounts := map:map()

let $_ := xdmp:log(fn:concat(
"rdo=[",$rdo,"] ",
"city=[",$city,"] ",
"barangay=[",$barangay,"] ",
"street=[",$street,"] ",
"condo=[",$condo,"] ",
"vicinity=[",$vicinity,"] ",
"class=[",$class,"]",
"date=[",$date,"]"
),
"debug")

let $date-q := if (fn:empty($date) or $date eq "") then () 
(:    then cts:and-query((
        cts:element-attribute-range-query(xs:QName("start-date"),xs:QName("iso-date"),"<=",xs:date(fn:substring(xs:string(fn:current-date()),1,10))),
        cts:element-attribute-range-query(xs:QName("end-date"),xs:QName("iso-date"),">=",xs:date(fn:substring(xs:string(fn:current-date()),1,10)))
    )) :)
    else cts:and-query((
        cts:element-attribute-range-query(xs:QName("start-date"),xs:QName("iso-date"),"<=",xs:date($date)),
        cts:element-attribute-range-query(xs:QName("end-date"),xs:QName("iso-date"),">=",xs:date($date))
    ))
let $q :=
    cts:and-query((
        cts:collection-query(("listings")),
        if ($rdo) then cts:element-value-query(xs:QName("rdo"), $rdo) else (),
        if ($city) then cts:element-value-query(xs:QName("city"), $city) else (),
        if ($barangay) then cts:element-value-query(xs:QName("barangay"), $barangay) else (),
        if ($street) then cts:element-value-query(xs:QName("street"), $street) else (),
        if ($condo) then cts:element-value-query(xs:QName("condo"), $condo) else (),
        if ($vicinity) then cts:element-value-query(xs:QName("vicinity"), $vicinity) else (),
        if ($class) then cts:element-value-query(xs:QName("class"), $class) else ()
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
    <h3 class="center">Please select your location to view the zonal value</h3>
    <form class="form-horizontal ui-widget" role="form" id="zonalForm">
        { local:combobox("rdo",$rdo,$date-q) }
        { local:combobox("city",$city,$date-q) }
		{ local:combobox("barangay",$barangay,$date-q) }
		{ local:combobox("street",$street,$date-q) }
		{ local:combobox("condo",$condo,$date-q) }
		{ local:combobox("vicinity",$vicinity,$date-q) }
		{ local:combobox("class",$class,$date-q) }
        <div class="form-group">
            <label class="col-sm-2 control-label">SQ Meters:</label>
            <div class="col-sm-2">
                <input id="sqm" type="text" name="sqm" value="{ $sqm }" class="ui-widget ui-corner-left ui-corner-right zonal-color"/>
            </div>
        </div>
        <div class="form-group">
            <label class="col-sm-2 control-label" for="date">Transaction Date:</label>
            <div class="col-sm-2">
                <input class="ui-widget ui-corner-left ui-corner-right zonal-color" id="date" type="text" name="date" value="{ $date }" data-date-format="yyyy-mm-dd"/>
            </div>
        </div>
    </form>
    <form  class="form-horizontal ui-widget" role="form" id="clearZonal">
        <div class="form-group">
            <div class="col-sm-offset-2 col-sm-2">
                <input type="submit" class="ui-widget ui-corner-left ui-corner-right zonal-color zonal-button" value ="Clear"/>
            </div>
        </div>
    </form>
    { 
        let $_ := for $key in map:keys($counters) return xdmp:log(fn:concat("key[",$key,"] has value[",map:get($counters,$key),"]"),"debug")
        let $hits := cts:search(fn:collection("listings"), 
            cts:and-query(($q,$date-q)),"unfiltered")
        let $nr_of_hits := if (fn:empty($hits)) then 0 else cts:remainder($hits[1])
        let $_ := xdmp:log(fn:concat("NR OF HITS:",$nr_of_hits),"debug")
        let $listings :=
            if ($nr_of_hits = 1 or (
                    (map:contains($counters,"class") and map:get($counters,"class") eq 1) and
                    (map:contains($counters,"vicinity") and map:get($counters,"vicinity") eq 1) and (
                        (map:contains($counters,"class") and map:get($counters,"class") eq 1) and
                        (map:contains($counters,"vicinity") and map:get($counters,"vicinity") eq 1)
                    )
                )
            )
            then (cts:search(fn:collection("listings"), 
                cts:and-query(($q,if (fn:empty($date) or $date eq "") then () else $date-q)),"unfiltered"),
                xdmp:log(fn:concat("GET_LISTINGS::cts:search(fn:collection('listings'), 
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
                            <th class="col-sm-3">Zonal Value</th>
                        </tr>
                    </thead>
                    <tbody> {
                        for $listing in $listings
                        let $_ := xdmp:log($listing,"debug")
                        let $rev := 
                            if (ends-with($listing//rev, ".00")) 
                            then fn:replace(fn:substring-before($listing//rev, ".00"),",","") 
                            else if (ends-with($listing//rev, ",00"))
                            then  fn:replace(fn:substring-before($listing//rev, ",00"),"\.","") 
                            else $listing//rev
                        let $start-date := fn:string($listing//start-date/@iso-date)
                        let $end-date := fn:string($listing//end-date/@iso-date)
                        let $sort-date := $listing//start-date/@iso-date
                        let $do-nr := $listing//do-no/text()
                        let $revision := $listing//revision/text()
                        order by $sort-date descending
                        return
                            if ($rev) then 
                                <tr>
                                    <td class="col-sm-1"><strong>{ $do-nr }</strong></td>
                                    <td class="col-sm-1"><strong>{ $revision }</strong></td>
                                    <td class="col-sm-1"><strong>{ $start-date }</strong></td>
                                    <td class="col-sm-1"><strong>{ $end-date }</strong></td>
                                    <td class="col-sm-3">{
                                        if (not($rev castable as xs:float)) 
                                        then <em>{ $rev }</em>
                                        else if ($sqm = 1) 
                                            then <strong>Php <span class="zonal-value">{ local:commify($rev) }</span></strong>
                                            else <strong>{ fn:concat("Php ", local:commify($rev), " x ", local:commify($sqm), " sqm = Php ") }
                                                <span class="zonal-value">{ local:commify($sqm*xs:float($rev)) }</span></strong>
                                    }
                                    </td>
                                </tr>
                            else ()
                    }</tbody>
                </table>
    }
    </div>
    <!-- jQuery (necessary for Bootstrap's JavaScript plugins) -->
    <script src="/jquery/1.11.1/jquery-1.11.1.js"></script>
    <!-- Include all compiled plugins (below), or include individual files as needed -->
    <script src="/bootstrap-3.2.0/js/bootstrap.min.js"></script>
    <script src="/jquery-ui/1.9.2/js/jquery-ui-1.9.2.js"></script>
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
