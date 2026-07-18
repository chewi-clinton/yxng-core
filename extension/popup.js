const loginView = document.getElementById('loginView');
const captureView = document.getElementById('captureView');

function guessNameFromUrl(url) {
  try {
    const host = new URL(url).hostname.replace(/^www\./, '');
    const base = host.split('.')[0];
    return base.charAt(0).toUpperCase() + base.slice(1);
  } catch (_) {
    return '';
  }
}

function defaultRenewalDate() {
  const d = new Date();
  d.setDate(d.getDate() + 30);
  return d.toISOString().split('T')[0];
}

async function getStored(keys) {
  return chrome.storage.local.get(keys);
}

async function setStored(obj) {
  return chrome.storage.local.set(obj);
}

async function initView() {
  const { authToken, apiBaseUrl } = await getStored(['authToken', 'apiBaseUrl']);
  if (authToken) {
    loginView.classList.add('hidden');
    captureView.classList.remove('hidden');
    await prefillCapture();
  } else {
    loginView.classList.remove('hidden');
    captureView.classList.add('hidden');
    if (apiBaseUrl) document.getElementById('apiBaseUrl').value = apiBaseUrl;
  }
}

async function prefillCapture() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (tab && tab.url) {
    document.getElementById('pageUrl').textContent = tab.url;
    document.getElementById('name').value = guessNameFromUrl(tab.url);
  }
  document.getElementById('renewsOn').value = defaultRenewalDate();
}

document.getElementById('loginBtn').addEventListener('click', async () => {
  const apiBaseUrl = document.getElementById('apiBaseUrl').value.trim().replace(/\/$/, '');
  const username = document.getElementById('username').value.trim();
  const password = document.getElementById('password').value;
  const errorEl = document.getElementById('loginError');
  errorEl.style.display = 'none';

  if (!username || !password) {
    errorEl.textContent = 'Enter your username and password.';
    errorEl.style.display = 'block';
    return;
  }

  try {
    const res = await fetch(`${apiBaseUrl}/api/v1/auth/login/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password }),
    });
    if (!res.ok) throw new Error('Invalid username or password.');
    const data = await res.json();
    await setStored({ authToken: data.token, apiBaseUrl });
    await initView();
  } catch (e) {
    errorEl.textContent = e.message || 'Could not reach the server.';
    errorEl.style.display = 'block';
  }
});

document.getElementById('logoutLink').addEventListener('click', async () => {
  await chrome.storage.local.remove(['authToken']);
  await initView();
});

document.getElementById('scanBtn').addEventListener('click', async () => {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab || !tab.id) return;
  try {
    const [{ result }] = await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: () => {
        const text = document.body ? document.body.innerText : '';
        const match = text.match(/\$\s?(\d{1,4}(?:\.\d{2})?)/);
        return match ? match[1] : null;
      },
    });
    if (result) {
      document.getElementById('amount').value = result;
    } else {
      const errorEl = document.getElementById('saveError');
      errorEl.textContent = "Couldn't find a price on this page — enter it manually.";
      errorEl.style.display = 'block';
    }
  } catch (_) {
    const errorEl = document.getElementById('saveError');
    errorEl.textContent = "Can't scan this page (restricted by the browser).";
    errorEl.style.display = 'block';
  }
});

document.getElementById('saveBtn').addEventListener('click', async () => {
  const errorEl = document.getElementById('saveError');
  const successEl = document.getElementById('saveSuccess');
  errorEl.style.display = 'none';
  successEl.style.display = 'none';

  const name = document.getElementById('name').value.trim();
  const cardLabel = document.getElementById('cardLabel').value.trim();
  const amount = parseFloat(document.getElementById('amount').value);
  const renewsOn = document.getElementById('renewsOn').value;

  if (!name || !renewsOn || isNaN(amount)) {
    errorEl.textContent = 'Fill in the service name, amount, and renewal date.';
    errorEl.style.display = 'block';
    return;
  }

  const { authToken, apiBaseUrl } = await getStored(['authToken', 'apiBaseUrl']);
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

  try {
    const res = await fetch(`${apiBaseUrl}/api/v1/payments/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Token ${authToken}`,
      },
      body: JSON.stringify({
        name,
        card_label: cardLabel,
        amount: amount.toFixed(2),
        renews_on: renewsOn,
        source: 'extension',
        source_url: tab ? tab.url : '',
      }),
    });

    if (res.status === 401) {
      await chrome.storage.local.remove(['authToken']);
      await initView();
      return;
    }
    if (!res.ok) throw new Error('Could not save — check the fields and try again.');

    successEl.style.display = 'block';
    setTimeout(() => window.close(), 900);
  } catch (e) {
    errorEl.textContent = e.message || 'Could not reach the server.';
    errorEl.style.display = 'block';
  }
});

initView();
