xquery version "1.0-ml";

module namespace bir = "http://marklogic.com/rest-api/resource/suggest";

declare namespace roxy = "http://marklogic.com/roxy";

declare variable $fields := ( "rdo", "barangay", "street", "condo", "vicinity", "class", "date" );

declare function bir:suggest(
  $element as xs:string,
  $q as xs:string,
  $len as xs:long
) as item()*
{
  cts:search(fn:collection("listings"),
    cts:element-word-query(xs:QName($element), fn:concat($q,'*'), ("case-insensitive","wildcarded","stemmed"))
  )[0 to $len]//xdmp:value($element)/text()
};

(: 
 : To add parameters to the functions, specify them in the params annotations. 
 : Example
 :   declare %roxy:params("uri=xs:string", "priority=xs:int") bir:get(...)
 : This means that the get function will take two parameters, a string and an int.
 :)

(:
 :)
declare 
%roxy:params("rdo= xs:string",
    "barangay=xs:string",
    "street=xs:string",
    "condo=xs:string",
    "vicinity=xs:string",
    "class=xs:string"
)
function bir:get(
  $context as map:map,
  $params  as map:map
) as document-node()*
{
  map:put($context, "output-types", "application/xml"),
  xdmp:set-response-code(200, "OK"),
  document {
    let $suggestions := map:map()
    let $rdo := if (map:contains($params, "rdo")) then map:put($suggestions,"rdo",map:get($params, "rdo")) else ()
    let $barangay := if (map:contains($params, "barangay")) then map:put($suggestions, "barangay", map:get($params, "barangay")) else ()
    let $street := if (map:contains($params, "street")) then map:put($suggestions, "street", map:get($params, "street")) else ()
    let $condo := if (map:contains($params, "condo")) then map:put($suggestions, "condo", fn:true()) else map:put($suggestions, "condo", fn:false())
    let $vicinity := if (map:contains($params, "vicinity")) then map:put($suggestions, "vicinity", map:get($params, "vicinity")) else ()
    let $class := if (map:contains($params, "class")) then map:put($suggestions, "class", map:get($params, "class")) else ()
    let $date := if (map:contains($params, "date")) then map:put($suggestions, "date", map:get($params, "date")) else fn:current-date()
    
    return element suggestions {
        for $field in map:keys($suggestions)
        return 
            element suggestion {
                attribute type { $field },
                for $sug in bir:suggest($field, map:get($suggestions,$field), 10)
                return element value { $sug }
            }
    }
  }
};
