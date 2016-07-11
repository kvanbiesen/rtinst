<?php

///
///
/// The Seedbox From Scratch Script
///   By Notos ---> https://github.com/Notos/
///
///
/// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
///
///  Copyright (c) 2013 Notos (https://github.com/Notos/)
///
///  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
///
///  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
///
///  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
///
///  --> Licensed under the MIT license: http://www.opensource.org/licenses/mit-license.php
///
/// --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
///

  require_once( '../../php/util.php' );

  if(!isset($quotaUser)) {
    $quotaUser = '';
  }
  $homeUser  = $topDirectory.'/'.$quotaUser;
  $homeBase  = $topDirectory;
  $quotaEnabled = FALSE;
  if (isset($quotaUser) and !Empty($quotaUser) and file_exists($homeBase.'/aquota.user')) {
    $quotaEnabled = myGetDirs($quotaUser, &$homeUser, &$homeBase); /// get the real home dir
  }

  if ($quotaEnabled) {
    $total = shell_exec("/usr/bin/sudo /usr/sbin/repquota -u $homeBase | grep ^".$quotaUser." | awk '{print \$4}'") * 1024;
    $used = shell_exec("/usr/bin/sudo /usr/sbin/repquota -u $homeBase | grep ^".$quotaUser." | awk '{print \$3}'") * 1024;

    if ($total == 0) {
      $total = disk_total_space($topDirectory);
    }

    $free = ($total - $used);
  } else {
    $total = disk_total_space($topDirectory);
    $free = disk_free_space($topDirectory);
  }

  cachedEcho('{ "total": '.$total.', "free": ' .$free.' }',"application/json");

  function myGetDirs($username, $homeUser, $homeBase) {
    $passwd = file('/etc/passwd');
    $path = false;
    foreach ($passwd as $line) {
      if (strstr($line, $username) !== false) {
        $parts = explode(':', $line);
        $path = $parts[5];
        break;
      }
    }

    $ret = TRUE;  
    $U = realpath($path); /// expand
    $B = realpath($path."/.."); /// home is the previous path
  
    if (isset($U) and !Empty($U) and is_dir($U)) {
      $homeUser = $U;
    } else {
      $ret = FALSE;
    }
    if (isset($B) and !Empty($B) and is_dir($B)) {
      $homeBase = $B;
    } else {
      $ret = FALSE;
    }

    return $ret;
  }