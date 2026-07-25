<?php
return [
    'routes' => [
        // Page
        ['name' => 'page#index', 'url' => '/', 'verb' => 'GET'],

        // API — proxied to the pos microservice. URLs start with /api/ so the
        // aiba_integration AiChatController can discover + call them.
        ['name' => 'pos#restaurants', 'url' => '/api/restaurants', 'verb' => 'GET'],
        ['name' => 'pos#products', 'url' => '/api/products', 'verb' => 'GET'],
        ['name' => 'pos#orders', 'url' => '/api/orders', 'verb' => 'GET'],
        ['name' => 'pos#salesSummary', 'url' => '/api/sales-summary', 'verb' => 'GET'],

        // API — management (manager / admin only, enforced in the controller)
        ['name' => 'pos#createRestaurant', 'url' => '/api/restaurants', 'verb' => 'POST'],
        ['name' => 'pos#createTerminal', 'url' => '/api/restaurants/{restaurant_id}/terminals', 'verb' => 'POST'],
        ['name' => 'pos#createStaff', 'url' => '/api/restaurants/{restaurant_id}/staff', 'verb' => 'POST'],
        ['name' => 'pos#createProduct', 'url' => '/api/products', 'verb' => 'POST'],
        ['name' => 'pos#seedDemo', 'url' => '/api/seed-demo', 'verb' => 'POST'],
    ],
];
