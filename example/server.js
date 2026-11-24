// A tiny app to try the stack with: no dependencies, logs one JSON line per request.
const http = require("node:http");

const port = Number(process.env.PORT || 3000);

http
  .createServer((req, res) => {
    const started = Date.now();
    const status = req.url === "/boom" ? 500 : 200;
    res.writeHead(status, { "content-type": "application/json" });
    res.end(JSON.stringify({ ok: status === 200, path: req.url }));
    const line = { level: status === 500 ? "error" : "info", method: req.method, path: req.url, status, ms: Date.now() - started };
    console.log(JSON.stringify(line));
  })
  .listen(port, () => console.log(JSON.stringify({ level: "info", msg: `listening on ${port}` })));
