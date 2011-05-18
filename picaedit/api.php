<?php
/**
 * This JSONP api wraps several other APIs for the LuaPICA bench.
 *
 * ?id={X}      get PICA+ record X via unAPI. Returns
 *              { "value": pprecord, "id": X }  or  { "error": msg }
 * ?name={S}    get script with name S. Returns
 *              { "script": script, "name": S }  or  { "error": msg }
 *
 * ?action=transform&script=...&value=...
 * ?action=transform&script=...&id={X}
 * ?action=transform&name={S}&value=...
 * ?action=transform&name={S}&id={X}
 * 
 */

ini_set('display_errors', '1');

require_once 'config.php';

# see http://pear.php.net/manual/en/package.tools.versioncontrol-git.tutorial.handle-command.php
require_once 'VersionControl/Git.php';

class LuaPICABench {
   var $config, $git;

   function __construct($config) {
       $this->config = $config;
       $this->git    = new VersionControl_Git( $config['repository'] );
   }

   function listScripts() {
       return $this->listFiles('scripts');
   }

   function listSamples() {
       return $this->listFiles('samples');
   }

   function listFiles($path) {
       $cmd   = $this->git->getCommand('ls-files')->addArgument($path);
       $files = split("\n",$cmd->execute());
       $reg = '/^'.preg_quote("$path/",'/').'('.LuaPICABench::$NAME_REG.')/';
       foreach ($files as $n => $f) {
           if (preg_match($reg,$f,$match)) {
               $files[$n] = $match[1];
           } else {
               unset($files[$n]);
           }
       }
       return $files; 
   }

   function getScript($name) {
       if (!preg_match('/^'.LuaPICABench::$NAME_REG.'$/',$name)) {
           throw new Exception('Invalid name');
       }
       $file = $this->config['repository']."scripts/$name.lua";
       $script = @file_get_contents($file);
       if ($script === false) throw new Exception('failed to get script');
       return $script;
   }

   function saveScript($name,$content) {
       if (!preg_match('/^'.LuaPICABench::$NAME_REG.'$/',$name)) {
           throw new Exception('Invalid name');
       }
       if (!$content or trim($content)=="") {
           throw new Exception('Empty content');
       }
       $file = $this->config['repository']."contents/$name.lua";

       # TODO: compile with lua and reject on syntax errors

       if (@file_put_contents($file, $content)) {
          $cmd = $this->git->getCommand('add')->addArgument( "contents/$name.lua" );
          $response = $cmd->execute();
          $cmd = $this->git->getCommand('commit')->setOptions(array(
             # TODO: author, date
             "message" => "saved content $name.lua",
          ))->addArgument( "contents/$name.lua" );
          $response = $cmd->execute();
       } else {
          throw new Exception("failed to write file");
       } 
       return $response;
       # TODO: on error restore old file
   }

   // Get a single record via unAPI
   function getRecord($id) {
       if (!$id) throw new Exception('id missing');
       if (!preg_match('/^[a-zA-Z_0-9:-]+$/',$id)) 
         throw new Exception("malformed id");
       $url = $this->config["unapi"];
       if (!$url) throw new Exception("no unapi configured");

       $url = "$url?id=$id&format=pp";
       $value = @file_get_contents($url);
       if ($value === false)
         throw new Exception("record not found");

       return $value;
   }   

   function transformLuaPica( $record, $script, $source = null) {
	$wrapper = "runluapica.lua";
	$maxTime = 2;

	$cmd = "(ulimit -t 1 ; lua $wrapper | head -c 8k)";
	$dspec = array(
	    0 => array('pipe', 'r'), // stdin
	    1 => array('pipe', 'w'), // stdout
	    2 => array('pipe', 'w')  // stderr
	);
	$pipes = array();
	$env = array( "record" => $record, "source" => $source );

	$proc = proc_open($cmd, $dspec, $pipes, null, $env);

	for($i=0;$i<2;$i++) {
	  stream_set_blocking($pipes[$i], 0);
	  stream_set_write_buffer($pipes[$i], 0);
	}

	fwrite($pipes[0], $script );
	fclose($pipes[0]);

	$result = "";

	// Wait for a response back on the other pipe
	$read = array($pipes[1]);
	$write = null;
	$except = null;

	while (!feof($pipes[1])) {
	    $num = stream_select($read, $write, $except, $maxTime);
	    
	    if ($num === false || $num === 0) {
		// Time to kill the thread
		// proc_terminate() is useless in this endeavor
		$status = proc_get_status($proc);
		
		if ($status['running'] == true) {
		    fclose($pipes[1]);
		    fclose($pipes[2]);
		    proc_terminate($proc);
		}
		proc_close($proc);
		throw new TimeExceededException('Max execution time reached');
	    }

	    $result .= fgets($pipes[1]);
	}
	fclose($pipes[1]);

	$error = ""; // read error 
	while (!feof($pipes[2])) {
	    $error .= fread($pipes[2],1024);
	}
	fclose($pipes[2]);
	if ( $error ) {
	    # TODO: clean up the error message and adjust/extract line numbers
	    $error = substr($error,strlen($wrapper)+6);
	    $error = preg_replace('/^\d+:\s*/','',$error);
	    if (preg_match('/^\s*(\d+): (.+)/',$error,$match)) {
		$errorline = $match[1];
	    }
	}

	proc_close($proc);
    
        // TODO: add $errorline
        if ($error) throw Exception($error);

        return $result;
   }

   function sendJSON($data) {
       $callback = @$_REQUEST['callback'];
       $json = json_encode($data);
       if (preg_match('/^[a-z_][a-z_0-9]*$/i',$callback)) {
           print "$callback($json);";
       } else {
           print $json;
       }
   }

   static $NAME_REG = '[[:alpha:]]([[:alnum:] _-]*[[:alnum:]]+)?';
}

################################################################################

$pe = new LuaPICABench($config);

#var_dump($pe->listScripts());
#var_dump($pe->listSamples());

try {
    if (php_sapi_name() == 'cli') { // allow testing on the command line
       foreach( $argv as $arg ) {
           if (preg_match('/([^=]+)=(.*)$/',$arg,$match))
             $_REQUEST[$match[1]] = $match[2];
       }
    }

    $action  = @$_REQUEST['action'];
    $id      = @$_REQUEST['id'];
    $name    = @$_REQUEST['name'];
    $value   = @$_REQUEST['value'];
    $content = @$_REQUEST['content'];
    $script  = @$_REQUEST['script'];

    if (!$action && !$id) {
        if ($name) $action = "getscript";
    }

    if ($action == 'listscripts') {
        $scripts = $pe->listScripts();
        $pe->sendJSON( array( 'scripts' => $scripts ) ); 
    } elseif ($action == 'getscript') {
        $script = $pe->getScript( $name );
        $pe->sendJSON( array( 'script' => $script ) ); 
    } elseif ($action == 'savescript') {
        $status = $pe->saveScript( $name, $script );
        $pe->sendJSON( array( 'name' => $name, 'script' => $script, 'status' => $status ) ); 
    } elseif ($action == 'transform') {
        if ($id) $record = $pe->getRecord($id);
        elseif ($value) $record = $value;
        if (!$record) throw new Exception("empty record value");
        if ($name) $script = $pe->getScript($name);
        if (!$script) throw new Exception("no script provided");

        $result = $pe->transformLuaPica( $record, $script );

        $pe->sendJSON( array( 'result' => $result ) );
    } else { // get record
        $record = $pe->getRecord($id);
        $pe->sendJSON( array( 'value' => $record, 'id' => $id ) );
    }
} catch( Exception $e ) {
    $pe->sendJSON( array( 'error' => $e->getMessage() ) );
}

?>
