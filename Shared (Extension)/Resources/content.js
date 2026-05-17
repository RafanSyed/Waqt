// check storage on page load
chrome.storage.local.get(["remaining", "blocked"], (result) => {
    if (result.blocked || (result.remaining !== undefined && result.remaining <= 0)) {
        blockWebsite()
    }
})

// listen for block message from background
chrome.runtime.onMessage.addListener((message) => {
    if (message.action === "block") {
        blockWebsite()
    }
})

function blockWebsite() {
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
}
 terminal
