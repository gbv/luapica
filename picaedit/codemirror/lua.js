/**
 * Defines basic lua syntax highlighting with for CodeMirror 2.
 * Based on the 'clike' mode. Surely not free of bugs.
 */

CodeMirror.defineMode("lua", function(config, parserConfig) {
  function splitkeywords(str) {
    var obj = {}, words = str.split(" ");
    for (var i = 0; i < words.length; ++i) obj[words[i]] = true;
    return obj;
  }
  var keywords = "and break elseif false nil not or return "
               + "true function end if then else do "
               + "while repeat until for in local";
  keywords = splitkeywords(keywords);
  var stdfunctions =
  "_G _VERSION assert collectgarbage dofile error getfenv getmetatable ipairs load loadfile loadstring module next pairs pcall print rawequal rawget rawset require select setfenv setmetatable tonumber tostring type unpack xpcall "
+ "coroutine.create coroutine.resume coroutine.running coroutine.status coroutine.wrap coroutine.yield "
+ "debug.debug debug.getfenv debug.gethook debug.getinfo debug.getlocal debug.getmetatable debug.getregistry debug.getupvalue debug.setfenv debug.sethook debug.setlocal debug.setmetatable debug.setupvalue debug.traceback "
+ "close flush lines read seek setvbuf write "
"io.close io.flush io.input io.lines io.open io.output io.popen io.read io.stderr io.stdin io.stdout io.tmpfile io.type io.write "
+ "math.abs math.acos math.asin math.atan math.atan2 math.ceil math.cos math.cosh math.deg math.exp math.floor math.fmod math.frexp math.huge math.ldexp math.log math.log10 math.max math.min math.modf math.pi math.pow math.rad math.random math.randomseed math.sin math.sinh math.sqrt math.tan math.tanh "
+ "os.clock os.date os.difftime os.execute os.exit os.getenv os.remove os.rename os.setlocale os.time os.tmpname "
+ "package.cpath package.loaded package.loaders package.loadlib package.path package.preload package.seeall "
"string.byte string.char string.dump string.find string.format string.gmatch string.gsub string.len string.lower string.match string.rep string.reverse string.sub string.upper "
+ "table.concat table.insert table.maxn table.remove table.sort";
  stdfunctions = splitkeywords(stdfunctions);

  var indentUnit = config.indentUnit,
      multiLineStrings = parserConfig.multiLineStrings,
      $vars = parserConfig.$vars, atAnnotations = parserConfig.atAnnotations;
  var isOperatorChar = /[+\-*&%=<>!?~|#]/;

  function chain(stream, state, f) {
    state.tokenize = f;
    return f(stream, state);
  }

  var type;
  function ret(tp, style) {
    type = tp;
    return style;
  }

  function tokenBase(stream, state) {
    var ch = stream.next();
    if (ch == '"' || ch == "'")
      return chain(stream, state, tokenString(ch));
    else if (/[\[\]{}\(\),;\:\.]/.test(ch))
      return ret(ch);
    else if (/\d/.test(ch)) {
      stream.eatWhile(/[\w\.]/)
      return ret("number", "lua-number");
    }
    else if (ch == "-") {
/*   if (stream.eat("*")) { // TODO: support [[ ]]
        return chain(stream, state, tokenComment);
      }*/      
      if (stream.eat("-")) {
        stream.skipToEnd(); // TODO: support --[[
        return ret("comment", "lua-comment");
      }
      else {
        stream.eatWhile(isOperatorChar);
        return ret("operator");
      }
    }
    else if (isOperatorChar.test(ch)) {
      stream.eatWhile(isOperatorChar);
      return ret("operator");
    }
    else {
      stream.eatWhile(/[\w\$_]/);
      if (keywords && keywords.propertyIsEnumerable(stream.current()))
        return ret("keyword", "lua-keyword");
      
      if (stdfunctions && stdfunctions.propertyIsEnumerable(stream.current()))
        return ret("keyword", "lua-stdkeyword");
      
      return ret("word", "c-like-word");
    }
  }

  function tokenString(quote) {
    return function(stream, state) {
      var escaped = false, next, end = false;
      while ((next = stream.next()) != null) {
        if (next == quote && !escaped) {end = true; break;}
        escaped = !escaped && next == "\\";
      }
      if (end || !(escaped || multiLineStrings))
        state.tokenize = tokenBase;
      return ret("string", "lua-string");
    };
  }

  function tokenComment(stream, state) {
    var maybeEnd = false, ch;
    while (ch = stream.next()) {
      if (ch == "/" && maybeEnd) {
        state.tokenize = tokenBase;
        break;
      }
      maybeEnd = (ch == "*");
    }
    return ret("comment", "lua-comment");
  }

  function Context(indented, column, type, align, prev) {
    this.indented = indented;
    this.column = column;
    this.type = type;
    this.align = align;
    this.prev = prev;
  }

  function pushContext(state, col, type) {
    return state.context = new Context(state.indented, col, type, null, state.context);
  }
  function popContext(state) {
    return state.context = state.context.prev;
  }

  // Interface

  return {
    startState: function(basecolumn) {
      return {
        tokenize: tokenBase,
        context: new Context((basecolumn || 0) - indentUnit, 0, "top", false),
        indented: 0,
        startOfLine: true
      };
    },

    token: function(stream, state) {
      var ctx = state.context;
      if (stream.sol()) {
        if (ctx.align == null) ctx.align = false;
        state.indented = stream.indentation();
        state.startOfLine = true;
      }
      if (stream.eatSpace()) return null;
      var style = state.tokenize(stream, state);
      if (type == "comment") return style;
      if (ctx.align == null) ctx.align = true;

      if ((type == ";" || type == ":") && ctx.type == "statement") popContext(state);
      else if (type == "{") pushContext(state, stream.column(), "}");
      else if (type == "[") pushContext(state, stream.column(), "]");
      else if (type == "(") pushContext(state, stream.column(), ")");
      else if (type == "}") {
        if (ctx.type == "statement") ctx = popContext(state);
        if (ctx.type == "}") ctx = popContext(state);
        if (ctx.type == "statement") ctx = popContext(state);
      }
      else if (type == ctx.type) popContext(state);
      else if (ctx.type == "}") pushContext(state, stream.column(), "statement");
      state.startOfLine = false;
      return style;
    },

    indent: function(state, textAfter) {
      if (state.tokenize != tokenBase) return 0;
      var firstChar = textAfter && textAfter.charAt(0), ctx = state.context, closing = firstChar == ctx.type;
      if (ctx.type == "statement") return ctx.indented + (firstChar == "{" ? 0 : indentUnit);
      else if (ctx.align) return ctx.column + (closing ? 0 : 1);
      else return ctx.indented + (closing ? 0 : indentUnit);
    },

    electricChars: "{}"
  };
});


