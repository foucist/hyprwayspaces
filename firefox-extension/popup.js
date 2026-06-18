async function currentWindowId() {
    const w = await browser.windows.getCurrent();
    return w.id;
}

function setStatus(text, isError) {
    const el = document.getElementById("status");
    el.textContent = text;
    el.style.color = isError ? "#c33" : "#555";
}

async function refresh() {
    const windowId = await currentWindowId();
    const { project } = await browser.runtime.sendMessage({ cmd: "get", windowId });
    const stateEl = document.getElementById("state");
    if (project) {
        stateEl.textContent = `marked as: ${project}`;
        stateEl.className = "marked";
        document.getElementById("name").value = project;
    } else {
        stateEl.textContent = "unmarked";
        stateEl.className = "unmarked";
    }
}

document.getElementById("save").addEventListener("click", async () => {
    const name = document.getElementById("name").value.trim();
    if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/.test(name)) {
        setStatus("name must be alphanumeric (._- allowed)", true);
        return;
    }
    const windowId = await currentWindowId();
    await browser.runtime.sendMessage({ cmd: "set", windowId, name });
    setStatus(`marked as ${name}; dumped`);
    await refresh();
});

document.getElementById("dump").addEventListener("click", async () => {
    const windowId = await currentWindowId();
    await browser.runtime.sendMessage({ cmd: "dump", windowId });
    setStatus("dumped");
});

document.getElementById("unmark").addEventListener("click", async () => {
    const windowId = await currentWindowId();
    await browser.runtime.sendMessage({ cmd: "clear", windowId });
    setStatus("unmarked");
    await refresh();
});

document.getElementById("name").addEventListener("keydown", (e) => {
    if (e.key === "Enter") document.getElementById("save").click();
});

refresh();
