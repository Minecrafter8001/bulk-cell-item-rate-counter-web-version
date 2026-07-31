async function refresh() {
    try {
        const response = await fetch("/data");
        const data = await response.json();

        document.getElementById("title").textContent =
            data.title || "Bulk Cell Rate Monitor";

        document.getElementById("updated").textContent =
            data.timestamp
                ? `Updated: ${new Date(data.timestamp).toLocaleString()}`
                : "Waiting for data...";

        const tbody = document.getElementById("rows");
        tbody.innerHTML = "";

        for (const item of data.items) {
            const tr = document.createElement("tr");

            tr.innerHTML = `
                <td>${item.name}</td>
                <td class="right">${Number(item.count).toLocaleString()}</td>
                <td class="right ${item.rate >= 0 ? "positive" : "negative"}">
                    ${item.rate >= 0 ? "+" : ""}${Number(item.rate).toFixed(1)}/s
                </td>
            `;

            tbody.appendChild(tr);
        }
    } catch (err) {
        console.error(err);
    }
}

refresh();
setInterval(refresh, 1000);