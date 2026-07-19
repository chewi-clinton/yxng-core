// Runs on every page. Looks for signals that this is a payment/subscription
// confirmation page, and — only if the user is logged in and hasn't already
// dismissed this site — offers a small in-page banner to save it.

const CONFIRMATION_PATTERN =
  /order confirmed|payment successful|payment received|subscription (confirmed|active|started)|you'?re subscribed|thank you for (your )?(purchase|order|subscribing)|receipt|next billing date|renews on|welcome to [a-z0-9 ]*(premium|pro|plus)/i;
const PRICE_PATTERN = /\$\s?(\d{1,4}(?:\.\d{2})?)/;

const MAX_SCANS_PER_PAGE = 6;
const SCAN_DEBOUNCE_MS = 1500;

let scanCount = 0;
let handledForThisUrl = false;
let lastUrl = location.href;
let debounceTimer = null;

function extractSignal() {
  if (!document.body) return null;
  const text = document.body.innerText.slice(0, 8000);
  const priceMatch = text.match(PRICE_PATTERN);
  const hasConfirmation = CONFIRMATION_PATTERN.test(text);
  if (priceMatch && hasConfirmation) {
    return { amount: priceMatch[1], name: guessName() };
  }
  return null;
}

function guessName() {
  const host = location.hostname.replace(/^www\./, '');
  const base = host.split('.')[0];
  return base.charAt(0).toUpperCase() + base.slice(1);
}

async function isLoggedIn() {
  const { authToken } = await chrome.storage.local.get(['authToken']);
  return !!authToken;
}

async function isDismissedForThisSite() {
  const { dismissedSites } = await chrome.storage.local.get(['dismissedSites']);
  return Array.isArray(dismissedSites) && dismissedSites.includes(location.hostname);
}

async function dismissForThisSite() {
  const { dismissedSites } = await chrome.storage.local.get(['dismissedSites']);
  const updated = Array.isArray(dismissedSites) ? dismissedSites : [];
  if (!updated.includes(location.hostname)) updated.push(location.hostname);
  await chrome.storage.local.set({ dismissedSites: updated });
}

async function savePayment(name, amount) {
  const { authToken, apiBaseUrl } = await chrome.storage.local.get([
    'authToken',
    'apiBaseUrl',
  ]);
  const base = (apiBaseUrl || 'https://yxngcore.zardocard.com').replace(/\/$/, '');
  const renewsOn = new Date();
  renewsOn.setDate(renewsOn.getDate() + 30);

  const res = await fetch(`${base}/api/v1/payments/`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Token ${authToken}`,
    },
    body: JSON.stringify({
      name,
      card_label: '',
      amount: parseFloat(amount).toFixed(2),
      renews_on: renewsOn.toISOString().split('T')[0],
      source: 'extension',
      source_url: location.href,
    }),
  });
  if (!res.ok) throw new Error('save failed');
}

function renderBanner(signal) {
  if (document.getElementById('__yxngcore_banner_host')) return;

  const host = document.createElement('div');
  host.id = '__yxngcore_banner_host';
  host.style.all = 'initial';
  document.documentElement.appendChild(host);
  const shadow = host.attachShadow({ mode: 'open' });

  shadow.innerHTML = `
    <style>
      .card {
        position: fixed; bottom: 20px; right: 20px; z-index: 2147483647;
        width: 280px; padding: 16px; border-radius: 18px;
        background: #1F1F27; border: 1px solid #4D4354;
        box-shadow: 0 8px 30px rgba(0,0,0,0.4);
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
        color: #E4E1EC; animation: slideIn 0.25s ease-out;
      }
      @keyframes slideIn { from { transform: translateY(12px); opacity: 0; } to { transform: translateY(0); opacity: 1; } }
      .title { font-weight: 800; font-size: 14px; margin-bottom: 4px; }
      .title .accent { color: #B76DFF; }
      .sub { font-size: 12px; color: #988D9F; margin-bottom: 12px; }
      .row { display: flex; gap: 8px; }
      button { border: none; border-radius: 999px; font-weight: 700; font-size: 12px; padding: 9px 0; flex: 1; cursor: pointer; }
      .save { background: #B76DFF; color: white; }
      .save:hover { background: #A257F0; }
      .dismiss { background: transparent; color: #988D9F; border: 1px solid #4D4354; }
      .never { display: block; text-align: center; margin-top: 8px; font-size: 11px; color: #988D9F; text-decoration: underline; cursor: pointer; }
      .status { font-size: 12px; text-align: center; padding: 4px 0; color: #B76DFF; }
    </style>
    <div class="card">
      <div class="title">Save to <span class="accent">Yxng Core</span>?</div>
      <div class="sub">Detected ${signal.name} — $${signal.amount}</div>
      <div class="row">
        <button class="save">Save</button>
        <button class="dismiss">Not now</button>
      </div>
      <div class="never">Don't ask on this site</div>
    </div>
  `;

  shadow.querySelector('.save').addEventListener('click', async () => {
    const card = shadow.querySelector('.card');
    try {
      await savePayment(signal.name, signal.amount);
      card.innerHTML = '<div class="status">Saved ✓</div>';
      setTimeout(() => host.remove(), 1200);
    } catch (_) {
      card.innerHTML =
        '<div class="status" style="color:#FFB4AB">Could not save — open the extension to try again.</div>';
      setTimeout(() => host.remove(), 2200);
    }
  });

  shadow.querySelector('.dismiss').addEventListener('click', () => host.remove());

  shadow.querySelector('.never').addEventListener('click', async () => {
    await dismissForThisSite();
    host.remove();
  });
}

async function scan() {
  if (handledForThisUrl || scanCount >= MAX_SCANS_PER_PAGE) return;
  scanCount += 1;

  const [loggedIn, dismissed] = await Promise.all([
    isLoggedIn(),
    isDismissedForThisSite(),
  ]);
  if (!loggedIn || dismissed) return;

  const signal = extractSignal();
  if (signal) {
    handledForThisUrl = true;
    renderBanner(signal);
  }
}

function scheduleScan() {
  clearTimeout(debounceTimer);
  debounceTimer = setTimeout(scan, SCAN_DEBOUNCE_MS);
}

// Initial scan once the page has settled.
setTimeout(scan, 800);

// Re-scan on DOM changes (SPA checkout flows render confirmations client-side).
const observer = new MutationObserver(scheduleScan);
if (document.body) {
  observer.observe(document.body, { childList: true, subtree: true });
}

// SPA route changes don't reload the content script — detect URL changes by
// polling, and reset per-page state so a new "page" can trigger the banner.
setInterval(() => {
  if (location.href !== lastUrl) {
    lastUrl = location.href;
    handledForThisUrl = false;
    scanCount = 0;
    scheduleScan();
  }
}, 1000);
