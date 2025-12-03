const router = require('express').Router();

/**
 * Redirect to app deep link
 * GET /app/stream -> redirects to smartcontrol://stream
 */
router.get('/stream', (req, res) => {
    const deepLink = 'smartcontrol://stream';
    
    // Send HTML page that attempts to open the app
    res.send(`
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>กำลังเปิดแอป Smart Control...</title>
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
                h1 { font-size: 24px; margin-bottom: 16px; }
                p { font-size: 16px; opacity: 0.9; margin-bottom: 24px; }
                .spinner {
                    width: 50px;
                    height: 50px;
                    border: 4px solid rgba(255,255,255,0.3);
                    border-top-color: white;
                    border-radius: 50%;
                    animation: spin 1s linear infinite;
                    margin: 0 auto 24px;
                }
                @keyframes spin {
                    to { transform: rotate(360deg); }
                }
                .btn {
                    display: inline-block;
                    padding: 14px 32px;
                    background: white;
                    color: #667eea;
                    text-decoration: none;
                    border-radius: 30px;
                    font-weight: bold;
                    font-size: 16px;
                    box-shadow: 0 4px 15px rgba(0,0,0,0.2);
                    transition: transform 0.2s;
                }
                .btn:hover { transform: scale(1.05); }
                .note {
                    margin-top: 24px;
                    font-size: 13px;
                    opacity: 0.7;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="spinner"></div>
                <h1>🎵 Smart Control</h1>
                <p>กำลังเปิดแอปเพื่อฟังสตรีมเสียง...</p>
                <a href="${deepLink}" class="btn">เปิดแอป</a>
                <p class="note">หากแอปไม่เปิดอัตโนมัติ กรุณากดปุ่มด้านบน</p>
            </div>
            <script>
                // Try to open the app automatically
                setTimeout(function() {
                    window.location.href = '${deepLink}';
                }, 500);
            </script>
        </body>
        </html>
    `);
});

/**
 * Generic app redirect
 * GET /app/:path -> redirects to smartcontrol://:path
 */
router.get('/:path', (req, res) => {
    const path = req.params.path || 'home';
    const deepLink = `smartcontrol://${path}`;
    
    res.redirect(302, deepLink);
});

module.exports = router;
