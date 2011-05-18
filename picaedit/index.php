<!doctype html>
<?php 

require_once 'config.php';

?>
<html>
  <head>
    <title>LuaPICA Bench</title>
    <!-- jQuery and jQuery UI -->
    <!--link type="text/css" href="picatextarea/lib/jquery-ui-1.8.12.custom.css" rel="Stylesheet" /-->   
    <script type="text/javascript" src="picatextarea/lib/jquery-1.5.2.min.js"></script>
    <script type="text/javascript" src="picatextarea/lib/jquery-ui-1.8.12.custom.min.js"></script>
    <link rel="stylesheet" href="picatextarea/lib/codemirror.css">
    <script src="picatextarea/lib/codemirror.js"></script>
    <link rel="stylesheet" href="picatextarea/picatextarea.css">
    <script src="picatextarea/picatextarea.js"></script>
    <script src="codemirror/lua.js"></script>
    <link rel="stylesheet" href="codemirror/lua.css">

    <link rel="stylesheet" href="lpbench.css">
    <script type="text/javascript" src="lpbench.js"></script>
  </head>
  <body>
    <h1>LuaPICA bench</h1>
    <form>
     <textarea id="picaedit" name="picaedit">
003@ $0123456789
019@ $aXA-DE
021A $aDas @Beispiel mit $$-Zeichen
028C/01 $dMax$aMusterfrau$9a54321$8Musterfrau, Max
099Z $0test$1test$Atest$Ztest
101@ $a23$cPICA
203@/01 $09875
101@ $a23$cPICA
203@/99 $056321
123X $ax
</textarea></form>
<!--
001@ $0x
204@/99 $xfoo
This is an error
123A This also
123X/ $ax
-->
<!--
      <label for="pica-source">source</label>
      <input type="text" id="pica-source"/>
-->
  <p>edit, copy &amp; paste <b>lua transformation script</b> 
     (partial syntax highlighting).
      see <a href="https://github.com/nichtich/luapica/wiki">luapica wiki</a> 
      and <a href="http://www.lua.org/manual/5.1/">lua reference manual</a>
      for help.
  </p>

  <form>
  <table>
   <tr>
    <th></th>
    <!-- TODO: click and edit (rename) -->
    <th style="text-align:left">
      <span style="width:28px">&#xA0;</span>
      <input type="text" id="luascript-name"/>
      <input type="button" class="button" value="load" onClick="$('#luaedit').luaedit('loadScript');"/>
      <input type="button" class="button" value="save" onClick="$('#luaedit').luaedit('saveScript');"/>
    </th>
   </tr>
   <tr>
    <td style="vertical-align:top">
      <div id="scripts">&#xA0;</div>
      <!-- saved scripts and snippets (to load and save) -->
    </td>
    <td style="vertical-align:top">
      <!-- current script -->
      <textarea id="luaedit" name="luaedit">
print(record)
print()
print(record["021A"])
print("PPN: "..record["003@$0"])

dc, errors = record:map {
   title    = '!021A $a',    -- must be exactely one value
   authors  = '*028C/xx $8', -- optional any number of values
   language = '010@$a',      -- first matching value, if any  
   subject  = "+041A/xx $8"  -- at least one subject
}
print(dc.title)
if dc.authors then
   local authors = table.concat(dc.authors,", ")
   print("Authors: "..authors)
end
if (errors) then
   for field,msg in pairs(errors) do
       print("ERROR: "..field.." "..msg)
   end
end
  </textarea>
    </td>
    <td  style="vertical-align:top">
  <textarea id="output">
  </textarea>
 </td>
  </tr>
</table>
  <p>
  <input type="button" class="button" value="transform" onClick="$('#luaedit').luaedit('executeScript');"/>
  <span id="scriptstatus">&#x21E0; click to transform via lua script!</span>
  </p>
</form>

<script>
$(document).ready(function() {
  var picaedit =$('#picaedit').picatextarea({ 
    toolbar: ['undo','redo','name','load','error'],
    load: function(callback,id) {
      var url = "api.php?callback=?";
      $.getJSON( url, {id:id}, callback );
    },
    images: "picatextarea/img/silk/"
  });

  $('#luaedit').luaedit({
      scripts: '#scripts',
      output: $('#output').outputview(),
      name: '#luascript-name',
      statusbar: '#scriptstatus',
      picaedit: picaedit,
  });
});
</script>

    <div id="footer">
      <p>powered by <a href="http://codemirror.net/">CodeMirror</a> 
      (syntax highlighting) <a href="http://jquery.com/">jQuery</a>, 
      <a href="http://nichtich.github.com/picatextarea/">PICA textarea</a>, and
      <!--a href="http://layout.jquery-dev.net/">jquery.layout.js"</a>, and-->
      <a href="https://github.com/nichtich/luapica">luapica</a>
      </p>
    </div>
  </body>
</html>
