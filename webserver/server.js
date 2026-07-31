const express = require("express");

const app = express();
const PORT = 8080;

app.use(express.json({ limit: "1mb" }));

let latestData = {
    title: "",
    refreshSeconds: 0,
    timestamp: 0,
    items: [],
};

app.post("/update", (req, res) => {
    latestData = req.body;

    console.log(
        `[${new Date().toLocaleTimeString()}] Received ${latestData.items?.length ?? 0} items`
    );

    res.sendStatus(200);
});

app.get("/data", (req, res) => {
    res.json(latestData);
});

app.get("/", (req, res) => {
    const rows = (latestData.items || [])
        .map(item => `
<tr>
    <td>${item.name}</td>
    <td style="text-align:right">${item.count.toLocaleString()}</td>
    <td style="text-align:right;color:${item.rate >= 0 ? "#00aa00" : "#cc3300"}">
        ${item.rate >= 0 ? "+" : ""}${item.rate.toFixed(1)}/s
    </td>
</tr>`)
        .join("");

    res.send(`<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>${latestData.title || "Bulk Cell Rate Monitor"}</title>
<style>
body{
    font-family:Arial,sans-serif;
    background:#181818;
    color:#eee;
    margin:40px;
}
table{
    width:100%;
    border-collapse:collapse;
}
th,td{
    padding:8px 12px;
    border-bottom:1px solid #333;
}
th{
    text-align:left;
}
h1{
    margin-bottom:4px;
}
small{
    color:#888;
}
</style>
</head>
<body>
<h1>${latestData.title || "Bulk Cell Rate Monitor"}</h1>
<small>
Updated:
${latestData.timestamp
    ? new Date(latestData.timestamp).toLocaleString()
    : "Never"}
</small>

<table>
<thead>
<tr>
<th>Item</th>
<th style="text-align:right">Count</th>
<th style="text-align:right">Rate</th>
</tr>
</thead>
<tbody>
${rows}
</tbody>
</table>

<script>
setTimeout(() => location.reload(), 1000);
</script>
</body>
</html>`);
});

app.listen(PORT, () => {
    console.log(`Server listening on http://localhost:${PORT}`);
});