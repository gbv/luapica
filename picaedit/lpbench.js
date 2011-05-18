/**
 * Displays the output of a script, possibly with status, diff, etc.
 */
$.widget('ui.outputview',{
    _create: function() {
        var textarea = this.element.get(0);
        this.codemirror = CodeMirror.fromTextArea( textarea, {
            lineNumbers: false, 
            mode: "text/plain",
            readOnly: true
        });
    },
    setOutput: function(data) {
        if (!data) data = "";
        this.codemirror.setValue( data );
    }
});

/*
function analyzeLuaCursor() {
    return; // TODO: re-anable

    var sel = luaedit.getSelection();
    if (sel && sel.match(/^[0-2][0-9][0-9][A-Z@]$/)) {
        locate(sel);
    } else {
        locate(false);
    }
}*/

/**
 * Provides a textbox with syntax highlighting
 */
$.widget('ui.luaedit',{
    options: {
        scripts: null,
        api: 'api.php',      
    },
    _create: function() {
        var textarea = this.element.get(0);
        var me = this;
        this.codemirror = CodeMirror.fromTextArea( textarea , {
            lineNumbers: true, mode: 'lua', 
            //onChange: function() { me.codeChanged(me); } //??
        });
        this.picaedit = this.options.picaedit;
        this.api = this.options.api;
        this.scriptname = $(this.options.name);
        this.statusbar  = $(this.options.statusbar);
        if (this.options.scripts) {
            this.scripts = $(this.options.scripts);
            this.listScripts();
        }
    },
    showStatus: function( ok, message ) {
        if (!this.statusbar) return;        
        if (ok) {
            this.statusbar.removeClass("error").addClass("ok");
        } else {
            this.statusbar.removeClass("ok").addClass("error");
        }        
        if (!message) message = "";
        this.statusbar.text( message ).show();
    },
    listScripts: function() {
        if (!this.scripts || !this.api) return;
        var scripts = this.scripts;
        var me = this;
        $.get( this.api, {action: 'listscripts'}, function( result ) {
            scripts.empty();
            me.scriptlist = {};
            if( result && result.scripts ) {
                for( var i=0; i<result.scripts.length; i++ ) {
                    var name = result.scripts[i];
                    var e = $('<div>').text( name );
                    scripts.append(e);
                    me.scriptlist[name] = e;
                }
            }
        },'jsonp');
    },
    loadScript: function() {
        var codemirror = this.codemirror;
        var name   = this.scriptname.val(); // TODO: might be null or invalid
        var me     = this;
        $.get( this.api, { action:'getscript', name:name }, function( result ) {
            if( result && result.script ) {
                codemirror.setValue( result.script );
            }
            if ( result.error ) {
                me.showStatus( false, result.error );
            }
        },'jsonp');
    },
    saveScript: function() {
        var name    = this.scriptname.val(); // TODO: might be null or invalid
        var script  = this.codemirror.getValue();
        var me      = this;
        $.post( this.api, {action:'savescript',script:script,name:name}, function(result) {
            if ( result.error ) {
                me.showStatus( false, result.error );
            } else {  
                // ...
            }
            me.listScripts();
        },'jsonp');
    },
    executeScript: function() {
        var me = this;
        var luaedit = this.codemirror;
        var data = {
            "value": $(this.picaedit).picatextarea('getValue'),
            "script" : luaedit.getValue(),
        };
        $.post( 'api.php?action=transform', data, function( result ) {
            if (typeof result != "object") {
                result = { "error" : "transformation failed" };
            }
            if (me.errorLine) {
                luaedit.clearMarker(me.errorLine);
                luaedit.setLineClass(me.errorLine,null);
            }
            if ( result.error && result.error != "" ) {
                me.showStatus( false, result.error );                
                result.line = parseInt(result.line);
                if ( result.line > 0 ) {
                    me.errorLine = result.line - 1;                    
                    luaedit.setLineClass(me.errorLine, "lua-errorline");
                    luaedit.setMarker(me.errorLine,"","lua-errormark");
                }
            } else {
                me.showStatus( true, "ok" );
            }
            $(me.options.output).outputview('setOutput',result.result);
        },"json");
    },
});
