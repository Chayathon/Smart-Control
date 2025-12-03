const router = require('express').Router();

/**
 * Open app page
 * GET /app/stream -> shows page to open the app
 */
router.get('/stream', (req, res) => {
    // Send HTML page with instructions to open the app
    res.send(`
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Smart Control - ฟังสตรีมเสียง</title>
            <style>
                body {
                    font-family: 'Kanit', -apple-system, BlinkMacSystemFont, sans-serif;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    min-height: 100vh;
                    margin: 0;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    text-align: center;
                }
                .container {
                    padding: 40px;
                    max-width: 400px;
                }
                .icon { font-size: 64px; margin-bottom: 16px; }
                h1 { font-size: 24px; margin-bottom: 8px; }
                p { font-size: 16px; opacity: 0.9; margin-bottom: 24px; line-height: 1.5; }
                .note {
                    margin-top: 24px;
                    font-size: 13px;
                    opacity: 0.7;
                    padding: 16px;
                    background: rgba(255,255,255,0.1);
                    border-radius: 12px;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="icon">🎵</div>
                <h1>Smart Control</h1>
                <p>กำลังถ่ายทอดสดเสียงอยู่ขณะนี้!</p>
                <p class="note">📱 เปิดแอป Smart Control บนมือถือของคุณเพื่อรับฟังสตรีมเสียง</p>
            </div>
        </body>
        </html>
    `);
});

module.exports = router;
