<?php

$config = array(
  "unapi"      => "http://unapi.gbv.de/",

  // The repository must be writeable by www-user
  // $ chgrp -R www-data .git
  // $ chgrp -R www-data *
  // $ find -type d -exec chmod 2775 '{}' ';'
  // $ find -type f -exec chmod 664 '{}' ';'

  "repository" => "../repository/",
);

?>
