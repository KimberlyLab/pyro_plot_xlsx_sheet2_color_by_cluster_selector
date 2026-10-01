// Works both inside htmlwidgets::onRender() and pasted into DevTools.
(function () {
    const plot = typeof el !== "undefined" ? el : document.querySelector(".plotly");
    if (!plot || typeof plot.on !== "function") {
        throw new Error("No rendered Plotly plot found.");
    }

    // Re-running this script replaces its handler instead of adding downloads.
    if (plot._saveSelectedIdsHandler) {
        plot.removeListener("plotly_selected", plot._saveSelectedIdsHandler);
    }
    plot._saveSelectedIdsHandler = function (eventData) {
        if (!eventData || !eventData.points || !eventData.points.length) return;

        const ids = eventData.points.map(function (point) {
            const trace = point.data || plot.data[point.curveNumber];
            return trace.key[point.pointNumber];
        });
        if (ids.some(id => id === undefined || id === null || id === "")) {
            console.error("Selection contains missing sample IDs; download cancelled.");
            return;
        }

        const selected = eventData.points.map(function (point) {
            const trace = point.data || plot.data[point.curveNumber];
            const i = point.pointNumber;
            return {a: trace.x[i], b: trace.y[i], c: trace.customdata[i], cnr: trace.name};
        });
        // Missing numeric values are excluded from that column's mean.
        // If no finite values remain, use NA rather than treating missing as zero.
        const mean = field => {
            const values = selected.map(p => p[field]).filter(v =>
                typeof v === "number" && Number.isFinite(v));
            return values.length
                ? Math.round(values.reduce((sum, v) => sum + v, 0) / values.length).toString()
                : "NA";
        };
        const counts = new Map();
        selected.forEach(p => counts.set(p.cnr, (counts.get(p.cnr) || 0) + 1));
        // Sort labels first so ties consistently choose the alphabetically first.
        const mode = [...counts.keys()].sort().reduce((best, label) =>
            best === undefined || counts.get(label) > counts.get(best) ? label : best,
            undefined);
        const safeCnr = String(mode).replace(/[<>:"/\\|?*\x00-\x1f]/g, "_");
        const filename = `selected_2a${mean("a")}_2b${mean("b")}_3a${mean("c")}_CNR${safeCnr}_N${selected.length}.txt`;

        const blob = new Blob([ids.join("\n") + "\n"], {type: "text/plain"});
        const url = URL.createObjectURL(blob);
        const link = document.createElement("a");
        link.href = url;
        link.download = filename;
        document.body.appendChild(link);
        link.click();
        link.remove();
        setTimeout(() => URL.revokeObjectURL(url), 1000);
        console.log("Selected sample IDs:", ids);
    };
    plot.on("plotly_selected", plot._saveSelectedIdsHandler);
})();
