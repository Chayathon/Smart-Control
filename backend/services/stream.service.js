
const { spawn } = require('child_process');
const cfg = require('../config/config');
const bus = require('./bus');
const path = require('path');
const fs = require('fs');
// Removed heavy, unused imports to reduce startup overhead
// (we spawn yt-dlp/ffmpeg directly via child_process)
const Song = require('../models/Song');
const Playlist = require('../models/Playlist');
const settingsService = require('./settings.service');

let ffmpegProcess = null;
let isPaused = false;
let currentStreamUrl = null;
let activeMode = 'none';
let currentDisplayName = null;

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
// Generic paused state to support pause/resume for all modes
let pausedState = null; // { kind: 'playlist'|'youtube'|'file', index?, url?, path?, resumeMs }

const ytdlpCache = new Map();

const isAlive = (p) => !!p && p.exitCode === null;

function getIcecastUrl() {
    const { icecast } = cfg;
    return `icecast://${icecast.username}:${icecast.password}` +
        `@${icecast.host}:${icecast.port}${icecast.mount}`;
}

function getPreStartDelayMs() {
    const delay = cfg.stream && typeof cfg.stream.preStartDelayMs === 'number' ? cfg.stream.preStartDelayMs : 0;
    return Math.max(0, delay | 0);
}

function nowMs() { return Date.now(); }

async function getSampleRateFromDb() {
    try {
        const sampleRate = await settingsService.getSetting('sampleRate');
        return sampleRate !== null ? String(sampleRate) : '44100';
    } catch (error) {
        console.warn('⚠️ ไม่สามารถดึงค่า sampleRate จาก DB ได้, ใช้ค่าเริ่มต้น 44100:', error.message);
        return '44100';
    }
}

function emitStatus({ event, extra = {} }) {
    bus.emit('status', {
        event,
        mode: playlistMode ? 'playlist' : 'single',
        index: currentIndex,
        total: playlistQueue.length,
        loop: playlistLoop,
        isPlaying: isAlive(ffmpegProcess) && currentStreamUrl !== 'flutter-mic',
        isPaused,
        currentUrl: currentStreamUrl,
        activeMode,
        ...extra,
    });
}

// -------------------------------------------------
// DRY helpers for spawning FFmpeg to Icecast
// -------------------------------------------------
function icecastOutputArgs({
    bitrate = '128k',
    sampleRate = '44100',
    channels = '2',
    addLowLatency = false,
    extra = [],
} = {}) {
    const out = [
        '-c:a', 'libmp3lame',
        '-b:a', bitrate,
        '-ar', sampleRate,
        '-ac', channels,
        '-content_type', 'audio/mpeg',
        '-f', 'mp3',
    ];
    if (addLowLatency) {
        out.push('-fflags', '+nobuffer', '-flush_packets', '1');
    }
    out.push(...extra);
    out.push(getIcecastUrl());
    return out;
}

function baseFfmpegArgs({ loglevel = 'error' } = {}) {
    return ['-hide_banner', '-loglevel', loglevel, '-nostdin'];
}

function spawnFfmpeg(args, tag = 'ffmpeg') {
    const proc = spawn('ffmpeg', args, { stdio: ['ignore', 'ignore', 'pipe'] });
    wireChildLogging(proc, tag);
    return proc;
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
        await _quickStop();
        
        if (playlistStopping) {
            console.log('⏸️ ตรวจพบ playlist stopping หลัง quick stop');
            return;
        }

        playlistMode = true;

        const { source, from, name } = playlistQueue[i];
        console.log(`▶️ [${i + 1}/${playlistQueue.length}] ${name}`);
        console.log(`📂 Source: ${source}`);

        // ดึงค่า sampleRate จาก DB
        const sampleRate = await getSampleRateFromDb();
        console.log(`🎵 Sample Rate: ${sampleRate} Hz`);

        // ปรับแต่งสำหรับ transition ที่นุ่มนวล
        const ffArgs = [
            ...baseFfmpegArgs({ loglevel: 'error' }),
            '-re',
            ...(seekMs > 0 ? ['-ss', String(seekMs / 1000)] : []),
            '-i', source,
            '-vn',
            // Audio fade in ช้าขึ้นเพื่อให้เนียนขึ้น
            '-af', 'afade=t=in:st=0:d=0.8',
            ...icecastOutputArgs({
                bitrate: '128k', sampleRate, channels: '2', addLowLatency: true,
                extra: ['-write_xing', '0', '-id3v2_version', '0', '-fflags', '+flush_packets+nobuffer']
            }),
        ];

        ffmpegProcess = spawnFfmpeg(ffArgs, 'ffmpeg');
    trackBaseOffsetMs = Math.max(0, seekMs | 0);
    trackStartMonotonic = nowMs();

        ffmpegProcess.on('close', async (code) => {
            console.log(`🎵 เพลงสิ้นสุด (code ${code})`);
            const wasPlaylistMode = playlistMode;
            ffmpegProcess = null;
            if (!pausePendingResume) {
                isPaused = false;
            }
            currentStreamUrl = null;
            lastKnownElapsedMs = trackBaseOffsetMs + Math.max(0, nowMs() - trackStartMonotonic);

            if (!wasPlaylistMode || playlistStopping) {
                return;
            }

            // รอให้ Icecast buffer ล้างสะอาดเพื่อป้องกันเสียงกระตุก
            // เพิ่มเวลาเป็น 1.2 วินาที เพื่อให้ buffer ล้างสะอาดจริงๆ
            console.log('⏳ รอ buffer ล้างสะอาด...');
            await sleep(1200);
            // เพิ่มเวลาหน่วงก่อนเริ่มเพลงถัดไปตาม config เพื่อลดการกระตุก
            const delay = getPreStartDelayMs();
            if (delay > 0) {
                console.log(`⏳ หน่วงก่อนเริ่มเพลงถัดไป ${delay}ms`);
                await sleep(delay);
            }
            console.log('✅ Buffer ล้างสะอาดแล้ว/ครบหน่วง เริ่มเพลงถัดไป');

            if (pausePendingResume) {
                console.log('⏸️ Pause pending resume, not auto-advancing');
                return;
            }
            
            // ดึงค่า loop ล่าสุดจาก DB ก่อนตัดสินใจเล่นต่อ
            try {
                const loopFromDb = await settingsService.getSetting('loopPlaylist');
                playlistLoop = loopFromDb !== null ? !!loopFromDb : false;
            } catch (error) {
                console.warn('⚠️ ไม่สามารถดึงค่า loopPlaylist จาก DB ได้:', error.message);
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
                activeMode = 'none';
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

async function _quickStop() {
    if (!ffmpegProcess || ffmpegProcess.exitCode !== null) {
        ffmpegProcess = null;
        currentStreamUrl = null;
        currentDisplayName = null;
        return;
    }
    console.log('🛑 Quick stop: ปิด ffmpeg process...');
    await stopProcess(ffmpegProcess, 800);
    ffmpegProcess = null;
    currentStreamUrl = null;
    currentDisplayName = null;
}

async function playPlaylist({ loop = false } = {}) {
    if (activeMode !== 'none') {
        const err = new Error(`ระบบกำลังเล่นโหมด ${activeMode} อยู่ โปรดหยุดก่อนเริ่มเพลย์ลิสต์`);
        err.code = 'MODE_BUSY';
        err.activeMode = activeMode;
        err.requestedMode = 'playlist';
        throw err;
    }
    
    // ดึงค่า loop จากฐานข้อมูล Settings แทนการใช้ parameter
    try {
        const loopFromDb = await settingsService.getSetting('loopPlaylist');
        playlistLoop = loopFromDb !== null ? !!loopFromDb : false;
        console.log(`🔄 Loop Playlist from DB: ${playlistLoop}`);
    } catch (error) {
        console.warn('⚠️ ไม่สามารถดึงค่า loopPlaylist จาก DB ได้, ใช้ค่าเริ่มต้น false:', error.message);
        playlistLoop = false;
    }
    
    playlistStopping = false;

    await buildQueueFromDb();

    if (playlistQueue.length === 0) {
        console.log('⚠️ ไม่มีเพลงในเพลย์ลิสต์');
        return { success: false, message: 'ไม่มีเพลงในเพลย์ลิสต์' };
    }
    
    currentIndex = 0;
    playlistMode = true;
    activeMode = 'playlist';
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
    
    // ดึงค่า loop ล่าสุดจาก DB
    try {
        const loopFromDb = await settingsService.getSetting('loopPlaylist');
        playlistLoop = loopFromDb !== null ? !!loopFromDb : false;
    } catch (error) {
        console.warn('⚠️ ไม่สามารถดึงค่า loopPlaylist จาก DB ได้:', error.message);
    }
    
    if (currentIndex + 1 >= playlistQueue.length && !playlistLoop) {
        return { success: false, message: 'ถึงเพลงสุดท้ายแล้ว' };
    }
    
    const nextIdx = (currentIndex + 1) % playlistQueue.length;
    
    console.log(`⏭️ กดเพลงถัดไป: ${currentIndex} -> ${nextIdx}`);
    playlistStopping = true;
    await _quickStop();
    playlistStopping = false;
    
    const delay = getPreStartDelayMs();
    if (delay > 0) {
        console.log(`⏳ หน่วงก่อนเล่นเพลงถัดไป ${delay}ms`);
        await sleep(delay);
    }

    currentIndex = nextIdx;
    playlistMode = true;
    trackBaseOffsetMs = 0; trackStartMonotonic = 0; lastKnownElapsedMs = 0; pausePendingResume = false;
    await _playIndex(currentIndex, 0);
    
    return { success: true, message: 'เพลงถัดไป' };
}

async function prevTrack() {
    if (!playlistMode) return { success: false, message: 'ไม่ได้อยู่ในโหมดเพลย์ลิสต์' };
    
    // ดึงค่า loop ล่าสุดจาก DB
    try {
        const loopFromDb = await settingsService.getSetting('loopPlaylist');
        playlistLoop = loopFromDb !== null ? !!loopFromDb : false;
    } catch (error) {
        console.warn('⚠️ ไม่สามารถดึงค่า loopPlaylist จาก DB ได้:', error.message);
    }
    
    if (currentIndex === 0 && !playlistLoop) {
        return { success: false, message: 'เป็นเพลงแรกแล้ว' };
    }
    
    const prevIdx = (currentIndex - 1 + playlistQueue.length) % playlistQueue.length;
    
    console.log(`⏮️ กดเพลงก่อนหน้า: ${currentIndex} -> ${prevIdx}`);
    playlistStopping = true;
    await _quickStop();
    playlistStopping = false;
    
    const delay = getPreStartDelayMs();
    if (delay > 0) {
        console.log(`⏳ หน่วงก่อนเล่นเพลงก่อนหน้า ${delay}ms`);
        await sleep(delay);
    }

    currentIndex = prevIdx;
    playlistMode = true;
    trackBaseOffsetMs = 0; trackStartMonotonic = 0; lastKnownElapsedMs = 0; pausePendingResume = false;
    await _playIndex(currentIndex, 0);
    
    return { success: true, message: 'เพลงก่อนหน้า' };
}

async function stop() {
    playlistStopping = true;
    playlistMode = false;
    playlistQueue = [];
    currentIndex = -1;
    pausedState = null;
    pausePendingResume = false;
    
    await stopAll();
    
    playlistStopping = false;
    activeMode = 'none';
    emitStatus({ event: 'stopped-all' });
    return { success: true, message: 'หยุดการเล่น' };
}

function wireChildLogging(child, tag) {
    child.stderr.on('data', (d) => {
        const s = d.toString();
        if (s.trim() && !s.includes('deprecated pixel format')) {
            console.log(`[${tag}] ${s.trim()}`);
        }
    });
    child.on('error', (err) => console.error(`[${tag}] error:`, err));
}

function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }

function stopProcess(proc, softTimeoutMs = 1500) {
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
        }, Math.max(200, softTimeoutMs | 0));

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
        activeMode = 'none';
        emitStatus({ event: 'stopped' });
        await sleep(250);
        stopping = false;
    }
}

function resolveDirectUrl(youtubeUrl) {
    const ttl = (cfg.stream && cfg.stream.ytCacheTtlMs) || 10 * 60 * 1000;
    const cached = ytdlpCache.get(youtubeUrl);
    if (cached && (Date.now() - cached.cachedAt) < ttl) {
        return Promise.resolve({ mediaUrl: cached.mediaUrl, headerLines: cached.headerLines });
    }

    return new Promise((resolve, reject) => {
        const args = [
            '--no-playlist',
            '--no-warnings',
            '--geo-bypass',
            '-f', 'bestaudio/best',
            '--dump-json',
            youtubeUrl
        ];
        const p = spawn('yt-dlp', args, { stdio: ['ignore', 'pipe', 'pipe'] });

        let out = '';
        p.stdout.on('data', d => out += d.toString());
        p.stderr.on('data', d => {
            const s = d.toString().trim();
            if (s) console.log('[yt-dlp]', s);
        });
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

            ytdlpCache.set(youtubeUrl, { mediaUrl, headerLines, cachedAt: Date.now() });
            resolve({ mediaUrl, headerLines });
        });
    });
}

async function startYoutubeUrl(url, seekMs = 0, opts = {}) {
    if (activeMode !== 'none') {
        const allowResume = opts && opts.fromResume === true && activeMode === 'youtube';
        if (!allowResume) {
        const err = new Error(`ระบบกำลังเล่นโหมด ${activeMode} อยู่ โปรดหยุดก่อนเริ่ม YouTube`);
        err.code = 'MODE_BUSY';
        err.activeMode = activeMode;
        err.requestedMode = 'youtube';
        throw err;
        }
    }
    while (starting) await sleep(50);
    starting = true;
    try {
        // Stop only the active FFmpeg process fast to reduce extra events
        await _quickStop();
        console.log(`▶️ เริ่มสตรีม YouTube: ${url}`);

        const { mediaUrl, headerLines } = await resolveDirectUrl(url);
        
        // ดึงค่า sampleRate จาก DB
        const sampleRate = await getSampleRateFromDb();
        console.log(`🎵 Sample Rate: ${sampleRate} Hz`);

        const ffArgs = [
            ...baseFfmpegArgs({ loglevel: 'error' }), '-nostats',
            // Faster start-up probing
            '-analyzeduration', '0', '-probesize', '32k',
            // Improve stability on flaky networks
            '-reconnect', '1', '-reconnect_streamed', '1', '-reconnect_at_eof', '1',
            '-reconnect_on_network_error', '1', '-reconnect_delay_max', '5',
            '-reconnect_on_http_error', '4xx,5xx',
            // Input queue to absorb jitter
            '-thread_queue_size', '512'
        ];

        if (headerLines && headerLines.length) ffArgs.push('-headers', headerLines);

        const seekSec = String((seekMs > 0 ? (seekMs / 1000) : 0));
        const isHls = /m3u8/i.test(mediaUrl);

        if (!isHls) {
            if (seekMs > 0) ffArgs.push('-ss', seekSec);
            ffArgs.push('-re', '-i', mediaUrl);
        } else {
            if (seekMs > 0) {
                ffArgs.push('-i', mediaUrl, '-ss', seekSec);
            } else {
                ffArgs.push('-re', '-i', mediaUrl);
            }
        }

        ffArgs.push('-vn', '-dn', ...icecastOutputArgs({ bitrate: '128k', sampleRate }));

        ffmpegProcess = spawnFfmpeg(ffArgs, 'ffmpeg');

        ffmpegProcess.on('close', (code) => {
            console.log(`🎵 สตรีม YouTube จบการทำงาน (รหัส ${code})`);
            const endedUrl = currentStreamUrl;
            ffmpegProcess = null;
            if (!pausePendingResume) {
                isPaused = false;
            }
            currentStreamUrl = null;
            if (!pausePendingResume) {
                activeMode = 'none';
            }
            if (!pausePendingResume) {
                bus.emit('status', { event: 'ended', reason: 'ffmpeg-closed', code });
            }

            if (!pausePendingResume && code !== 0 && endedUrl) {
                ytdlpCache.delete(endedUrl);
            }

            if (!pausePendingResume && cfg.stream.autoReplayOnEnd && endedUrl) {
                setTimeout(() => {
                    console.log('🔁 Auto replay same URL');
                    startYoutubeUrl(endedUrl).catch(e => console.error('Auto replay failed:', e));
                }, 1500);
            }
        });

        isPaused = false;
        currentStreamUrl = url;
        activeMode = 'youtube';
        trackBaseOffsetMs = Math.max(0, seekMs | 0);
    trackStartMonotonic = nowMs();
        bus.emit('status', { event: 'started', url });
    } finally {
        starting = false;
    }
}

async function startLocalFile(filePath, seekMs = 0, opts = {}) {
    if (activeMode !== 'none') {
        const allowResume = opts && opts.fromResume === true && activeMode === 'file';
        if (!allowResume) {
        const err = new Error(`ระบบกำลังเล่นโหมด ${activeMode} อยู่ โปรดหยุดก่อนเริ่มไฟล์จากเครื่อง`);
        err.code = 'MODE_BUSY';
        err.activeMode = activeMode;
        err.requestedMode = 'file';
        throw err;
        }
    }
    while (starting) await sleep(50);
    starting = true;
    try {
        // Stop only current FFmpeg to avoid extra stop events
        await _quickStop();
        console.log(`▶️ เริ่มสตรีมไฟล์ในเครื่อง: ${filePath}`);

        const absPath = path.resolve(filePath);
        const providedName = (opts && (opts.displayName || opts.name)) || null;
        currentDisplayName = providedName || path.basename(absPath);

        // ดึงค่า sampleRate จาก DB
        const sampleRate = await getSampleRateFromDb();
        console.log(`🎵 Sample Rate: ${sampleRate} Hz`);

        const ffArgs = [
            ...baseFfmpegArgs({ loglevel: 'warning' }), '-re',
            ...(seekMs > 0 ? ['-ss', String(seekMs / 1000)] : []),
            '-i', absPath,
            '-vn',
            ...icecastOutputArgs({ bitrate: '128k', sampleRate })
        ];

        ffmpegProcess = spawnFfmpeg(ffArgs, 'ffmpeg');

        ffmpegProcess.on('close', (code) => {
            console.log(`🎵 สตรีมไฟล์ในเครื่องจบการทำงาน (รหัส ${code})`);
            const endedUrl = currentStreamUrl;
            ffmpegProcess = null;
            if (!pausePendingResume) {
                isPaused = false;
            }
            currentStreamUrl = null;
            if (!pausePendingResume) {
                activeMode = 'none';
            }
            if (!pausePendingResume) {
                bus.emit('status', { event: 'ended', reason: 'ffmpeg-closed', code });
            }

            if (!pausePendingResume && cfg.stream.autoReplayOnEnd && endedUrl) {
                setTimeout(() => {
                    console.log('🔁 Auto replay same file');
                    startLocalFile(endedUrl).catch(e => console.error('Auto replay failed:', e));
                }, 1500);
            }
        });

        isPaused = false;
        currentStreamUrl = absPath;
        activeMode = 'file';
        trackBaseOffsetMs = Math.max(0, seekMs | 0);
        trackStartMonotonic = nowMs();
        bus.emit('status', { event: 'started', url: absPath, name: currentDisplayName });
    } finally {
        starting = false;
    }
}

function pause() {
    if (activeMode === 'mic') {
        throw new Error('cannot pause mic');
    }
    if (activeMode === 'youtube') {
        throw new Error('cannot pause youtube');
    }
    if (activeMode === 'none') {
        throw new Error('no active stream');
    }
    if (isPaused) {
        console.log('⚠️ หยุดชั่วคราวอยู่แล้ว');
        return;
    }

    lastKnownElapsedMs = trackBaseOffsetMs + Math.max(0, nowMs() - trackStartMonotonic);
    isPaused = true;
    pausePendingResume = true;

    if (activeMode === 'playlist') {
        if (currentIndex < 0 || currentIndex >= playlistQueue.length) {
            throw new Error('no active playlist');
        }
        pausedState = { kind: 'playlist', index: currentIndex, resumeMs: lastKnownElapsedMs };
    } else if (activeMode === 'youtube') {
        throw new Error('cannot pause youtube');
    } else if (activeMode === 'file') {
        pausedState = { kind: 'file', path: currentStreamUrl, resumeMs: lastKnownElapsedMs };
    }

    console.log(`⏸️ หยุดชั่วคราว (${pausedState?.kind}) ณ ~${Math.round(lastKnownElapsedMs/1000)}s`);
    (async () => {
        try {
            if (activeMode === 'playlist') {
                playlistStopping = true;
            }
            await _quickStop();
        } finally {
            playlistStopping = false;
            emitStatus({ event: 'paused', extra: { resumeMs: lastKnownElapsedMs, kind: pausedState?.kind } });
        }
    })().catch(e => console.error('pause() error:', e));
}

function resume() {
    if (activeMode === 'mic') {
        throw new Error('cannot resume while mic is active');
    }
    if (!isPaused || !pausePendingResume || !pausedState) {
        throw new Error('no paused stream');
    }
    if (pausedState.kind === 'youtube') {
        throw new Error('cannot resume youtube');
    }
    const seekMs = Math.max(0, (pausedState.resumeMs ?? lastKnownElapsedMs) | 0);

    const kind = pausedState.kind;
    console.log(`▶️ เล่นต่อ (${kind}) จาก ~${Math.round(seekMs/1000)}s`);
    const toResume = pausedState;
    pausedState = null;
    isPaused = false;
    pausePendingResume = false;

    (async () => {
        try {
            await _quickStop();
        } finally {
            if (kind === 'playlist') {
                playlistMode = true;
                currentIndex = typeof toResume.index === 'number' ? toResume.index : currentIndex;
                activeMode = 'playlist';
                _playIndex(currentIndex, seekMs).catch(e => console.error('resume playlist failed:', e));
            } else if (kind === 'youtube' && toResume.url) {
                console.warn('Resume requested for YouTube but disabled');
            } else if (kind === 'file' && toResume.path) {
                startLocalFile(toResume.path, seekMs, { fromResume: true }).catch(e => console.error('resume file failed:', e));
            }
            emitStatus({ event: 'resumed', extra: { resumeMs: seekMs, kind } });
        }
    })().catch(e => console.error('resume() error:', e));
}

function getStatus() {
    const status = {
        isPlaying: isAlive(ffmpegProcess) && currentStreamUrl !== 'flutter-mic',
        isPaused,
        currentUrl: currentStreamUrl,
        mode: playlistMode ? 'playlist' : 'single',
        playlistMode,
        currentIndex,
        totalSongs: playlistQueue.length,
        loop: playlistLoop,
        resumeMs: lastKnownElapsedMs,
        activeMode,
        name: currentDisplayName,
    };
    
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
    // Do not control or change current playback mode here.
    // If another non-mic stream is still active, reject mic start to avoid clobbering.
    if (isAlive(ffmpegProcess) && currentStreamUrl !== 'flutter-mic') {
        console.warn('Mic start requested while another stream is active; rejecting without altering playback.');
        try { ws.close(1013, 'stream-busy'); } catch { }
        return;
    }

    if (activeWs && activeWs !== ws) {
        try { activeWs.terminate(); } catch { }
        activeWs = null;
    }

    while (starting) await sleep(50);
    starting = true;

    try {
        console.log("🎤 Starting mic stream (Optimized for low latency)");
        activeWs = ws;

        const icecastUrl = getIcecastUrl();
        
        // ดึงค่า sampleRate จาก DB
        const sampleRate = await getSampleRateFromDb();
        console.log(`🎵 Mic Sample Rate: ${sampleRate} Hz`);

        const ffArgs = [
            // General
            '-hide_banner', '-loglevel', 'error', '-nostdin',
            // try to minimize internal buffering
            '-fflags', '+nobuffer',
            // Input: raw PCM 16-bit stereo from stdin (sample rate from DB)
            '-f', 's16le', '-ar', sampleRate, '-ac', '2', '-i', 'pipe:0',

            // Audio processing kept light for CPU; keep basic HP/LP filtering
            // Increase loudness and add a simple compressor + limiter to reduce clipping
            // '-af', 'highpass=f=80,lowpass=f=15000,acompressor=threshold=-12dB:ratio=2:attack=5:release=50,volume=3.5,alimiter=limit=0.95',
            '-af', 'highpass=f=100,lowpass=f=12000,afftdn,agate=threshold=0.02:ratio=2:attack=5:release=80,acompressor=threshold=-18dB:ratio=2:attack=6:release=90,volume=3.0,alimiter=limit=0.97',

            // Encoder: MP3 CBR 128k (sample rate from DB) stereo
            '-c:a', 'libmp3lame', '-b:a', '128k', '-ar', sampleRate, '-ac', '2',
            // Low latency mux/IO
            '-write_xing', '0', '-id3v2_version', '0',
            '-flush_packets', '1',
            '-max_interleave_delta', '0',
            '-muxpreload', '0',
            '-muxdelay', '0',
            // HTTP/Icecast output meta
            '-content_type', 'audio/mpeg',
            '-f', 'mp3', icecastUrl,
        ];

        ffmpegProcess = spawn('ffmpeg', ffArgs, { 
            stdio: ['pipe', 'ignore', 'pipe']
        });
        
        wireChildLogging(ffmpegProcess, 'ffmpeg-mic');

        let bytesReceived = 0;
        let lastLog = Date.now();
        // backpressure coordination to avoid node buffering
        const netSocket = ws && ws._socket && typeof ws._socket.pause === 'function' ? ws._socket : null;
        let wsPausedForBackpressure = false;

        if (ffmpegProcess.stdin) {
            ffmpegProcess.stdin.on('drain', () => {
                if (wsPausedForBackpressure && netSocket && typeof netSocket.resume === 'function') {
                    wsPausedForBackpressure = false;
                    try { netSocket.resume(); } catch {}
                }
            });
        }

        ws.on('message', (msg) => {
            if (!ffmpegProcess || ffmpegProcess.exitCode !== null || !Buffer.isBuffer(msg)) return;
            
            try {
                const canWrite = ffmpegProcess.stdin.write(msg);
                if (!canWrite && netSocket && typeof netSocket.pause === 'function') {
                    // Apply backpressure to the incoming socket briefly
                    try { netSocket.pause(); wsPausedForBackpressure = true; } catch {}
                }
                bytesReceived += msg.length;
                
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

        const cleanup = async () => {
            console.log("🔌 Mic disconnected");
            try { 
                if (ffmpegProcess?.stdin && !ffmpegProcess.stdin.destroyed) {
                    ffmpegProcess.stdin.end();
                }
            } catch { }
            
            await sleep(200);
            // Only stop the mic stream; do not alter playback_mode or other streams.
            if (ffmpegProcess && currentStreamUrl === 'flutter-mic') {
                await stopProcess(ffmpegProcess);
                ffmpegProcess = null;
                currentStreamUrl = null;
                // preserve paused state
                emitStatus({ event: 'mic-stopped' });
            }
            
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
            // Do not change activeMode/playback_mode here.
        });

        currentStreamUrl = "flutter-mic";
        // Do not set activeMode to 'mic'; keep playback_mode unchanged.
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
    
    // Only stop mic ffmpeg if it's the active mic stream; do not modify playback_mode.
    if (ffmpegProcess && currentStreamUrl === 'flutter-mic') {
        await stopProcess(ffmpegProcess);
        ffmpegProcess = null;
        currentStreamUrl = null;
        // preserve paused state
        bus.emit('status', { event: 'mic-stopped' });
    }
}

module.exports = {
    getStatus,
    startMicStream,
    stopMicStream,
    startLocalFile,
    startYoutubeUrl,
    playPlaylist,
    stop,
    nextTrack,
    prevTrack,
    pause,
    resume,
    stopAll,

    _internals: { isAlive: (p) => isAlive(p) }
};