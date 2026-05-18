const API_BASE = "https://forward-gilly-webguardian-1b994c6d.koyeb.app"

let deductInterval = null

// always check server on page load, don't trust cached storage
async function init() {
    try {
        const res = await fetch(`${API_BASE}/time/remaining`, {
            headers: {
                "x-api-key": "" //ADD read env api key from Koyeb
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
        // if server unreachable, fall back to storage
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

init()

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
                    "x-api-key": "" //ADD read env api key from Koyeb
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
