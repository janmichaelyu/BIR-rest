(function ($) {
    $.widget("custom.combobox", {

        _create: function () {
            this.wrapper = $("<span>")
                .addClass("custom-combobox")
                .insertAfter(this.element);
            this.element.hide();
            this._createAutocomplete();
            this._createShowAllButton();
        },

        _createAutocomplete: function () {
            var selected = this.element.children(":selected"),
                firstVal = this.element.children("option")[0].text,
                value = selected.val() ? selected.text() : firstVal;

            this.input = $("<input>")
                .appendTo(this.wrapper)
                .val(value)
                .attr("title", "")
                .addClass("custom-combobox-input ui-widget ui-widget-content ui-state-default ui-corner-left")
                .autocomplete({
                    delay: 0,
                    minLength: 0,
                    source: $.proxy(this, "_source")
                })
                .tooltip({
                    tooltipClass: "ui-state-highlight"
                })
                .on('mouseup', function () {
                    $(this).select();
                });

            $(this).blur();

            this._on(this.input, {
                autocompleteselect: function (event, ui) {
                    ui.item.option.selected = true;
                    this._trigger("select", event, {
                        item: ui.item.option
                    });
                },
                autocompletechange: "_removeIfInvalid"
            });
        },

        _createShowAllButton: function () {
            var input = this.input,
                wasOpen = false;

            $("<a>")
                .attr("tabIndex", -1)
                .attr("title", "Show All Items")
                .tooltip()
                .appendTo(this.wrapper)
                .button({
                    icons: {
                        primary: "ui-icon-triangle-1-s"
                    },
                    text: false
                })
                .removeClass("ui-corner-all")
                .addClass("custom-combobox-toggle ui-corner-right")
                .mousedown(function () {
                    wasOpen = input.autocomplete("widget").is(":visible");
                })
                .click(function () {
                    input.focus();
                    input.blur();

                    // Close if already visible
                    if (wasOpen) {
                        return;
                    };

                    // Pass empty string as value to search for, displaying all results
                    input.autocomplete("search", "");
                });
        },

        _source: function (request, response) {
            var matcher = new RegExp($.ui.autocomplete.escapeRegex(request.term), "i");
            response(this.element.children("option").map(function () {
                var text = $(this).text();
                if (this.value && (!request.term || matcher.test(text))) return {
                    label: text,
                    value: text,
                    option: this
                };
            }));
        },

        _removeIfInvalid: function (event, ui) {
            // Selected an item, nothing to do
            if (ui.item) {

                var selected = this.element;
                return;
            };

            // Search for a match (case-insensitive)
            var default_text = "";

            var value = this.input.val(),
                valueLowerCase = value.toLowerCase(),
                valid = false;

            this.element.children("option").each(function () {

                if ($(this).val() == "default") {
                    default_text = $(this).text();
                };

                if ($(this).text().toLowerCase() === valueLowerCase) {
                    this.selected = valid = true;
                    return false;
                };
            });

            // Found a match, nothing to do
            if (valid) {
                return;
            };

            // Remove invalid value
            this.input.val(default_text)
                .attr("title", value + " didn't match any item")
                .tooltip("open");

            this._delay(function () {
                this.input.tooltip("close").attr("title", "");
            }, 2500);
            this.input.data("ui-autocomplete").term = "";
        },

        _destroy: function () {
            this.wrapper.remove();
            this.element.show();
        },

        refresh: function () {
            selected = this.element.children(":selected");
            this.input.val(selected.text());
        },

        select: function (event, ui) {
            ui.item.option.selected = true;
            self._trigger("selected", event, {
                item: ui.item.option
            });
            select.trigger("change");
        },

        change: function (event, ui) {
            if (!ui.item) {
                var matcher = new RegExp("^" + $.ui.autocomplete.escapeRegex($(this).val()) + "$", "i"),
                    valid = false;
                select.children("option").each(function () {
                    if ($(this).text().match(matcher)) {
                        this.selected = valid = true;
                        return false;
                    };
                });
                if (!valid) {
                    // remove invalid value, as it didn't match anything
                    $(this).val("");
                    select.val("");
                    input.data("autocomplete").term = "";
                    return false;
                };
            };
        }
    });
})(jQuery);

