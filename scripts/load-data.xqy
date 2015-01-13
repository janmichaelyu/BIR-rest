xquery version "1.0-ml";

let $location := "/Users/pkester/Customers/Phillipines/csv-step6/"
let $fileListName := "/Users/pkester/Customers/Phillipines/file-overview-tony-6.xml"
let $fileList := xdmp:document-get($fileListName)

for $file in $fileList//csvfile
let $_ := xdmp:log(fn:concat("Processing file ",$location,$file),"debug")
let $start := $file/start-date/text()
let $end := $file/end-date/text()
let $do-no := $file/do-no/text()
let $revision := $file/revision/text()
let $sec := (xdmp:permission("BIR-rest-role", "read"),
             xdmp:permission("BIR-rest-role", "insert"),
             xdmp:permission("BIR-rest-role", "update"))
let $fileName := fn:concat($location,$file/filename/text())
let $map := map:map()
let $_ := map:put($map,"fileName",$fileName)
let $_ := map:put($map,"start",$start)
let $_ := map:put($map,"end",$end)
let $_ := map:put($map,"do-no",$do-no)
let $_ := map:put($map,"revision",$revision)
let $_ := map:put($map,"sec",$sec)

return xdmp:spawn("/lib/load-file.xqy",
  (xs:QName("params"),$map)) 
