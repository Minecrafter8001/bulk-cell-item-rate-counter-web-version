const express = require("express");
const path = require("path");

const app = express();
const PORT = 8080;

app.use(express.json({ limit: "1mb" }));

let latestData = {
    title: "",
    refreshSeconds: 0,
    timestamp: 0,
    items: [],
};

app.use(express.static(path.join(__dirname, "public")));

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

app.listen(PORT, () => {
    console.log(`Server listening on http://localhost:${PORT}`);
});