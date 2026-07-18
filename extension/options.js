const input = document.getElementById('apiBaseUrl');
const saved = document.getElementById('saved');

chrome.storage.local.get(['apiBaseUrl']).then(({ apiBaseUrl }) => {
  input.value = apiBaseUrl || 'http://localhost:8000';
});

document.getElementById('saveBtn').addEventListener('click', async () => {
  const apiBaseUrl = input.value.trim().replace(/\/$/, '');
  await chrome.storage.local.set({ apiBaseUrl });
  saved.style.display = 'block';
  setTimeout(() => (saved.style.display = 'none'), 1500);
});

document.getElementById('logoutBtn').addEventListener('click', async () => {
  await chrome.storage.local.remove(['authToken']);
  saved.textContent = 'Logged out ✓';
  saved.style.display = 'block';
  setTimeout(() => (saved.style.display = 'none'), 1500);
});
