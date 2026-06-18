// hyprwayspaces tab saver — background page
//
// Marks Firefox windows with a "project" name via sessions.setWindowValue,
// then dumps their tabs to the native messaging host whenever they change.

const NATIVE_HOST = "hyprwayspaces";
const KEY = "hwsp-project";
const DEBOUNCE_MS = 1500;

async function getProject(windowId) {
    try {
        return await browser.sessions.getWindowValue(windowId, KEY);
    } catch {
        return null;
    }
}

async function setProject(windowId, name) {
    await browser.sessions.setWindowValue(windowId, KEY, name);
}

async function clearProject(windowId) {
    try {
        await browser.sessions.removeWindowValue(windowId, KEY);
    } catch {}
}

async function dumpWindow(windowId) {
    const project = await getProject(windowId);
    if (!project) return;
    let win;
    try {
        win = await browser.windows.get(windowId, { populate: true });
    } catch {
        return; // window may be gone
    }
    const payload = {
        project,
        savedAt: new Date().toISOString(),
        windowId: win.id,
        focused: win.focused,
        tabs: (win.tabs || []).map(t => ({
            url: t.url,
            title: t.title,
            pinned: t.pinned,
            active: t.active
        }))
    };
    try {
        await browser.runtime.sendNativeMessage(NATIVE_HOST, payload);
    } catch (e) {
        console.warn("hyprwayspaces native messaging failed:", e);
    }
}

// Debounce per window so rapid-fire tab events coalesce into one write.
const timers = new Map();
function scheduleDump(windowId) {
    if (!windowId || windowId < 0) return;
    clearTimeout(timers.get(windowId));
    timers.set(windowId, setTimeout(() => {
        timers.delete(windowId);
        dumpWindow(windowId);
    }, DEBOUNCE_MS));
}

browser.tabs.onCreated.addListener(t => scheduleDump(t.windowId));
browser.tabs.onUpdated.addListener((id, change, t) => {
    if (change.url || change.title || change.pinned !== undefined || change.status === "complete") {
        scheduleDump(t.windowId);
    }
});
browser.tabs.onMoved.addListener((id, info) => scheduleDump(info.windowId));
browser.tabs.onRemoved.addListener((id, info) => {
    if (!info.isWindowClosing) scheduleDump(info.windowId);
});
browser.tabs.onAttached.addListener((id, info) => scheduleDump(info.newWindowId));

// Update toolbar badge to reflect a window's project mark.
async function refreshBadge(windowId) {
    const project = await getProject(windowId);
    const text = project ? project.slice(0, 4) : "";
    browser.browserAction.setBadgeText({ text, windowId });
    if (project) {
        browser.browserAction.setBadgeBackgroundColor({ color: "#4a7bff", windowId });
    }
}

// Restore badges + state for marked windows when the browser starts.
browser.runtime.onStartup.addListener(restoreAll);
restoreAll();

async function restoreAll() {
    const windows = await browser.windows.getAll();
    for (const w of windows) {
        await refreshBadge(w.id);
    }
}

// Popup talks to us via messages.
browser.runtime.onMessage.addListener(async (msg, sender) => {
    if (!msg || !msg.cmd) return;
    const windowId = msg.windowId ?? sender.tab?.windowId;
    if (!windowId) return;
    switch (msg.cmd) {
        case "get":
            return { project: await getProject(windowId) };
        case "set":
            await setProject(windowId, msg.name);
            await refreshBadge(windowId);
            await dumpWindow(windowId);
            return { ok: true };
        case "clear":
            await clearProject(windowId);
            await refreshBadge(windowId);
            return { ok: true };
        case "dump":
            await dumpWindow(windowId);
            return { ok: true };
    }
});
