const API_BASE = "https://forward-gilly-webguardian-1b994c6d.koyeb.app"

// runs every 60 seconds via alarms API (more reliable than setInterval)
chrome.alarms.create("deduct", { periodInMinutes: 1 })

chrome.alarms.onAlarm.addListener(async (alarm) => {
    if (alarm.name !== "deduct") return

    // only deduct if youtube tab is active
    const tabs = await chrome.tabs.query({ active: true, currentWindow: true })
    const activeTab = tabs[0]

    if (!activeTab?.url?.includes("youtube.com")) {
        console.log("Waqt: YouTube not active, skipping deduct")
        return
    }

    try {
        const res = await fetch(`${API_BASE}/time/deduct`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ seconds: 60 })
        })
        const data = await res.json()
        console.log("Waqt: deducted, remaining:", data.remaining)

        // store remaining so content.js can read it
        chrome.storage.local.set({ remaining: data.remaining, blocked: data.blocked })

        // tell content.js to block if time is up
        if (data.blocked) {
            chrome.tabs.sendMessage(activeTab.id, { action: "block" })
        }
    } catch (err) {
        console.error("Waqt: deduct failed", err)
    }
})

// check remaining on startup
async function checkOnStartup() {
    try {
        const res = await fetch(`${API_BASE}/time/remaining`)
        const data = await res.json()
        chrome.storage.local.set({ remaining: data.remaining, blocked: data.remaining <= 0 })
    } catch (err) {
        console.error("Waqt: startup check failed", err)
    }
}

checkOnStartup()
