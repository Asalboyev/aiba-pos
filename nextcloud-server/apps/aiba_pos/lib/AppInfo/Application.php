<?php
namespace OCA\AibaPos\AppInfo;

use OCP\AppFramework\App;

class Application extends App {
    public const APP_ID = 'aiba_pos';

    public function __construct() {
        parent::__construct(self::APP_ID);
    }
}
