const API_BASE = "https://forward-gilly-webguardian-1b994c6d.koyeb.app"

let deductInterval = null

// Always check server on page load/navigation, don't trust cached storage
async function init() {
    try {
        const res = await fetch(`${API_BASE}/time/remaining`, {
            headers: {
                "x-api-key": "YOUR_SECRET_KEY_HERE"
            }
        })
        const data = await res.json()

        chrome.storage.local.set({ remaining: data.remaining, blocked: data.remaining <= 0 })

        if (data.remaining <= 0) {
            blockWebsite()
            return
        }

        if (!document.hidden) {
            startDeducting()
        }
    } catch (err) {
        // If server unreachable, fall back to local storage
        chrome.storage.local.get(["remaining", "blocked"], (result) => {
            if (result.blocked || result.remaining <= 0) {
                blockWebsite()
                return
            }
            if (!document.hidden) {
                startDeducting()
            }
        })
    }
}

// Kick off initial check
init()

// Re-check on YouTube SPA navigation without resetting the active deduction timer
let lastUrl = location.href
new MutationObserver(() => {
    if (location.href !== lastUrl) {
        lastUrl = location.href
        // Just re-verify if they ran out of time on navigation; 
        // don't stopDeducting() here so the 60s loop isn't exploited.
        init() 
    }
}).observe(document, { subtree: true, childList: true })

document.addEventListener("visibilitychange", () => {
    if (document.hidden) {
        stopDeducting()
    } else {
        init()
    }
})

function startDeducting() {
    if (deductInterval) return

    deductInterval = setInterval(async () => {
        if (document.hidden) {
            stopDeducting()
            return
        }

        try {
            const res = await fetch(`${API_BASE}/time/deduct`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    "x-api-key": "YOUR_SECRET_KEY_HERE"
                },
                body: JSON.stringify({ seconds: 60 })
            })
            const data = await res.json()
            chrome.storage.local.set({ remaining: data.remaining, blocked: data.blocked })

            if (data.blocked) {
                blockWebsite()
            }
        } catch (err) {
            console.error("Waqt: deduct failed", err)
        }
    }, 60000)
}

function stopDeducting() {
    clearInterval(deductInterval)
    deductInterval = null
}

function blockWebsite() {
    stopDeducting()
    document.documentElement.innerHTML = `
        <head><title>Waqt — Time's Up</title></head>
        <body style="
            margin:0;
            background:#05050f;
            color:white;
            display:flex;
            align-items:center;
            justify-content:center;
            height:100vh;
            font-family:-apple-system;
        ">
            <div style="text-align:center;max-width:500px;padding:40px;">
                <div style="font-size:64px;margin-bottom:16px;">وقت</div>
                <h1 style="font-size:36px;margin-bottom:16px;font-weight:700;">Time's Up</h1>
                <p style="font-size:18px;opacity:0.6;line-height:1.6;">
                    Open the Waqt app and read some Quran to earn more time.
                </p>
            </div>
        </body>
    `

    const observer = new MutationObserver(() => {
        if (!document.body?.innerHTML?.includes("Time's Up")) {
            blockWebsite()
        }
    })
    observer.observe(document.documentElement, { childList: true, subtree: true })
}