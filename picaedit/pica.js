/**
 * Defines PICA+ syntax highlighting with error detection for CodeMirror 2.
 */

CodeMirror.defineMode("pica", function() {
  return {
    startState: function() {
      return { lev: 0, mode: 0  };
    },
    token: function(stream,state) {
      if (stream.sol()) { // read tag
        state.mode = 0;
        if (stream.eatWhile(/[^ $]/)) {
          var match = PICAEdit.tagpattern.exec(stream.current());
          if ( match ) {
            var lev = parseInt(match[1].charAt(0));
            if ((lev == 0 && state.lev > 0) || (lev == 2 && state.lev == 0)) {
              state.lev = lev;
              return "pica-tag-wrong";
            }
            state.lev = lev;
            if (!stream.match(/^\s*\$/,false)) {
              return "pica-error";
            }
            return "pica-tag";
          } else {
            return "pica-error";
          }
        }
      } else if (state.mode == 2 ) { // read value
        state.mode = 1;
        while( stream.skipTo('$') ) {
          if ( stream.match('$$') ) {
            stream.next(); stream.next();
          } else {
            return "pica-value";
          }
        }
        stream.skipToEnd();
        return "pica-value";
      } else { // read subfield
        if (state.mode == 0 && stream.eatSpace()) return;
        if (stream.next() == "$") {
          if ( stream.eat(/[a-zA-Z0-9]/) ) {
             state.mode = 2;
             var look = stream.peek(); // empty subfield
             if (!look || (look == '$' && !stream.match(/^$[^$]/))) {
               return "pica-error";
             }
             return "pica-sf";
          }
        }
      }
      stream.skipToEnd();
      return "pica-error";
    }
  };
});

/**
 * Global PICAEdit object to bundle functions.
 */
var PICAEdit = {
  tagpattern : /^([0-2][0-9][0-9][A-Z@])(\/([0-9][0-9]))?$/,
  // get current type, tag, subfield, and value 
  getFromCursor : function(editor) {
    var cursor = editor.getCursor();
    var tag="",sf="",value="",type="pica-tag";
    if (cursor) {
      var token = editor.getTokenAt({line:cursor.line,ch:1});
      type = token.className;
      if ( type == "pica-tag" || type == "pica-tag-wrong" ) {
        tag = token.string; 
        token = editor.getTokenAt(cursor);
        if (token.className == "pica-value") {
          value = token.string;
          token = editor.getTokenAt({line:cursor.line,ch:token.start-1})
        }
        if (token && token.className=="pica-sf") {
          sf = token.string;
          if (value=="") {
            token = editor.getTokenAt({line:cursor.line,ch:token.end+1})
            value = token.string;
          }
        }
      }
    }
    return {type:type,tag:tag,sf:sf,value:value};
  },
};

