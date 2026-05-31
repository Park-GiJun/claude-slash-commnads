// AGENT PITCH 대시보드 — 의존성 0개 정적 서버 + 히스토리 적립기
// 사용법: node server.js  (기본 포트 5173, PORT 환경변수로 변경)
//
// status.json 을 감시하다가 팀이 "전원 done" 으로 바뀌는 순간을 history.json 에
// append 한다. (런마다 .team-runs 가 덮어써져 기록이 사라지므로 서버가 보존한다.)
const http = require("http");
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "public");
const STATUS_FILE = path.join(ROOT, "status.json");
const HISTORY_FILE = path.join(ROOT, "history.json");
const PORT = process.env.PORT || 5173;
const HISTORY_CAP = 300;

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".png": "image/png",
  ".woff2": "font/woff2",
  ".ttf": "font/ttf",
};

// ---- 히스토리 적립 -------------------------------------------------------
const prevAllDone = {}; // slug -> 직전에 전원 완료였는가

function readJson(file, fallback) {
  try { return JSON.parse(fs.readFileSync(file, "utf8")); }
  catch { return fallback; }
}

function recordHistory() {
  const doc = readJson(STATUS_FILE, null);
  if (!doc || !Array.isArray(doc.teams)) return;
  let hist = readJson(HISTORY_FILE, []);
  if (!Array.isArray(hist)) hist = [];
  let changed = false;

  for (const t of doc.teams) {
    const agents = t.agents || [];
    const allDone = agents.length > 0 && agents.every(a => a.status === "done");
    // "전원 완료" 로 새로 전이한 순간에만 1건 기록
    if (allDone && !prevAllDone[t.slug]) {
      hist.push({
        ts: doc.generatedAt || "",
        slug: t.slug,
        title: t.title,
        stack: t.stack || "",
        totalLines: agents.reduce((s, a) => s + (a.lines || 0), 0),
        agents: agents.map(a => ({
          name: a.display, role: a.role, model: a.model,
          lines: a.lines || 0, lastLine: a.lastLine || "",
        })),
      });
      changed = true;
    }
    prevAllDone[t.slug] = allDone;
  }

  if (changed) {
    if (hist.length > HISTORY_CAP) hist = hist.slice(-HISTORY_CAP);
    try { fs.writeFileSync(HISTORY_FILE, JSON.stringify(hist, null, 2)); }
    catch (e) { console.error("history 쓰기 실패:", e.message); }
  }
}

function initHistory() {
  if (!fs.existsSync(HISTORY_FILE)) {
    try { fs.writeFileSync(HISTORY_FILE, "[]"); } catch {}
  }
  // 시작 시점에 이미 완료된 팀을 "신규 완료" 로 오인하지 않도록 기준선 설정
  const doc = readJson(STATUS_FILE, null);
  if (doc && Array.isArray(doc.teams)) {
    for (const t of doc.teams) {
      const agents = t.agents || [];
      prevAllDone[t.slug] = agents.length > 0 && agents.every(a => a.status === "done");
    }
  }
}

// status.json 변화 감시 (Windows 친화적 폴링)
function watchStatus() {
  fs.watchFile(STATUS_FILE, { interval: 1000 }, () => recordHistory());
}

// ---- 정적 서버 ----------------------------------------------------------
const server = http.createServer((req, res) => {
  let urlPath = decodeURIComponent(req.url.split("?")[0]);
  if (urlPath === "/") urlPath = "/index.html";

  const filePath = path.normalize(path.join(ROOT, urlPath));
  if (!filePath.startsWith(ROOT)) {
    res.writeHead(403).end("Forbidden");
    return;
  }

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
      res.end("Not Found: " + urlPath);
      return;
    }
    const ext = path.extname(filePath).toLowerCase();
    res.writeHead(200, {
      "Content-Type": MIME[ext] || "application/octet-stream",
      "Cache-Control": "no-store",
    });
    res.end(data);
  });
});

initHistory();
watchStatus();
server.listen(PORT, () => {
  console.log(`AGENT PITCH → http://localhost:${PORT}`);
});
