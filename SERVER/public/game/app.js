const RULES_VERSION = "network-1";
const TOKEN_KEY = "big-hero.session-token";
const ACCOUNT_KEY = "big-hero.account";
const state = { token: sessionStorage.getItem(TOKEN_KEY), account: readJson(ACCOUNT_KEY), character: null, socket: null, heartbeat: null, reconnectTimer: null, reconnectStartedAt: 0, messages: [], registerMode: false };

const $ = (id) => document.getElementById(id);
const show = (id) => { $(id).hidden = false; };
const hide = (id) => { $(id).hidden = true; };
function readJson(key) { try { return JSON.parse(sessionStorage.getItem(key) || "null"); } catch { return null; } }
function requestId(prefix) {
  const random = Math.random().toString(36).slice(2) + Math.random().toString(36).slice(2);
  return `${prefix}_${Date.now().toString(36)}_${random}`.slice(0, 64);
}
function setError(id, message = "") { $(id).textContent = message; }
function errorText(error) { return error?.message || "网络暂时不可用，请稍后重试"; }

async function api(path, options = {}) {
  const headers = { "content-type": "application/json", ...(options.headers || {}) };
  if (state.token) headers.authorization = `Bearer ${state.token}`;
  const response = await fetch(path, { ...options, headers });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok || payload.ok === false) throw Object.assign(new Error(payload.error?.message || "请求失败"), { code: payload.error?.code, status: response.status });
  return payload;
}

function setAuthMode(register) {
  state.registerMode = register;
  $("auth-title").textContent = register ? "申请账号" : "进入冒险";
  $("auth-subtitle").textContent = register ? "使用管理员发放的邀请码创建账号。" : "与伙伴一起踏上新的地图。";
  $("auth-submit").textContent = register ? "创建账号" : "登录";
  $("auth-switch").textContent = register ? "返回登录" : "使用邀请码注册";
  $("register-fields").hidden = !register;
  $("password-confirm").required = register;
  $("invite-code").required = register;
  setError("auth-error");
}

function updatePlayer() {
  const character = state.character;
  if (!character) return;
  $("player-name").textContent = character.name;
  $("map-player-name").textContent = character.name;
  $("player-meta").textContent = `Lv.${character.level} · ${character.experience} EXP · ${character.gold} 金币`;
}

function showLoggedIn() {
  hide("auth-view"); hide("character-view"); show("game-view"); updatePlayer(); connectSocket(); refreshOnlineCount();
}
function showCharacterCreation() { hide("auth-view"); hide("game-view"); show("character-view"); $("character-name").focus(); }
function showLogin() { hide("game-view"); hide("character-view"); show("auth-view"); $("username").focus(); }

async function login() {
  const payload = { rules_version: RULES_VERSION, username: $("username").value, password: $("password").value };
  const result = await api("/api/v1/auth/login", { method: "POST", body: JSON.stringify(payload) });
  state.token = result.session.token; state.account = result.account; state.character = result.character;
  sessionStorage.setItem(TOKEN_KEY, state.token); sessionStorage.setItem(ACCOUNT_KEY, JSON.stringify(state.account));
  $("password").value = "";
  if (state.character) showLoggedIn(); else showCharacterCreation();
}

async function register() {
  const payload = { rules_version: RULES_VERSION, request_id: requestId("register"), username: $("username").value, password: $("password").value, password_confirm: $("password-confirm").value, invite_code: $("invite-code").value };
  await api("/api/v1/auth/register", { method: "POST", body: JSON.stringify(payload) });
  setAuthMode(false); $("username").value = payload.username; $("password").value = ""; setError("auth-error", "账号创建成功，请登录。");
}

async function createCharacter(event) {
  event.preventDefault(); setError("character-error");
  try {
    const result = await api("/api/v1/characters", { method: "POST", body: JSON.stringify({ rules_version: RULES_VERSION, request_id: requestId("character"), name: $("character-name").value }) });
    state.character = result.character; showLoggedIn();
  } catch (error) { setError("character-error", errorText(error)); }
}

function setConnection(online, label = online ? "已连接" : "连接中") { $("connection-dot").classList.toggle("online", online); $("connection-label").textContent = label; }
function connectSocket() {
  if (!state.token || state.socket?.readyState === WebSocket.OPEN || state.socket?.readyState === WebSocket.CONNECTING) return;
  const protocol = location.protocol === "https:" ? "wss:" : "ws:";
  const socket = new WebSocket(`${protocol}//${location.host}/ws`); state.socket = socket; setConnection(false, "连接中");
  socket.addEventListener("open", () => { state.reconnectStartedAt = 0; setConnection(true); socket.send(JSON.stringify({ type: "authenticate", token: state.token })); state.heartbeat = window.setInterval(() => { if (socket.readyState === WebSocket.OPEN) socket.send(JSON.stringify({ type: "heartbeat" })); }, 10000); });
  socket.addEventListener("message", (event) => handleSocketMessage(JSON.parse(event.data)));
  socket.addEventListener("close", (event) => { window.clearInterval(state.heartbeat); state.heartbeat = null; state.socket = null; if (event.code === 4001 || event.code === 4003) { clearSession(); return; } setConnection(false, "重连中"); scheduleReconnect(); });
  socket.addEventListener("error", () => setConnection(false, "连接异常"));
}
function scheduleReconnect() { if (state.reconnectTimer || !state.token) return; if (!state.reconnectStartedAt) state.reconnectStartedAt = Date.now(); if (Date.now() - state.reconnectStartedAt > 30000) { clearSession(); return; } state.reconnectTimer = window.setTimeout(() => { state.reconnectTimer = null; connectSocket(); }, 2000); }
function handleSocketMessage(packet) {
  if (packet.type === "authenticated") { setConnection(true); return; }
  if (packet.type === "chat_history") { state.messages = Array.isArray(packet.messages) ? packet.messages : []; renderMessages(); return; }
  if (packet.type === "chat_message" && packet.message) { if (!state.messages.some((item) => item.id === packet.message.id)) state.messages.push(packet.message); state.messages = state.messages.slice(-100); renderMessages(); return; }
  if (packet.type === "error") { if (packet.code === "SESSION_INVALID" || packet.code === "KICKED" || packet.code === "REPLACED_BY_NEW_LOGIN") clearSession(); else setError("chat-error", packet.message); }
}
function renderMessages() {
  const container = $("chat-messages"); container.replaceChildren();
  for (const message of state.messages) {
    const item = document.createElement("article"); item.className = "chat-message";
    const header = document.createElement("header"); const name = document.createElement("strong"); name.textContent = message.senderName || "系统"; const time = document.createElement("time"); time.textContent = new Date(message.createdAt).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }); header.append(name, time);
    const body = document.createElement("p"); body.textContent = message.body; item.append(header, body); container.append(item);
  }
  container.scrollTop = container.scrollHeight; $("chat-count").textContent = String(state.messages.length);
}
function sendChat(event) { event.preventDefault(); const input = $("chat-input"); const body = input.value.trim(); if (!body || state.socket?.readyState !== WebSocket.OPEN) return; setError("chat-error"); state.socket.send(JSON.stringify({ type: "chat_send", body, client_message_id: requestId("chat") })); input.value = ""; }
async function refreshOnlineCount() { try { const result = await fetch("/healthz"); const data = await result.json(); $("online-count").textContent = data.online_players ?? "-"; } catch { $("online-count").textContent = "-"; } }
async function logout() { try { if (state.token) await api("/api/v1/auth/logout", { method: "POST" }); } catch { /* local logout still clears the session */ } clearSession(); }
function clearSession() { if (state.socket) state.socket.close(); window.clearTimeout(state.reconnectTimer); window.clearInterval(state.heartbeat); state.token = null; state.account = null; state.character = null; sessionStorage.removeItem(TOKEN_KEY); sessionStorage.removeItem(ACCOUNT_KEY); showLogin(); }

$("auth-switch").addEventListener("click", () => setAuthMode(!state.registerMode));
$("auth-form").addEventListener("submit", async (event) => { event.preventDefault(); setError("auth-error"); const button = $("auth-submit"); button.disabled = true; try { if (state.registerMode) await register(); else await login(); } catch (error) { setError("auth-error", errorText(error)); } finally { button.disabled = false; } });
$("character-form").addEventListener("submit", createCharacter);
$("chat-form").addEventListener("submit", sendChat);
$("logout-button").addEventListener("click", logout);
document.querySelectorAll(".nav-item").forEach((button) => button.addEventListener("click", () => { document.querySelectorAll(".nav-item").forEach((item) => item.classList.toggle("active", item === button)); document.querySelectorAll(".tab-panel").forEach((panel) => { panel.hidden = panel.id !== `${button.dataset.tab}-panel`; }); }));

async function restoreSession() { if (!state.token) return; try { const result = await api("/api/v1/characters/me"); state.character = result.character; if (state.character) showLoggedIn(); else showCharacterCreation(); } catch { clearSession(); } }
setAuthMode(false); restoreSession();
