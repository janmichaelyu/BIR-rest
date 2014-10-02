xquery version "1.0-ml";

import module namespace bir = "http://www.bir.gov.ph/ml/lib" at "/lib/load_file_lib.xqy";

(:
declare variable $file as xs:string external;
declare variable $start as xs:string external;
declare variable $end as xs:string external;
:)
declare variable $params as map:map external;


xdmp:log(fn:concat("Spawn ",map:get($params,"fileName")," start"),"debug"),
bir:load-file($params, "listings"),
xdmp:log(fn:concat("Spawn ",map:get($params,"fileName")," stopped ",xdmp:elapsed-time()),"debug")
