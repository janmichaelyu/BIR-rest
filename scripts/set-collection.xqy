xquery version "1.0-ml";

let $uris := cts:uris("",(),cts:not-query(cts:directory-query("/config/","infinity")))
for $uri in $uris
return xdmp:document-add-collections($uri,"listings")