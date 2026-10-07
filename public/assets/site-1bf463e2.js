/*
   QistManager - Shared JavaScript Utilities
    */

//  Print header (logo + business name/address/phone) for invoices/receipts
/**
 * Returns HTML for a standard print header showing the business logo,
 * name, address and phone (from QM.bizLogo/bizName/bizAddress/bizPhone),
 * with the document title/subtitle on the right.
 */
function qmPrintHeader(title, subtitle) {
    var logo = QM.bizLogo ? '<img src="' + QM.bizLogo + '" style="max-height:56px;max-width:120px;object-fit:contain;margin-right:12px">' : '';
    var addr = QM.bizAddress ? '<div style="font-size:.8rem;color:#555;">' + escHtml(QM.bizAddress) + '</div>' : '';
    var phone = QM.bizPhone ? '<div style="font-size:.8rem;color:#555;">Phone: ' + escHtml(QM.bizPhone) + '</div>' : '';
    return '<div style="display:flex;align-items:center;justify-content:space-between;border-bottom:3px solid #333;padding-bottom:.6rem;margin-bottom:1rem;">' +
        '<div style="display:flex;align-items:center;">' + logo +
            '<div><div style="font-size:1.35rem;font-weight:800;letter-spacing:.02em;">' + escHtml(QM.bizName || 'QistManager') + '</div>' + addr + phone + '</div>' +
        '</div>' +
        '<div style="text-align:right;">' +
            '<div style="font-size:1.15rem;font-weight:700;text-transform:uppercase;">' + escHtml(title || '') + '</div>' +
            (subtitle ? '<div style="font-size:.85rem;color:#555;">' + subtitle + '</div>' : '') +
        '</div>' +
    '</div>';
}

/**
 * Returns HTML for a centered print header for narrow 72mm thermal receipts.
 */
function qmPrintHeaderThermal(title) {
    var logo = QM.bizLogo ? '<img src="' + QM.bizLogo + '" style="max-height:40px;max-width:90px;object-fit:contain;margin-bottom:2px"><br>' : '';
    var addr = QM.bizAddress ? '<div>' + escHtml(QM.bizAddress) + '</div>' : '';
    var phone = QM.bizPhone ? '<div>Phone: ' + escHtml(QM.bizPhone) + '</div>' : '';
    return '<div class="pr-center">' + logo +
        '<strong style="font-size:13px;">' + escHtml(QM.bizName || 'QistManager') + '</strong>' +
        addr + phone +
        '<div class="pr-line"></div>' +
        '<strong>' + escHtml(title || '') + '</strong>' +
    '</div>';
}

//  AJAX helper 
/**
 * Post to a WebMethod on the current page.
 * @param {string}   method   e.g. "SaveCustomer"
 * @param {object}   data     Plain object; will be JSON-stringified
 * @param {function} onOk     Called with resp.d on HTTP 200
 * @param {function} onErr    Optional. Called with jqXHR on failure
 */
function qmAjax(method, data, onOk, onErr) {
    var url = window.location.pathname + '/' + method;
    $.ajax({
        type: 'POST',
        url: url,
        data: JSON.stringify(data || {}),
        contentType: 'application/json; charset=utf-8',
        dataType: 'json',
        success: function (resp) { onOk(resp.d); },
        error: function (xhr) {
            var msg = 'Server error';
            try { msg = JSON.parse(xhr.responseText).Message || msg; } catch (e) { }
            if (typeof onErr === 'function') onErr(xhr, msg);
            else qmToast(msg, 'danger');
        }
    });
}

//  Toast notifications 
/**
 * Show a Bootstrap toast at bottom-right.
 * @param {string} message
 * @param {string} type    'success' | 'danger' | 'warning' | 'info'
 */
function qmToast(message, type) {
    type = type || 'info';
    var iconMap = {
        success: 'bi-check-circle-fill',
        danger:  'bi-x-circle-fill',
        warning: 'bi-exclamation-triangle-fill',
        info:    'bi-info-circle-fill'
    };
    var icon = iconMap[type] || 'bi-info-circle-fill';

    if (!$('#toastContainer').length) {
        $('body').append('<div id="toastContainer" aria-live="polite" aria-atomic="true"></div>');
    }

    var id = 'toast_' + Date.now();
    var html = '<div id="' + id + '" class="toast align-items-center text-bg-' + type + ' border-0 mb-2" role="alert">'
        + '<div class="d-flex"><div class="toast-body"><i class="bi ' + icon + ' me-2"></i>' + escHtml(message) + '</div>'
        + '<button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button>'
        + '</div></div>';

    $('#toastContainer').append(html);
    var toastEl = document.getElementById(id);
    var bsToast = new bootstrap.Toast(toastEl, { delay: 4000 });
    bsToast.show();
    toastEl.addEventListener('hidden.bs.toast', function () { $(toastEl).remove(); });
}

//  Formatting helpers 
var qmCurrency = (typeof currency !== 'undefined') ? currency : 'Rs.';

function fmtAmt(n) {
    if (n == null || n === '') return qmCurrency + ' 0';
    return qmCurrency + ' ' + parseFloat(n).toLocaleString('en-PK', { maximumFractionDigits: 0 });
}

function fmtNum(n) {
    if (n == null) return '0';
    return parseInt(n).toLocaleString('en-PK');
}

function fmtDate(d) {
    if (!d) return '';
    var m = /\/Date\((\d+)\)\//.exec(d);
    if (m) return new Date(parseInt(m[1])).toLocaleDateString('en-PK');
    // Parse ISO yyyy-MM-dd as local date to avoid UTC midnight timezone shift
    var iso = /^(\d{4})-(\d{2})-(\d{2})/.exec(d);
    if (iso) return new Date(parseInt(iso[1]), parseInt(iso[2]) - 1, parseInt(iso[3])).toLocaleDateString('en-PK');
    return new Date(d).toLocaleDateString('en-PK');
}

//  dd-MMM-yyyy formatter, e.g. 07-Jun-2026
function fmtDateDMY(d) {
    if (!d) return '';
    var m = /\/Date\((\d+)\)\//.exec(d);
    var dt = m ? new Date(parseInt(m[1])) : new Date(d);
    if (isNaN(dt.getTime())) return '';
    var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    var dd = ('0' + dt.getDate()).slice(-2);
    return dd + '-' + months[dt.getMonth()] + '-' + dt.getFullYear();
}

//  Plain comma-separated number, no currency symbol, e.g. 1,250,000
function fmtMoney(n) {
    if (n == null || n === '') return '0';
    return parseFloat(n).toLocaleString('en-US', { maximumFractionDigits: 0 });
}

function fmtDateTime(d) {
    if (!d) return '';
    var m = /\/Date\((\d+)\)\//.exec(d);
    var dt = m ? new Date(parseInt(m[1])) : new Date(d);
    return dt.toLocaleDateString('en-PK') + ' ' + dt.toLocaleTimeString('en-PK', { hour: '2-digit', minute: '2-digit' });
}

function escHtml(s) {
    if (!s) return '';
    return $('<div>').text(s).html();
}

//  CNIC formatter (XXXXX-XXXXXXX-X) 
function formatCNIC(input) {
    var val = $(input).val().replace(/[^0-9]/g, '');
    var fmt = '';
    if (val.length > 0)  fmt  = val.substring(0,5);
    if (val.length > 5)  fmt += '-' + val.substring(5,12);
    if (val.length > 12) fmt += '-' + val.substring(12,13);
    $(input).val(fmt);
}

$(document).on('input', '.cnic-input', function () { formatCNIC(this); });

//  Phone formatter (0XXX-XXXXXXX) 
function formatPhone(input) {
    var val = $(input).val().replace(/[^0-9]/g, '');
    var fmt = '';
    if (val.length > 0) fmt  = val.substring(0,4);
    if (val.length > 4) fmt += '-' + val.substring(4,11);
    $(input).val(fmt);
}

$(document).on('input', '.phone-input', function () { formatPhone(this); });

//  Confirm modal helper 
/**
 * Show a Bootstrap modal confirm dialog.
 * @param {string}   title
 * @param {string}   message
 * @param {function} onConfirm  Called when user clicks Confirm
 * @param {string}   btnClass   'btn-danger' | 'btn-warning' etc.
 */
function qmConfirm(title, message, onConfirm, btnClass) {
    btnClass = btnClass || 'btn-danger';

    if (!$('#qmConfirmModal').length) {
        var modalHtml = '<div class="modal fade" id="qmConfirmModal" tabindex="-1">'
            + '<div class="modal-dialog"><div class="modal-content">'
            + '<div class="modal-header"><h5 class="modal-title" id="qmConfirmTitle"></h5>'
            + '<button type="button" class="btn-close" data-bs-dismiss="modal"></button></div>'
            + '<div class="modal-body" id="qmConfirmBody"></div>'
            + '<div class="modal-footer">'
            + '<button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>'
            + '<button type="button" class="btn ' + btnClass + '" id="qmConfirmBtn">Confirm</button>'
            + '</div></div></div></div>';
        $('body').append(modalHtml);
    }

    $('#qmConfirmTitle').text(title);
    $('#qmConfirmBody').text(message);
    $('#qmConfirmBtn').removeClass().addClass('btn ' + btnClass);

    var modal = new bootstrap.Modal(document.getElementById('qmConfirmModal'));
    modal.show();

    $('#qmConfirmBtn').off('click').on('click', function (e) {
        e.preventDefault();
        modal.hide();
        if (typeof onConfirm === 'function') onConfirm();
    });
}

//  Loading button state 
function btnLoading($btn, loadingText) {
    $btn.data('orig-text', $btn.html())
        .html('<span class="spinner-border spinner-border-sm me-1"></span>' + (loadingText || 'Loading...'))
        .prop('disabled', true);
}

function btnReset($btn) {
    $btn.html($btn.data('orig-text')).prop('disabled', false);
}

//  Searchable select (text input + datalist over a hidden <select>)
/**
 * Converts a <select> into a searchable text input backed by a <datalist>.
 * The original <select> stays in the DOM (hidden) and keeps its value in
 * sync, so existing code using $('#sel').val()/.trigger('change') keeps working.
 * Call again (or trigger 'qmRefresh' on the select) after repopulating options.
 */
function qmSearchableSelect(selectEl) {
    var $sel = $(selectEl);
    if (!$sel.length) return;

    function getOptions() {
        var opts = [];
        $sel.find('option').each(function () {
            opts.push({ val: $(this).val(), text: $(this).text() });
        });
        return opts;
    }

    function renderList(filter) {
        var $list = $sel.data('qmList');
        var opts = getOptions();
        filter = (filter || '').toLowerCase();
        var html = '';
        opts.forEach(function (o) {
            if (o.val === '' && filter) return;
            if (filter && o.text.toLowerCase().indexOf(filter) < 0) return;
            html += '<div class="qm-ss-item' + (o.val === $sel.val() ? ' active' : '') +
                    '" data-val="' + escHtml(o.val) + '">' + escHtml(o.text || ' ') + '</div>';
        });
        if (!html) html = '<div class="qm-ss-empty text-muted px-2 py-1 small">No matches</div>';
        $list.html(html);
    }

    function refresh() {
        var $input = $sel.data('qmInput');
        var $opt = $sel.find('option:selected');
        $input.val($opt.length ? $opt.text() : '');
        renderList('');
    }

    function openList() {
        var $list = $sel.data('qmList');
        renderList($sel.data('qmInput').val() === ($sel.find('option:selected').text() || '') ? '' : $sel.data('qmInput').val());
        $list.show();
    }

    function closeList() {
        $sel.data('qmList').hide();
    }

    if ($sel.data('qmSearchable')) { refresh(); return; }

    var cls = 'form-control' + ($sel.hasClass('form-select-sm') ? ' form-control-sm' : '');
    var $wrap = $('<div class="qm-ss-wrap"></div>');
    var $input = $('<input type="text" autocomplete="off">')
        .addClass(cls)
        .attr('placeholder', 'Type to search...');
    var $list = $('<div class="qm-ss-list"></div>');

    $wrap.append($input).append($list);
    $sel.hide().after($wrap);
    $sel.data('qmSearchable', true).data('qmInput', $input).data('qmList', $list);

    $input.on('focus click', function () {
        $(this).val('');
        renderList('');
        $list.show();
    });

    $input.on('input', function () {
        renderList($(this).val());
        $list.show();
    });

    $input.on('keydown', function (e) {
        var $items = $list.find('.qm-ss-item');
        var $cur = $list.find('.qm-ss-item.hover');
        if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
            e.preventDefault();
            if (!$list.is(':visible')) { openList(); return; }
            var idx = $items.index($cur);
            if (e.key === 'ArrowDown') idx = (idx + 1) % $items.length;
            else idx = (idx - 1 + $items.length) % $items.length;
            $items.removeClass('hover');
            $items.eq(idx).addClass('hover');
            var el = $items.eq(idx)[0];
            if (el) el.scrollIntoView({ block: 'nearest' });
        } else if (e.key === 'Enter') {
            e.preventDefault();
            var $pick = $cur.length ? $cur : $items.first();
            if ($pick.length) $pick.trigger('mousedown');
        } else if (e.key === 'Escape') {
            closeList();
        }
    });

    $list.on('mousedown', '.qm-ss-item', function (e) {
        e.preventDefault();
        var val = $(this).data('val');
        var text = $(this).text();
        $sel.val(val).trigger('change');
        $input.val(val === '' ? '' : text);
        closeList();
    });

    $(document).on('click', function (e) {
        if (!$wrap.is(e.target) && $wrap.has(e.target).length === 0) {
            closeList();
            var $opt = $sel.find('option:selected');
            $input.val($opt.length ? $opt.text() : '');
        }
    });

    $sel.on('change qmRefresh', refresh);
    refresh();
}

//  Auto-init searchable selects project-wide
//  Re-runs on every Turbo visit (native app): Turbo swaps the body, which
//  detaches both the observers and anything bound to replaced elements.
(function () {
    function initAll(root) {
        $(root).find('select').addBack('select').each(function () {
            var $sel = $(this);
            if ($sel.data('qmSearchable')) return;
            if ($sel.hasClass('qm-no-search')) return;
            if ($sel.is('[multiple]')) return;
            if ($sel.find('option').length <= 1) return;
            qmSearchableSelect($sel);
        });
    }

    function observeBody() {
        if (typeof MutationObserver === 'undefined') return;
        if (!document.body || document.body.dataset.qmObserver === '1') return;
        document.body.dataset.qmObserver = '1';

        var observer = new MutationObserver(function (mutations) {
            mutations.forEach(function (m) {
                // New <select> elements added
                m.addedNodes && m.addedNodes.forEach(function (n) {
                    if (n.nodeType === 1) initAll(n);
                });
                // Options repopulated inside an existing <select>
                if (m.target && m.target.tagName === 'SELECT') {
                    var $sel = $(m.target);
                    if ($sel.data('qmSearchable')) $sel.trigger('qmRefresh');
                    else initAll($sel);
                }
            });
        });
        observer.observe(document.body, { childList: true, subtree: true });
    }

    function boot() {
        initAll(document.body);
        observeBody();
    }

    $(document).ready(boot);
    document.addEventListener('turbo:load', boot);
})();

//  Sidebar behaviour (ported from the captured Site.master inline script) 
(function () {
    function isMobile() { return $(window).width() < 992; }

    function setCollapsed(collapsed) {
        $('#sidebar').toggleClass('collapsed', collapsed);
        $('#mainContent').toggleClass('expanded', collapsed);
        try { window.localStorage.setItem('qm.sidebar.collapsed', collapsed ? '1' : '0'); } catch (e) { }
    }

    function bind() {
        var $sidebar = $('#sidebar');
        var $main = $('#mainContent');
        var $overlay = $('#sidebarOverlay');
        if (!$sidebar.length) return;                 // native shell has no sidebar
        if (document.body.dataset.qmSidebarBound === '1') return;
        document.body.dataset.qmSidebarBound = '1';

        // Restore the desktop collapsed state from the previous visit
        try {
            if (!isMobile() && window.localStorage.getItem('qm.sidebar.collapsed') === '1') {
                $sidebar.addClass('collapsed');
                $main.addClass('expanded');
            }
        } catch (e) { }

        $('#sidebarToggleBtn').on('click', function () {
            if (isMobile()) {
                $sidebar.toggleClass('open');
                $overlay.toggleClass('visible');
            } else {
                setCollapsed(!$sidebar.hasClass('collapsed'));
            }
        });

        $overlay.on('click', function () {
            $sidebar.removeClass('open');
            $overlay.removeClass('visible');
        });

        // Close the drawer after navigating on small screens
        $('#sidebarNav').on('click', 'a', function () {
            if (isMobile()) {
                $sidebar.removeClass('open');
                $overlay.removeClass('visible');
            }
        });

        // Chevron rotation while a nav group expands/collapses
        $('#sidebarNav').on('show.bs.collapse', '.collapse', function () {
            $(this).prev('.nav-link-collapse').addClass('open');
        });
        $('#sidebarNav').on('hide.bs.collapse', '.collapse', function () {
            $(this).prev('.nav-link-collapse').removeClass('open');
        });
    }

    // Document-level bindings survive Turbo visits; bind them exactly once.
    $(document).ready(function () {
        if (window.__qmSidebarDocBound) return;
        window.__qmSidebarDocBound = true;

        // Escape closes the drawer
        $(document).on('keydown', function (e) {
            if (e.key === 'Escape') {
                $('#sidebar').removeClass('open');
                $('#sidebarOverlay').removeClass('visible');
            }
        });

        // Re-apply the drawer state when the viewport crosses the breakpoint
        $(window).on('resize', function () {
            if (!isMobile()) {
                $('#sidebar').removeClass('open');
                $('#sidebarOverlay').removeClass('visible');
            }
        });
    });

    $(document).ready(bind);
    document.addEventListener('turbo:load', bind);
})();

//  data-confirm support (the capture used rails-ujs; Turbo/rails-ujs are off) 
(function () {
    function messageFor($el) {
        return $el.attr('data-confirm')
            || $el.attr('data-turbo-confirm')
            || $el.attr('data-rails-confirm')
            || $el.attr('data-confirm-message')
            || 'Are you sure?';
    }

    var CONFIRMABLE = 'a[data-confirm], a[data-turbo-confirm], a[data-rails-confirm]';
    var CONFIRMABLE_FORM = 'form[data-confirm], form[data-turbo-confirm], form[data-rails-confirm]';
    var CONFIRMABLE_BTN = 'button[data-confirm], button[data-turbo-confirm], button[data-rails-confirm]';

    $(document).on('click', CONFIRMABLE, function (e) {
        e.preventDefault();
        var $link = $(this);
        var href = $link.attr('href');
        qmConfirm('Please confirm', messageFor($link), function () { window.location = href; }, 'btn-primary');
    });

    // button_to renders <form data-confirm>, so intercept the submit event
    $(document).on('submit', CONFIRMABLE_FORM, function (e) {
        var $form = $(this);
        if ($form.data('qmConfirmed')) return;

        e.preventDefault();
        qmConfirm('Please confirm', messageFor($form), function () {
            $form.data('qmConfirmed', true);
            $form.trigger('submit');
        });
    });

    $(document).on('click', CONFIRMABLE_BTN + ':not([data-bs-toggle])', function (e) {
        e.preventDefault();
        var $btn = $(this);
        if ($btn.data('qmConfirmed')) return;

        qmConfirm('Please confirm', messageFor($btn), function () {
            $btn.data('qmConfirmed', true);
            // Flag the enclosing form so its submit handler does not ask twice
            $btn.closest('form').data('qmConfirmed', true);
            $btn.trigger('click');
        });
    });
})();

//  DataTables defaults (if DataTables loaded) 
if (typeof $.fn.DataTable !== 'undefined') {
    $.extend(true, $.fn.DataTable.defaults, {
        pageLength: 25,
        language: {
            search:       'Search:',
            lengthMenu:   'Show _MENU_ entries',
            info:         'Showing _START_ to _END_ of _TOTAL_ entries',
            infoEmpty:    'No entries found',
            zeroRecords:  'No matching records found',
            paginate: { previous: '<i class="bi bi-chevron-left"></i>', next: '<i class="bi bi-chevron-right"></i>' }
        },
        dom: '<"row mb-2"<"col-sm-6"l><"col-sm-6"f>>rt<"row mt-2"<"col-sm-6"i><"col-sm-6"p>>',
        responsive: true
    });
}

/* ============================================================
   APPEARANCE SWITCHER  (colour scheme / accent / density)
   Persisted in localStorage and applied without a page reload.
   ============================================================ */
(function () {
    var root = document.documentElement;
    var STORE = { theme: 'qm.theme', accent: 'qm.accent', density: 'qm.density' };
    var DEFAULTS = { theme: 'light', accent: 'indigo', density: 'comfortable' };
    var media = window.matchMedia('(prefers-color-scheme: dark)');

    function read(key) {
        try { return localStorage.getItem(STORE[key]); } catch (e) { return null; }
    }

    function effectiveTheme(theme) {
        if (theme !== 'auto') return theme;
        return media.matches ? 'dark' : 'light';
    }

    function apply(theme, accent, density) {
        var t = effectiveTheme(theme);
        root.setAttribute('data-theme', t);
        root.setAttribute('data-bs-theme', t);   /* Bootstrap 5 components follow too */
        root.setAttribute('data-accent', accent);
        root.setAttribute('data-density', density);
        syncActive(theme, accent, density);
    }

    function store(key, value) {
        try { localStorage.setItem(STORE[key], value); } catch (e) {}
    }

    function syncActive(theme, accent, density) {
        document.querySelectorAll('[data-theme-set]').forEach(function (el) {
            el.classList.toggle('active', el.dataset.themeSet === theme);
        });
        document.querySelectorAll('[data-accent-set]').forEach(function (el) {
            el.classList.toggle('active', el.dataset.accentSet === accent);
        });
        document.querySelectorAll('[data-density-set]').forEach(function (el) {
            el.classList.toggle('active', el.dataset.densitySet === density);
        });
        var icon = document.getElementById('themeToggleIcon');
        if (icon) {
            var map = { light: 'bi-sun', dark: 'bi-moon-stars', auto: 'bi-circle-half' };
            icon.className = 'bi ' + map[theme];
        }
    }

    function current() {
        return {
            theme:    read('theme') || DEFAULTS.theme,
            accent:   read('accent') || DEFAULTS.accent,
            density:  read('density') || DEFAULTS.density
        };
    }

    document.addEventListener('click', function (e) {
        var t = e.target.closest('[data-theme-set]');
        if (t) { var v = t.dataset.themeSet; store('theme', v); apply(v, current().accent, current().density); return; }

        var a = e.target.closest('[data-accent-set]');
        if (a) { var av = a.dataset.accentSet; store('accent', av); apply(current().theme, av, current().density); return; }

        var d = e.target.closest('[data-density-set]');
        if (d) { var dv = d.dataset.densitySet; store('density', dv); apply(current().theme, current().accent, dv); return; }

        if (e.target.closest('#qmThemeReset')) {
            store('theme', DEFAULTS.theme);
            store('accent', DEFAULTS.accent);
            store('density', DEFAULTS.density);
            apply(DEFAULTS.theme, DEFAULTS.accent, DEFAULTS.density);
        }
    });

    /* Keep "Auto" in sync with the operating system. */
    if (media.addEventListener) {
        media.addEventListener('change', function () {
            if (current().theme === 'auto') apply('auto', current().accent, current().density);
        });
    }

    syncActive(current().theme, current().accent, current().density);
})();

/* Installable PWA: register the worker, which caches only fingerprinted
   /assets/ files (see app/views/pwa/service-worker.js). Registration failure -
   unsupported browser, or plain http away from localhost - must never affect
   the application, so it is swallowed. */
if ("serviceWorker" in navigator) {
    window.addEventListener("load", function () {
        navigator.serviceWorker.register("/service-worker").catch(function () { });
    });
}
