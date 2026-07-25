<?php
script('aiba_pos', 'pos');
style('aiba_pos', 'pos');
?>
<div id="aiba-pos" class="pos-wrap">
    <div class="pos-header">
        <h2><?php p($l->t('POS — boshqaruv')); ?></h2>
        <div class="pos-header__actions">
            <select id="pos-restaurant" class="pos-select"></select>
            <button id="pos-seed" class="pos-btn pos-btn--ghost"><?php p($l->t('Demo ma\'lumot')); ?></button>
            <button id="pos-refresh" class="pos-btn pos-btn--primary"><?php p($l->t('Yangilash')); ?></button>
        </div>
    </div>

    <div id="pos-empty" class="pos-empty" style="display:none">
        <p><?php p($l->t('Restoran yo\'q. "Demo ma\'lumot" tugmasini bosing yoki cloud-os orqali restoran qo\'shing.')); ?></p>
    </div>

    <div id="pos-body" class="pos-body" style="display:none">
        <div class="pos-cards">
            <div class="pos-card"><span class="pos-card__label"><?php p($l->t('Bugungi savdo')); ?></span><span class="pos-card__value" id="pos-total">—</span></div>
            <div class="pos-card"><span class="pos-card__label"><?php p($l->t('Cheklar')); ?></span><span class="pos-card__value" id="pos-orders">—</span></div>
            <div class="pos-card"><span class="pos-card__label"><?php p($l->t('Naqd')); ?></span><span class="pos-card__value" id="pos-cash">—</span></div>
            <div class="pos-card"><span class="pos-card__label"><?php p($l->t('Karta')); ?></span><span class="pos-card__value" id="pos-card">—</span></div>
        </div>

        <div class="pos-grid">
            <section class="pos-panel">
                <h3><?php p($l->t('Mahsulotlar')); ?> <span id="pos-prodcount" class="pos-muted"></span></h3>
                <table class="pos-table">
                    <thead><tr>
                        <th><?php p($l->t('Nomi')); ?></th>
                        <th><?php p($l->t('Narx')); ?></th>
                        <th>MXIK</th>
                    </tr></thead>
                    <tbody id="pos-products"></tbody>
                </table>
            </section>

            <section class="pos-panel">
                <h3><?php p($l->t('Oxirgi cheklar')); ?></h3>
                <table class="pos-table">
                    <thead><tr>
                        <th>#</th>
                        <th><?php p($l->t('Holat')); ?></th>
                        <th><?php p($l->t('Summa')); ?></th>
                        <th><?php p($l->t('Fiskal')); ?></th>
                    </tr></thead>
                    <tbody id="pos-orderlist"></tbody>
                </table>
            </section>
        </div>
    </div>
</div>
