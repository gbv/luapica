<?php

ini_set('display_errors', '1');

require_once 'config.php';

# http://pear.php.net/manual/en/package.tools.versioncontrol-git.tutorial.handle-command.php
require_once 'VersionControl/Git.php';

class PicaEdit {
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
       $reg = '/^'.preg_quote("$path/",'/').'('.PicaEdit::$NAME_REG.')/';
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
       if (!preg_match('/^'.PicaEdit::$NAME_REG.'$/',$name)) {
           throw new Exception('Invalid name');
       }
       $file = $this->config['repository']."scripts/$name.lua";
       $script = @file_get_contents($file);
       if ($script === false) throw new Exception('failed to get script');
       return $script;
   }

   function saveScript($name,$script) {
       if (!preg_match('/^'.PicaEdit::$NAME_REG.'$/',$name)) {
           throw new Exception('Invalid name');
       }
       if (!$script or preg_match('/^\s+$/m',$script)) {
           throw new Exception('Empty script');
       }
       $file = $this->config['repository']."scripts/$name.lua";

       # TODO: compile with lua and reject on syntax errors

       if (@file_put_contents($file, $script)) {
          $cmd = $this->git->getCommand('add')->addArgument( "scripts/$name.lua" );
          $response = $cmd->execute();
          $cmd = $this->git->getCommand('commit')->setOptions(array(
             # TODO: author, date
             "message" => "saved script $name.lua",
          ))->addArgument( "scripts/$name.lua" );
          $response = $cmd->execute();
       } else {
          throw new Exception("failed to write file");
       } 
       return $response;
       # TODO: on error restore old file
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


#$command = $git->getCommand('show');
#$result = $command->execute();

$pe = new PicaEdit($config);

#var_dump($pe->listScripts());
#var_dump($pe->listSamples());

try {
    $action = @$_REQUEST['action'];
    $name   = @$_REQUEST['name'];
    $script = @$_REQUEST['script'];
    if ($action == 'listscripts') {
        $scripts = $pe->listScripts();
        $pe->sendJSON( array( 'scripts' => $scripts ) ); 
    } elseif ($action == 'getscript') {
        $script = $pe->getScript( $name );
        $pe->sendJSON( array( 'script' => $script ) ); 
    } elseif ($action == 'savescript') {
        $status = $pe->saveScript( $name, $script );
        $pe->sendJSON( array( 'script' => $script, 'name' => $name, 'status' => $status ) ); 
    } else {
        throw new Exception("unknown action");
    }
} catch( Exception $e ) {
    $pe->sendJSON( array( 'error' => $e->getMessage() ) );
}

?>
