xquery version "1.0-ml";

declare default collation "http://marklogic.com/collation/en/MO";
declare option xdmp:mapping "false";

xdmp:set-response-content-type("text/html"),
xdmp:add-response-header("Cache-Control", "max-age=600"),

let $date := xdmp:get-request-field("date")

return
<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <meta charset="utf-8"/>
        <meta http-equiv="X-UA-Compatible" content="IE=edge"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title>Zonal Values - Bureau of Internal Revenue</title>
        
        <!-- Bootstrap -->
        <link href="/bootstrap-3.2.0/css/bootstrap.min.css" rel="stylesheet"/>
        
        <!--link rel="stylesheet" href="/js/datepicker/css/datepicker.css"/-->
        <link rel="stylesheet" href="/jquery-ui/1.9.2/css/custom-theme/jquery-ui-1.9.2.css"/>
    </head>
    <body>
        <form role="form" id="zonalForm">
            <div class="form-group">
                <label class="col-sm-2 control-label" for="date">Transaction Date:</label>
                <div class="col-sm-2">
                    <input class="ui-widget ui-corner-left ui-corner-right zonal-color" id="date" type="text" name="date" value="{ $date }" data-date-format="yyyy-mm-dd"/>
                </div>
            </div>
        </form>
        <script src="/jquery/1.11.1/jquery-1.11.1.js"></script>
        <!-- Include all compiled plugins (below), or include individual files as needed -->
        <script src="/bootstrap-3.2.0/js/bootstrap.min.js"></script>
        <script src="/jquery-ui/1.9.2/js/jquery-ui-1.9.2.js"></script>
        <script src="/js/datepicker/js/bootstrap-datepicker.js"></script>
        <script>
        $(function () {{
            $('#date').datepicker({{
                    onRender: function(date) {{
                        return date.valueOf();
                    }},
                    onSelect: function() {{
                        $("#zonalForm").submit();
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
        }});
        </script>
    </body>
</html>