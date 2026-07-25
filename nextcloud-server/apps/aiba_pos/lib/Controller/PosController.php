<?php
namespace OCA\AibaPos\Controller;

use OCP\AppFramework\Controller;
use OCP\AppFramework\Http\JSONResponse;
use OCP\IRequest;
use OCP\IGroupManager;

/**
 * Thin proxy from the Nextcloud app to the pos microservice.
 *
 * Access control lives here (cloud-os): only logged-in users reach these
 * methods, management actions require admin or the `pos_managers` group, and
 * the call to the backend is authenticated with the shared service secret.
 */
class PosController extends Controller {
    private string $posUrl;
    private string $serviceSecret;
    private IGroupManager $groupManager;
    private ?string $userId;

    public function __construct(string $appName, IRequest $request, ?string $userId, IGroupManager $groupManager) {
        parent::__construct($appName, $request);
        $this->userId = $userId ?? '';
        $this->groupManager = $groupManager;
        $this->posUrl = rtrim(getenv('POS_API_URL') ?: 'http://pos:8000', '/');
        $this->serviceSecret = getenv('AIBA_SERVICE_SECRET') ?: '';
    }

    private function isManager(): bool {
        if ($this->userId && $this->groupManager->isAdmin($this->userId)) {
            return true;
        }
        return $this->userId && $this->groupManager->isInGroup($this->userId, 'pos_managers');
    }

    private function req(string $method, string $path, ?array $data = null): array {
        $ch = curl_init($this->posUrl . $path);
        $headers = ['X-Service-Secret: ' . $this->serviceSecret, 'Accept: application/json'];
        $opts = [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 30,
            CURLOPT_CUSTOMREQUEST => $method,
        ];
        if ($data !== null) {
            $opts[CURLOPT_POSTFIELDS] = json_encode($data);
            $headers[] = 'Content-Type: application/json';
        }
        $opts[CURLOPT_HTTPHEADER] = $headers;
        curl_setopt_array($ch, $opts);
        $body = curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        curl_close($ch);
        return ['body' => $body, 'code' => $code, 'error' => $error];
    }

    private function pass(array $r): JSONResponse {
        $data = json_decode($r['body'] ?? '', true);
        if ($data === null && trim((string)($r['body'] ?? '')) !== 'null') {
            return new JSONResponse(
                ['error' => 'pos service unavailable', 'detail' => $r['error'] ?: $r['body']],
                $r['code'] ?: 502
            );
        }
        return new JSONResponse($data, $r['code'] ?: 200);
    }

    /** @NoAdminRequired */
    public function restaurants(): JSONResponse {
        return $this->pass($this->req('GET', '/api/internal/admin/restaurants'));
    }

    /** @NoAdminRequired */
    public function products(string $restaurant_id = ''): JSONResponse {
        return $this->pass($this->req('GET', '/api/v2/menu/products?restaurant_id=' . urlencode($restaurant_id)));
    }

    /** @NoAdminRequired */
    public function orders(string $restaurant_id = ''): JSONResponse {
        return $this->pass($this->req('GET', '/api/v2/orders?restaurant_id=' . urlencode($restaurant_id) . '&limit=50'));
    }

    /** @NoAdminRequired */
    public function salesSummary(string $restaurant_id = '', ?string $date_from = null, ?string $date_to = null): JSONResponse {
        $q = '/api/v2/reports/sales-summary?restaurant_id=' . urlencode($restaurant_id);
        if ($date_from) {
            $q .= '&date_from=' . urlencode($date_from);
        }
        if ($date_to) {
            $q .= '&date_to=' . urlencode($date_to);
        }
        return $this->pass($this->req('GET', $q));
    }

    /** @NoAdminRequired */
    public function createRestaurant(): JSONResponse {
        if (!$this->isManager()) {
            return new JSONResponse(['error' => 'forbidden'], 403);
        }
        $payload = [
            'name' => (string)$this->request->getParam('name', ''),
            'code' => (string)$this->request->getParam('code', ''),
            'inn' => $this->request->getParam('inn'),
            'company_id' => $this->request->getParam('company_id'),
            'legal_name' => $this->request->getParam('legal_name'),
            'address' => $this->request->getParam('address'),
        ];
        return $this->pass($this->req('POST', '/api/internal/admin/restaurants', $payload));
    }

    /** @NoAdminRequired */
    public function createTerminal(string $restaurant_id): JSONResponse {
        if (!$this->isManager()) {
            return new JSONResponse(['error' => 'forbidden'], 403);
        }
        $payload = [
            'name' => (string)$this->request->getParam('name', ''),
            'code' => (string)$this->request->getParam('code', ''),
            'fiscal_terminal_id' => $this->request->getParam('fiscal_terminal_id'),
        ];
        return $this->pass($this->req('POST', '/api/internal/admin/restaurants/' . urlencode($restaurant_id) . '/terminals', $payload));
    }

    /** @NoAdminRequired */
    public function createStaff(string $restaurant_id): JSONResponse {
        if (!$this->isManager()) {
            return new JSONResponse(['error' => 'forbidden'], 403);
        }
        $payload = [
            'full_name' => (string)$this->request->getParam('full_name', ''),
            'code' => (string)$this->request->getParam('code', ''),
            'pin' => (string)$this->request->getParam('pin', ''),
            'role' => (string)$this->request->getParam('role', 'cashier'),
            'cloud_user_id' => $this->request->getParam('cloud_user_id'),
        ];
        return $this->pass($this->req('POST', '/api/internal/admin/restaurants/' . urlencode($restaurant_id) . '/staff', $payload));
    }

    /** @NoAdminRequired */
    public function createProduct(): JSONResponse {
        if (!$this->isManager()) {
            return new JSONResponse(['error' => 'forbidden'], 403);
        }
        $payload = [
            'restaurant_id' => (string)$this->request->getParam('restaurant_id', ''),
            'name' => (string)$this->request->getParam('name', ''),
            'price' => $this->request->getParam('price', 0),
            'category_id' => $this->request->getParam('category_id'),
            'mxik_code' => $this->request->getParam('mxik_code'),
            'vat_percent' => $this->request->getParam('vat_percent', 12),
            'unit' => (string)$this->request->getParam('unit', 'dona'),
        ];
        return $this->pass($this->req('POST', '/api/v2/menu/products', $payload));
    }

    /** @NoAdminRequired */
    public function seedDemo(): JSONResponse {
        if (!$this->isManager()) {
            return new JSONResponse(['error' => 'forbidden'], 403);
        }
        return $this->pass($this->req('POST', '/api/internal/admin/seed-demo', []));
    }
}
