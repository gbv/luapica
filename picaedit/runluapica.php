<?php

$cmd = "(ulimit -t 1 ; lua runluapica.lua | head -c 8k)";

$dspec = array(
    0 => array('pipe', 'r'), // stdin
    1 => array('pipe', 'w'), // stdout
    2 => array('pipe', 'w')  // stderr
);

$env = array( 
    "record" => @$_REQUEST['pica'],
    "source" => @$_REQUEST['source']
);

$pipes = array();

$proc = proc_open($cmd, $dspec, $pipes, null, $env);

$maxTime = 2;

stream_set_blocking($pipes[0], 0);
stream_set_blocking($pipes[1], 0);
stream_set_blocking($pipes[2], 0);
stream_set_write_buffer($pipes[0], 0);
stream_set_write_buffer($pipes[1], 0);
stream_set_write_buffer($pipes[2], 0);


$luacode    = @$_REQUEST['lua'];

fwrite($pipes[0], $luacode );
fclose($pipes[0]);

$result = array( "out" => "" );

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
    
    $result["out"] .= fgets($pipes[1]);
   
}
fclose($pipes[1]);

// read error 
$error = "";
while (!feof($pipes[2])) {
    $error .= fread($pipes[2],1024);
}
fclose($pipes[2]);
if ( $error ) {
    # TODO: clean up the error message and adjust/extract line numbers
    $result["error"] = $error;
}

proc_close($proc);


// return the output and error status in JSON

$callback = @$_REQUEST['callback'];
$json = json_encode($result);
if (preg_match('/^[a-z_][a-z_0-9]*$/i',$callback)) {
    print "$callback($json);";
} else {
    print $json;
}

?>
