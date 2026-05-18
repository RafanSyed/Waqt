const API_BASE = "https://forward-gilly-webguardian-1b994c6d.koyeb.app"

function log(msg) {
    const el = document.getElementById("log")
    const time = new Date().toLocaleTimeString()
    el.innerHTML = `[${time}] ${msg}\n` + el.innerHTML
}

function setStatus(msg, color) {
    document.getElementById("status").innerHTML =
        `<span class="status-dot ${color}"></span>${msg}`
}

function formatMins(mins) {
    const m = Math.floor(mins)
    if (m >= 60) return `${Math.floor(m/60)}h ${m%60}m`
    return `${m}m`
}

async function refresh() {
    log("Fetching remaining time...")
    setStatus("Checking...", "yellow")

    try {
        const res = await fetch(`${API_BASE}/time/remaining`, {
            headers: {
                "x-api-key": "" //ADD read env api key from Koyeb
            }
        })
        const data = await res.json()
        log(`Got: ${JSON.stringify(data)}`)

        document.getElementById("remaining").textContent = formatMins(data.remaining || 0)

        if ((data.remaining || 0) <= 0) {
            setStatus("Blocked — no time left", "red")
        } else {
            setStatus("Active — deducting on YouTube", "green")
        }
    } catch (err) {
        log(`ERROR: ${err.message}`)
        setStatus("Can't reach server", "red")
    }
}

refresh()
