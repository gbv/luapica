<?php

$config = array(
  "unapi"      => "http://unapi.gbv.de/",

  //
  // The repository must be writeable by www-user:
  //
  // $ chgrp -R www-data .git
  // $ chgrp -R www-data *
  // $ find -type d -exec chmod 2775 '{}' ';'
  // $ find -type f -exec chmod 664 '{}' ';'
  //
  // To allow read-access via HTTP(S) you should further enable a post-hook
  // that runs `git update-server-info`:
  //
  // $ cp .git/hooks/post-update.sample .git/hooks/post-update
  // 
  // To run it manually:
  //
  // $ sudo -u www-data git update-server-info
  //
  // You can then access the repository via:
  //
  // git clone http://...../repository/.git
  //
  // A good overview how to share a git repository:
  // http://www.jedi.be/blog/2009/05/06/8-ways-to-share-your-git-repository/
  "repository" => "../repository/",
);

?>
