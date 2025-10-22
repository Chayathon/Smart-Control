
const { spawn } = require('child_process');
const cfg = require('../config/config');
const bus = require('./bus');
const path = require('path');
const fs = require('fs');
const ytdlp = require('yt-dlp-exec');
const ffmpeg = require('fluent-ffmpeg');
const Song = require('../models/Song');
const Playlist = require('../models/Playlist')

let ffmpegProcess = null;
let isPaused = false;
let currentStreamUrl = null;

let stopping = false;
let starting = false;
let activeWs = null;

let playlistQueue = [];
let currentIndex = -1;
let playlistMode = false;
let playlistLoop = false;
let playlistStopping = false;
let nextTrackQueued = false;

// Timing and pause-resume control
let trackStartMonotonic = 0;   // timestamp when current track started
let trackBaseOffsetMs = 0;     // accumulated offset before current start
let lastKnownElapsedMs = 0;    // snapshot of elapsed when pausing/closing
let pausePendingResume = false; // true when paused by user and waiting to resume

const isAlive = (p) => !!p && p.exitCode === null;

function emitStatus({ event, extra = {} }) {
    bus.emit('status', {
        event,
        mode: playlistMode ? 'playlist' : 'single',
        index: currentIndex,
        total: playlistQueue.length,
        loop: playlistLoop,
        isPlaying: isAlive(ffmpegProcess),
        isPaused,
        currentUrl: currentStreamUrl,
        ...extra,
    });
}

function toSourceFromSong(songDoc) {
    const url = songDoc.url || '';
    const isHttp = /^https?:\/\//i.test(url);
    if (isHttp) {
        return { source: url, from: 'http', name: songDoc.name || url };
    }

    const absPath = path.resolve(path.join(__dirname, '../uploads', url));
    return { source: absPath, from: 'local', name: songDoc.name || url };
}

async function buildQueueFromDb() {
    const pl = await Playlist.find().sort({ order: 1 }).populate('id_song').lean();
    playlistQueue = pl
        .filter(item => item.id_song)
        .map(item => toSourceFromSong(item.id_song));
    currentIndex = playlistQueue.length ? 0 : -1;
}

async function _playIndex(i, seekMs = 0) {
    if (playlistStopping) {
        console.log('⏸️ Playlist stopping, aborting playback');
        return;
    }

    if (i < 0 || i >= playlistQueue.length) {
        console.log('📭 คิวว่าง หรือ index เกิน');
        await _quickStop();
        playlistMode = false;
        return;
    }

    // ไม่รอ starting flag เพื่อให้ตอบสนองเร็วขึ้น
    if (starting) {
        console.log('⚠️ กำลัง starting อยู่ ข้ามการเล่นครั้งนี้');
        nextTrackQueued = true;
        return;
    }
    
    console.log(`🎬 เริ่มต้นการเล่นเพลง index ${i}`);
    starting = true;
    nextTrackQueued = false;

    try {
        // Quick stop แทน stopAll เพื่อลดดีเลย์
        await _quickStop();
        
        if (playlistStopping) {
            console.log('⏸️ ตรวจพบ playlist stopping หลัง quick stop');
            return;
        }

        playlistMode = true;

        const { source, from, name } = playlistQueue[i];
        console.log(`▶️ [${i + 1}/${playlistQueue.length}] ${name}`);
        console.log(`📂 Source: ${source}`);

        const icecastUrl = `icecast://${cfg.icecast.username}:${cfg.icecast.password}` +
            `@${cfg.icecast.host}:${cfg.icecast.port}${cfg.icecast.mount}`;

        // ปรับแต่งสำหรับ transition ที่นุ่มนวล
        const ffArgs = [
            '-hide_banner', '-loglevel', 'error', '-nostdin',
            '-re',
            ...(seekMs > 0 ? ['-ss', String(seekMs / 1000)] : []),
            '-i', source,
            '-vn',
            // Audio fade in ช้าขึ้นเพื่อให้เนียนขึ้น
            '-af', 'afade=t=in:st=0:d=0.8',
            '-c:a', 'libmp3lame',
            '-b:a', '128k',
            '-ar', '44100',
            '-ac', '2',
            // Optimize for smooth transitions
            '-write_xing', '0',
            '-id3v2_version', '0',
            '-fflags', '+flush_packets+nobuffer',
            '-flush_packets', '1',
            '-content_type', 'audio/mpeg',
            '-f', 'mp3',
            icecastUrl
        ];

    ffmpegProcess = spawn('ffmpeg', ffArgs, { stdio: ['ignore', 'ignore', 'pipe'] });
        wireChildLogging(ffmpegProcess, 'ffmpeg');
    // initialize timing
    trackBaseOffsetMs = Math.max(0, seekMs | 0);
    trackStartMonotonic = Date.now();

        ffmpegProcess.on('close', async (code) => {
            console.log(`🎵 เพลงสิ้นสุด (code ${code})`);
            const wasPlaylistMode = playlistMode;
            ffmpegProcess = null;
            // หากเป็นการ pause ชั่วคราว อย่ารีเซ็ตสถานะ paused
            if (!pausePendingResume) {
                isPaused = false;
            }
            currentStreamUrl = null;
            // snapshot elapsed
            lastKnownElapsedMs = trackBaseOffsetMs + Math.max(0, Date.now() - trackStartMonotonic);

            if (!wasPlaylistMode || playlistStopping) {
                return;
            }

            // รอให้ Icecast buffer ล้างสะอาดเพื่อป้องกันเสียงกระตุก
            // เพิ่มเวลาเป็น 1.2 วินาที เพื่อให้ buffer ล้างสะอาดจริงๆ
            console.log('⏳ รอ buffer ล้างสะอาด...');
            await sleep(1200);
            // เพิ่มเวลาหน่วงก่อนเริ่มเพลงถัดไปตาม config เพื่อลดการกระตุก
            var delay = (cfg.stream && typeof cfg.stream.preStartDelayMs === 'number') ? cfg.stream.preStartDelayMs : 0;
            if (delay > 0) {
                console.log(`⏳ หน่วงก่อนเริ่มเพลงถัดไป ${delay}ms`);
                await sleep(delay);
            }
            console.log('✅ Buffer ล้างสะอาดแล้ว/ครบหน่วง เริ่มเพลงถัดไป');

            // If paused and waiting to resume, do not auto advance
            if (pausePendingResume) {
                console.log('⏸️ Pause pending resume, not auto-advancing');
                return;
            }
            const next = currentIndex + 1;
            if (next < playlistQueue.length) {
                currentIndex = next;
                await _playIndex(currentIndex);
            } else if (playlistLoop) {
                currentIndex = 0;
                await _playIndex(currentIndex);
            } else {
                console.log('✅ เพลย์ลิสต์จบครบทุกเพลง');
                playlistMode = false;
                emitStatus({ event: 'playlist-ended' });
            }
        });

        isPaused = false;
        currentStreamUrl = source;
        
        console.log(`📡 Emitting status: title="${name}", index=${i}, total=${playlistQueue.length}`);
        emitStatus({
            event: 'started',
            extra: { title: name, index: i, total: playlistQueue.length }
        });
    } finally {
        starting = false;
    }
}

// Quick stop สำหรับ playlist transitions
async function _quickStop() {
    if (!ffmpegProcess || ffmpegProcess.exitCode !== null) {
        ffmpegProcess = null;
        currentStreamUrl = null;
        return;
    }

    console.log('🛑 Quick stop: ปิด ffmpeg process...');
    
    return new Promise((resolve) => {
        const timeout = setTimeout(() => {
            if (ffmpegProcess && ffmpegProcess.exitCode === null) {
                console.log('⚠️ Force kill ffmpeg (timeout)');
                try { ffmpegProcess.kill('SIGKILL'); } catch { }
            }
            ffmpegProcess = null;
            currentStreamUrl = null;
            resolve();
        }, 800);

        ffmpegProcess.once('close', () => {
            clearTimeout(timeout);
            console.log('✅ ffmpeg ปิดสมบูรณ์');
            ffmpegProcess = null;
            currentStreamUrl = null;
            resolve();
        });

        try { 
            ffmpegProcess.stdin?.end(); 
        } catch { }
        
        try { 
            ffmpegProcess.kill('SIGTERM'); 
        } catch { }
    });
}

async function playPlaylist({ loop = false } = {}) {
    playlistLoop = !!loop;
    playlistStopping = false;

    await buildQueueFromDb();

    if (playlistQueue.length === 0) {
        console.log('⚠️ ไม่มีเพลงในเพลย์ลิสต์');
        return { success: false, message: 'ไม่มีเพลงในเพลย์ลิสต์' };
    }
    
    currentIndex = 0;
    playlistMode = true;
    trackBaseOffsetMs = 0;
    trackStartMonotonic = 0;
    lastKnownElapsedMs = 0;
    pausePendingResume = false;
    emitStatus({ event: 'playlist-started', extra: { total: playlistQueue.length } });
    
    await _playIndex(currentIndex, 0);
    return { success: true, message: 'เริ่มเล่นเพลย์ลิสต์' };
}

async function nextTrack() {
    if (!playlistMode) return { success: false, message: 'ไม่ได้อยู่ในโหมดเพลย์ลิสต์' };
    
    // ป้องกันกดถัดไปถ้าเป็นเพลงสุดท้ายและไม่มีการวนลูป
    if (currentIndex + 1 >= playlistQueue.length && !playlistLoop) {
        return { success: false, message: 'ถึงเพลงสุดท้ายแล้ว' };
    }
    
    // คำนวณ index ถัดไป
    const nextIdx = (currentIndex + 1) % playlistQueue.length;
    
    // หยุด process ปัจจุบันและรอให้จบสมบูรณ์
    console.log(`⏭️ กดเพลงถัดไป: ${currentIndex} -> ${nextIdx}`);
    playlistStopping = true;  // ป้องกัน auto-play
    await _quickStop();
    playlistStopping = false;
    
    // หน่วงก่อนเล่นเพลงถัดไปตามค่า config เพื่อลดการกระตุก
    {
        var delay = (cfg.stream && typeof cfg.stream.preStartDelayMs === 'number') ? cfg.stream.preStartDelayMs : 0;
        if (delay > 0) {
            console.log(`⏳ หน่วงก่อนเล่นเพลงถัดไป ${delay}ms`);
            await sleep(delay);
        }
    }
    // เล่นเพลงถัดไป
    currentIndex = nextIdx;
    playlistMode = true;
    trackBaseOffsetMs = 0; trackStartMonotonic = 0; lastKnownElapsedMs = 0; pausePendingResume = false;
    await _playIndex(currentIndex, 0);
    
    return { success: true, message: 'เพลงถัดไป' };
}

async function prevTrack() {
    if (!playlistMode) return { success: false, message: 'ไม่ได้อยู่ในโหมดเพลย์ลิสต์' };
    
    // ป้องกันกดย้อนกลับถ้าเป็นเพลงแรกและไม่มีการวนลูป
    if (currentIndex === 0 && !playlistLoop) {
        return { success: false, message: 'เป็นเพลงแรกแล้ว' };
    }
    
    // คำนวณ index ก่อนหน้า
    const prevIdx = (currentIndex - 1 + playlistQueue.length) % playlistQueue.length;
    
    // หยุด process ปัจจุบันและรอให้จบสมบูรณ์
    console.log(`⏮️ กดเพลงก่อนหน้า: ${currentIndex} -> ${prevIdx}`);
    playlistStopping = true;  // ป้องกัน auto-play
    await _quickStop();
    playlistStopping = false;
    
    // หน่วงก่อนเล่นเพลงก่อนหน้าเพื่อลดการกระตุก
    {
        var delay = (cfg.stream && typeof cfg.stream.preStartDelayMs === 'number') ? cfg.stream.preStartDelayMs : 0;
        if (delay > 0) {
            console.log(`⏳ หน่วงก่อนเล่นเพลงก่อนหน้า ${delay}ms`);
            await sleep(delay);
        }
    }
    // เล่นเพลงก่อนหน้า
    currentIndex = prevIdx;
    playlistMode = true;
    trackBaseOffsetMs = 0; trackStartMonotonic = 0; lastKnownElapsedMs = 0; pausePendingResume = false;
    await _playIndex(currentIndex, 0);
    
    return { success: true, message: 'เพลงก่อนหน้า' };
}

async function stopPlaylist() {
    playlistStopping = true;
    playlistMode = false;
    playlistQueue = [];
    currentIndex = -1;
    
    await stopAll();
    
    playlistStopping = false;
    emitStatus({ event: 'playlist-stopped' });
    return { success: true, message: 'หยุดเพลย์ลิสต์' };
}

function wireChildLogging(child, tag) {
    child.stderr.on('data', (d) => {
        const s = d.toString();
        // Only log actual errors, not warnings
        if (s.trim() && !s.includes('deprecated pixel format')) {
            console.log(`[${tag}] ${s.trim()}`);
        }
    });
    child.on('error', (err) => console.error(`[${tag}] error:`, err));
}

function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }

function stopProcess(proc) {
    if (!proc) return Promise.resolve();
    if (proc.exitCode !== null || proc.signalCode) return Promise.resolve();

    return new Promise((resolve) => {
        const done = () => { proc.removeAllListeners('close'); resolve(); };
        proc.once('close', done);

        try { proc.stdin?.end(); } catch { }
        try { proc.kill('SIGTERM'); } catch { }

        const hardKill = setTimeout(() => {
            if (proc.exitCode === null && !proc.killed) {
                try { proc.kill('SIGKILL'); } catch { }
            }
        }, 1500);

        proc.once('close', () => clearTimeout(hardKill));
    });
}

async function stopAll() {
    if (stopping) return;
    stopping = true;
    try {
        await Promise.all([stopProcess(ffmpegProcess)]);
    } finally {
        ffmpegProcess = null;
        isPaused = false;
        currentStreamUrl = null;
        emitStatus({ event: 'stopped' });
        await sleep(250);
        stopping = false;
    }
}

function resolveDirectUrl(youtubeUrl) {
    return new Promise((resolve, reject) => {
        const p = spawn('yt-dlp', [
            '--no-playlist',
            '-f', 'bestaudio',
            '--dump-json',
            youtubeUrl
        ], { stdio: ['ignore', 'pipe', 'pipe'] });

        let out = '';
        p.stdout.on('data', d => out += d.toString());
        p.stderr.on('data', d => console.log('[yt-dlp]', d.toString().trim()));
        p.on('close', (code) => {
            if (code !== 0) return reject(new Error(`yt-dlp exited with ${code}`));
            const lines = out.trim().split('\n').filter(Boolean);
            const obj = JSON.parse(lines[lines.length - 1]);
            const mediaUrl = obj.url;
            const headersObj = obj.http_headers || {};
            let headerLines = Object.entries(headersObj)
                .map(([k, v]) => `${k}: ${v}`)
                .join('\r\n');
            if (headerLines.length) headerLines += '\r\n';
            resolve({ mediaUrl, headerLines });
        });
    });
}

async function startYoutubeUrl(url) {
    while (starting) await sleep(50);
    starting = true;
    try {
        await stopAll();
        console.log(`▶️ เริ่มสตรีม YouTube: ${url}`);

        const { mediaUrl, headerLines } = await resolveDirectUrl(url);

        const icecastUrl = `icecast://${cfg.icecast.username}:${cfg.icecast.password}` +
            `@${cfg.icecast.host}:${cfg.icecast.port}${cfg.icecast.mount}`;

        const ffArgs = [
            '-hide_banner', '-loglevel', 'warning', '-nostdin',
            '-reconnect', '1', '-reconnect_streamed', '1', '-reconnect_at_eof', '1',
            '-reconnect_on_network_error', '1', '-reconnect_delay_max', '5',
            '-re'
        ];

        if (headerLines && headerLines.length) ffArgs.push('-headers', headerLines);

        ffArgs.push(
            '-i', mediaUrl,
            '-vn',
            '-c:a', 'libmp3lame',
            '-b:a', '128k',
            '-content_type', 'audio/mpeg',
            '-f', 'mp3',
            icecastUrl
        );

        ffmpegProcess = spawn('ffmpeg', ffArgs, { stdio: ['ignore', 'ignore', 'pipe'] });
        wireChildLogging(ffmpegProcess, 'ffmpeg');

        ffmpegProcess.on('close', (code) => {
            console.log(`🎵 สตรีม YouTube จบการทำงาน (รหัส ${code})`);
            const endedUrl = currentStreamUrl;
            ffmpegProcess = null;
            isPaused = false;
            currentStreamUrl = null;
            bus.emit('status', { event: 'ended', reason: 'ffmpeg-closed', code });

            if (cfg.stream.autoReplayOnEnd && endedUrl) {
                setTimeout(() => {
                    console.log('🔁 Auto replay same URL');
                    start(endedUrl).catch(e => console.error('Auto replay failed:', e));
                }, 1500);
            }
        });

        isPaused = false;
        currentStreamUrl = url;
        bus.emit('status', { event: 'started', url });
    } finally {
        starting = false;
    }
}

async function startLocalFile(filePath) {
    while (starting) await sleep(50);
    starting = true;
    try {
        await stopAll();
        console.log(`▶️ เริ่มสตรีมไฟล์ในเครื่อง: ${filePath}`);

        const absPath = path.resolve(filePath);

        const icecastUrl = `icecast://${cfg.icecast.username}:${cfg.icecast.password}` +
            `@${cfg.icecast.host}:${cfg.icecast.port}${cfg.icecast.mount}`;

        const ffArgs = [
            '-hide_banner', '-loglevel', 'warning', '-nostdin',
            '-re',
            '-i', absPath,
            '-vn',
            '-c:a', 'libmp3lame',
            '-b:a', '128k',
            '-content_type', 'audio/mpeg',
            '-f', 'mp3',
            icecastUrl
        ];

        ffmpegProcess = spawn('ffmpeg', ffArgs, { stdio: ['ignore', 'ignore', 'pipe'] });
        wireChildLogging(ffmpegProcess, 'ffmpeg');

        ffmpegProcess.on('close', (code) => {
            console.log(`🎵 สตรีมไฟล์ในเครื่องจบการทำงาน (รหัส ${code})`);
            const endedUrl = currentStreamUrl;
            ffmpegProcess = null;
            isPaused = false;
            currentStreamUrl = null;
            bus.emit('status', { event: 'ended', reason: 'ffmpeg-closed', code });

            if (cfg.stream.autoReplayOnEnd && endedUrl) {
                setTimeout(() => {
                    console.log('🔁 Auto replay same file');
                    startLocalFile(endedUrl).catch(e => console.error('Auto replay failed:', e));
                }, 1500);
            }
        });

        isPaused = false;
        currentStreamUrl = absPath;
        bus.emit('status', { event: 'started', url: absPath });
    } finally {
        starting = false;
    }
}

function pause() {
    if (!playlistMode || currentIndex < 0 || currentIndex >= playlistQueue.length) {
        console.log('⚠️ ไม่มี playlist ที่กำลังเล่นอยู่');
        throw new Error('no active playlist');
    }
    if (isPaused) {
        console.log('⚠️ หยุดชั่วคราวอยู่แล้ว');
        return;
    }
    // Snapshot elapsed time
    lastKnownElapsedMs = trackBaseOffsetMs + Math.max(0, Date.now() - trackStartMonotonic);
    isPaused = true;
    pausePendingResume = true;
    console.log(`⏸️ ขอหยุดชั่วคราว ณ ~${Math.round(lastKnownElapsedMs/1000)}s`);
    // Stop ffmpeg to avoid Icecast timeout causing auto-advance
    (async () => {
        try {
            playlistStopping = true; // prevent auto-advance in close handler
            await _quickStop();
        } finally {
            playlistStopping = false;
            emitStatus({ event: 'paused', extra: { resumeMs: lastKnownElapsedMs } });
        }
    })().catch(e => console.error('pause() error:', e));
}

function resume() {
    if (!playlistMode || currentIndex < 0 || currentIndex >= playlistQueue.length) {
        console.log('⚠️ ไม่มี playlist สำหรับเล่นต่อ');
        throw new Error('no paused stream');
    }
    if (!isPaused && !pausePendingResume) {
        console.log('⚠️ ไม่ได้หยุดชั่วคราวอยู่');
        return;
    }
    const seekMs = Math.max(0, lastKnownElapsedMs | 0);
    isPaused = false;
    pausePendingResume = false;
    console.log(`▶️ เล่นต่อจาก ~${Math.round(seekMs/1000)}s ที่ index ${currentIndex}`);
    (async () => {
        try {
            // Ensure current process is stopped
            playlistStopping = true;
            await _quickStop();
        } finally {
            playlistStopping = false;
            _playIndex(currentIndex, seekMs).catch(e => console.error('resume play failed:', e));
            emitStatus({ event: 'resumed', extra: { resumeMs: seekMs } });
        }
    })().catch(e => console.error('resume() error:', e));
}

function getStatus() {
    const status = {
        isPlaying: isAlive(ffmpegProcess),
        isPaused,
        currentUrl: currentStreamUrl,
        mode: playlistMode ? 'playlist' : 'single',
        playlistMode,
        currentIndex,
        totalSongs: playlistQueue.length,
        loop: playlistLoop,
        resumeMs: lastKnownElapsedMs,
    };
    
    // เพิ่มข้อมูลเพลงปัจจุบันถ้าอยู่ในโหมด playlist
    if (playlistMode && currentIndex >= 0 && currentIndex < playlistQueue.length) {
        const currentSong = playlistQueue[currentIndex];
        status.currentSong = {
            title: currentSong.name,
            index: currentIndex,
            total: playlistQueue.length,
        };
    }
    
    return status;
}

async function startMicStream(ws) {
    // ปิด client เก่าก่อน (ถ้ามี)
    if (activeWs && activeWs !== ws) {
        try { activeWs.terminate(); } catch { }
        activeWs = null;
    }

    while (starting) await sleep(50);
    starting = true;

    try {
        await stopAll();
        console.log("🎤 Starting mic stream (Optimized for RPi4)");
        activeWs = ws;

        const icecastUrl = `icecast://${cfg.icecast.username}:${cfg.icecast.password}` +
            `@${cfg.icecast.host}:${cfg.icecast.port}${cfg.icecast.mount}`;

        // Optimized ffmpeg configuration for RPi4 - Low Latency
        const ffArgs = [
            '-hide_banner', '-loglevel', 'warning', '-nostdin',
            
            // Input: PCM 16-bit stereo 44.1kHz
            '-f', 's16le', '-ar', '44100', '-ac', '2', '-i', 'pipe:0',
            
            // Audio processing
            '-af', 'volume=2.0,highpass=f=80,lowpass=f=15000',
            
            // Output: MP3 128k
            '-c:a', 'libmp3lame', '-b:a', '128k', '-ar', '44100', '-ac', '2',
            
            // Low-latency optimization
            '-write_xing', '0', '-id3v2_version', '0',
            '-fflags', '+nobuffer', '-flush_packets', '1',
            
            '-content_type', 'audio/mpeg', '-f', 'mp3', icecastUrl
        ];

        ffmpegProcess = spawn('ffmpeg', ffArgs, { 
            stdio: ['pipe', 'ignore', 'pipe']
        });
        
        wireChildLogging(ffmpegProcess, 'ffmpeg-mic');

        // Performance monitoring
        let bytesReceived = 0;
        let lastLog = Date.now();

        // Handle incoming audio data
        ws.on('message', (msg) => {
            if (!ffmpegProcess || ffmpegProcess.exitCode !== null || !Buffer.isBuffer(msg)) return;
            
            try {
                ffmpegProcess.stdin.write(msg);
                bytesReceived += msg.length;
                
                // Log every 5 seconds
                const now = Date.now();
                if (now - lastLog > 5000) {
                    const kbps = ((bytesReceived * 8) / 5000).toFixed(1);
                    console.log(`🎤 Stream: ${kbps} kbps`);
                    bytesReceived = 0;
                    lastLog = now;
                }
            } catch (err) {
                console.error('⚠️ Write error:', err.message);
            }
        });

        // Cleanup handler
        const cleanup = async () => {
            console.log("🔌 Mic disconnected");
            try { 
                if (ffmpegProcess?.stdin && !ffmpegProcess.stdin.destroyed) {
                    ffmpegProcess.stdin.end();
                }
            } catch { }
            
            await sleep(200); // Wait for buffer flush
            await stopAll();
            
            if (activeWs === ws) activeWs = null;
        };

        ws.on('close', cleanup);
        ws.on('error', (err) => {
            console.error('⚠️ WS error:', err.message);
            cleanup();
        });

        ffmpegProcess.on('close', (code) => {
            console.log(`🎵 ffmpeg closed (${code})`);
            if (activeWs === ws) activeWs = null;
        });

        isPaused = false;
        currentStreamUrl = "flutter-mic";
        bus.emit('status', { event: 'mic-started', url: currentStreamUrl });
    } finally {
        starting = false;
    }
}

async function stopMicStream() {
    console.log("🛑 Stopping mic stream");
    
    if (activeWs) {
        try {
            activeWs.close(1000, 'stop-requested');
        } catch (err) {
            console.error('⚠️ Close error:', err);
        }
        activeWs = null;
    }
    
    await stopAll();
    bus.emit('status', { event: 'mic-stopped' });
}

module.exports = {
    getStatus,
    startMicStream,
    stopMicStream,
    startLocalFile,
    startYoutubeUrl,
    playPlaylist,
    stopPlaylist,
    nextTrack,
    prevTrack,
    pause,
    resume,
    stopAll,

    _internals: { isAlive: (p) => isAlive(p) }
};

