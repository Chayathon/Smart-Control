const { spawn } = require('child_process');
const cfg = require('../config/config');
const bus = require('./bus');
const Device = require('../models/Device');
const settingsService = require('./settings.service');

/**
 * MicStreamHandler - Handles microphone streaming with optimized FFmpeg pipeline
 * Designed for Raspberry Pi 4 with configurable DSP quality levels
 */
class MicStreamHandler {
    constructor() {
        this.activeWs = null;
        this.ffmpegProcess = null;
        this.starting = false;
        this.stopping = false;
        
        // Settings cache (60 second TTL)
        this.settingsCache = null;
        this.settingsCacheTime = 0;
        this.CACHE_TTL_MS = 60000;
    }

    /**
     * Check if mic is currently active
     */
    isActive() {
        return this.activeWs && this.activeWs.readyState === 1;
    }

    /**
     * Load settings from DB with caching
     */
    async _loadSettings() {
        const now = Date.now();
        
        // Return cached settings if valid
        if (this.settingsCache && (now - this.settingsCacheTime) < this.CACHE_TTL_MS) {
            return this.settingsCache;
        }

        try {
            const [sampleRate, micVolume] = await Promise.all([
                settingsService.getSetting('sampleRate').catch(() => 44100),
                settingsService.getSetting('micVolume').catch(() => 1.5),
            ]);

            this.settingsCache = {
                sampleRate: parseInt(sampleRate) || 44100,
                micVolume: parseFloat(micVolume) || 1.5,
            };
            this.settingsCacheTime = now;

            console.log('🎵 Loaded mic settings:', this.settingsCache);
            return this.settingsCache;
        } catch (error) {
            console.error('⚠️ Failed to load settings, using defaults:', error.message);
            return {
                sampleRate: 44100,
                micVolume: 1.5,
            };
        }
    }

    /**
     * Build FFmpeg filter chain
     */
    _buildFilterChain(settings) {
        const filters = [
            'highpass=f=80',        // ลดเสียงต่ำที่ไม่ต้องการ (เดิม 100Hz)
            'lowpass=f=15000',      // เพิ่มความถี่สูงเพื่อความชัดเจน (เดิม 12000Hz)
            'afftdn=nr=15:nf=-30',  // เพิ่ม noise reduction สูงขึ้นเพื่อลดเสียงสะท้อน (เดิม nr=10:nf=-25)
            'agate=threshold=0.1:ratio=3:attack=5:release=80', // ลด threshold เพื่อรับเสียงที่เบาขึ้น (เดิม 0.02)
            'acompressor=threshold=-16dB:ratio=6:attack=10:release=80:makeup=6dB', // เพิ่ม compression และ makeup gain
            `volume=${settings.micVolume * 1.5}`, // เพิ่ม volume multiplier (x1.5)
            'alimiter=limit=0.99:attack=3:release=40', // ปรับ limiter ให้รับเสียงดังขึ้น
        ];
        
        return filters.join(',');
    }

    /**
     * Get Icecast URL from config
     */
    _getIcecastUrl() {
        const { icecast } = cfg;
        return `icecast://${icecast.username}:${icecast.password}` +
            `@${icecast.host}:${icecast.port}${icecast.mount}`;
    }

    /**
     * Check if streaming is enabled in any device
     */
    async _checkStreamEnabled() {
        try {
            const devices = await Device.find({ 'status.stream_enabled': true }).limit(1).lean();
            return devices.length > 0;
        } catch (error) {
            console.error('⚠️ Error checking stream status:', error.message);
            return false;
        }
    }

    /**
     * Spawn FFmpeg process with optimized settings
     */
    _spawnFfmpeg(settings) {
        const filterChain = this._buildFilterChain(settings);
        const icecastUrl = this._getIcecastUrl();

        const args = [
            '-hide_banner',
            '-loglevel', 'error',
            '-nostdin',
            
            // Low-latency flags
            '-fflags', '+nobuffer',
            '-flags', 'low_delay',
            '-flush_packets', '1',
            
            // Input: PCM from stdin
            '-f', 's16le',
            '-ar', String(settings.sampleRate),
            '-ac', '2',
            '-thread_queue_size', '512',
            '-i', 'pipe:0',
            
            // Audio filter chain
            '-af', filterChain,
            
            // Output: MP3 to Icecast
            '-c:a', 'libmp3lame',
            '-b:a', '128k',
            '-ar', String(settings.sampleRate),
            '-ac', '2',
            '-content_type', 'audio/mpeg',
            '-f', 'mp3',
            icecastUrl,
        ];

        const proc = spawn('ffmpeg', args, { stdio: ['pipe', 'ignore', 'pipe'] });
        
        // Attach logging
        this._wireChildLogging(proc, 'ffmpeg-mic');
        
        return proc;
    }

    /**
     * Wire child process logging
     */
    _wireChildLogging(child, tag) {
        if (child.stderr) {
            child.stderr.on('data', (data) => {
                const msg = data.toString().trim();
                if (msg) console.error(`[${tag}] ${msg}`);
            });
        }
        child.on('error', (err) => console.error(`[${tag}] process error:`, err.message));
        child.on('exit', (code, signal) => {
            if (code !== 0 && code !== null) {
                console.warn(`[${tag}] exited with code ${code}, signal ${signal}`);
            }
        });
    }

    /**
     * Handle WebSocket data with backpressure management
     */
    _setupWebSocketHandler(ws) {
        let paused = false;

        ws.on('message', (data) => {
            if (!this.ffmpegProcess || this.ffmpegProcess.exitCode !== null) {
                return;
            }

            const canWrite = this.ffmpegProcess.stdin.write(data);
            
            // Backpressure: pause WebSocket if FFmpeg buffer is full
            if (!canWrite && !paused) {
                paused = true;
                ws.pause();
                console.log('⏸️ FFmpeg buffer full, pausing WebSocket');
                
                this.ffmpegProcess.stdin.once('drain', () => {
                    if (ws.readyState === 1) {
                        paused = false;
                        ws.resume();
                        console.log('▶️ FFmpeg buffer drained, resuming WebSocket');
                    }
                });
            }
        });

        ws.on('close', (code, reason) => {
            console.log(`🔌 WebSocket closed: code=${code}, reason=${reason || 'none'}`);
            this.stop().catch(err => console.error('Error stopping mic on ws close:', err));
        });

        ws.on('error', (err) => {
            console.error('⚠️ WebSocket error:', err.message);
        });
    }

    /**
     * Start microphone streaming
     * @param {WebSocket} ws - WebSocket connection from Flutter client
     */
    async start(ws) {
        // Prevent concurrent starts
        while (this.starting) {
            await new Promise(resolve => setTimeout(resolve, 50));
        }

        if (this.isActive()) {
            console.log('⚠️ Mic already active, rejecting new connection');
            try {
                ws.close(1008, 'Mic already active');
            } catch (e) {}
            return { success: false, message: 'Microphone is already active' };
        }

        this.starting = true;
        console.log('🎤 Starting microphone stream...');

        try {
            // 1. Check if streaming is enabled
            const streamEnabled = await this._checkStreamEnabled();
            if (!streamEnabled) {
                try {
                    ws.close(1008, 'Stream disabled');
                } catch (e) {}
                return { success: false, message: 'Stream is disabled in all devices' };
            }

            // 2. Stop schedule if active (mic has priority)
            const scheduler = require('./scheduler.service');
            if (scheduler && typeof scheduler.stopSchedule === 'function') {
                console.log('⏹️ Stopping schedule for mic priority...');
                await scheduler.stopSchedule();
                await new Promise(resolve => setTimeout(resolve, 8000));
            }

            // 3. Load settings (cached)
            const settings = await this._loadSettings();

            // 4. Spawn FFmpeg process
            this.ffmpegProcess = this._spawnFfmpeg(settings);
            this.activeWs = ws;

            // 5. Setup WebSocket handlers
            this._setupWebSocketHandler(ws);

            // 6. Handle FFmpeg exit
            this.ffmpegProcess.on('exit', (code, signal) => {
                console.log(`🛑 FFmpeg exited: code=${code}, signal=${signal}`);
                if (code !== 0 && code !== null && !this.stopping) {
                    console.error('⚠️ FFmpeg crashed unexpectedly');
                    bus.emit('status', {
                        event: 'mic-error',
                        error: 'FFmpeg process crashed',
                        code,
                        signal,
                    });
                }
                this.activeWs = null;
                this.ffmpegProcess = null;
            });

            // 7. Emit status
            bus.emit('status', {
                event: 'mic-started',
                mode: 'mic',
                currentUrl: 'flutter-mic',
                activeMode: 'mic',
                isPlaying: true,
                isPaused: false,
                settings: {
                    sampleRate: settings.sampleRate,
                    volume: settings.micVolume,
                },
            });

            console.log('✅ Microphone stream started successfully');
            return { success: true, message: 'Microphone stream started' };

        } catch (error) {
            console.error('❌ Failed to start mic stream:', error);
            
            // Cleanup on error
            if (this.ffmpegProcess) {
                try {
                    this.ffmpegProcess.kill('SIGTERM');
                } catch (e) {}
                this.ffmpegProcess = null;
            }
            
            if (ws.readyState === 1) {
                try {
                    ws.close(1011, 'Internal error');
                } catch (e) {}
            }
            
            this.activeWs = null;
            
            return { success: false, message: error.message };
        } finally {
            this.starting = false;
        }
    }

    /**
     * Stop microphone streaming
     */
    async stop() {
        if (this.stopping) {
            console.log('⏳ Already stopping mic...');
            return { success: true, message: 'Already stopping' };
        }

        if (!this.activeWs && !this.ffmpegProcess) {
            console.log('ℹ️ Mic not active, nothing to stop');
            return { success: true, message: 'Mic not active' };
        }

        this.stopping = true;
        console.log('🛑 Stopping microphone stream...');

        try {
            // Close WebSocket
            if (this.activeWs && this.activeWs.readyState === 1) {
                try {
                    this.activeWs.close(1000, 'Stopped by server');
                } catch (e) {
                    console.warn('Failed to close WebSocket:', e.message);
                }
            }

            // Stop FFmpeg
            if (this.ffmpegProcess && this.ffmpegProcess.exitCode === null) {
                await this._stopProcess(this.ffmpegProcess, 800);
            }

            // Emit status
            bus.emit('status', {
                event: 'mic-stopped',
                mode: 'none',
                activeMode: 'none',
                isPlaying: false,
                isPaused: false,
            });

            console.log('✅ Microphone stream stopped');
            return { success: true, message: 'Microphone stream stopped' };

        } catch (error) {
            console.error('⚠️ Error stopping mic:', error);
            return { success: false, message: error.message };
        } finally {
            this.activeWs = null;
            this.ffmpegProcess = null;
            this.stopping = false;
        }
    }

    /**
     * Gracefully stop a process
     */
    async _stopProcess(proc, timeoutMs = 1500) {
        if (!proc || proc.exitCode !== null) return;

        return new Promise((resolve) => {
            const timer = setTimeout(() => {
                if (proc.exitCode === null) {
                    console.warn('⚠️ Process did not exit, force killing...');
                    try {
                        proc.kill('SIGKILL');
                    } catch (e) {}
                }
                resolve();
            }, timeoutMs);

            proc.once('exit', () => {
                clearTimeout(timer);
                resolve();
            });

            try {
                if (proc.stdin && !proc.stdin.destroyed) {
                    proc.stdin.end();
                }
                proc.kill('SIGTERM');
            } catch (e) {
                console.warn('Error sending SIGTERM:', e.message);
            }
        });
    }

    /**
     * Get current mic status
     */
    getStatus() {
        return {
            active: this.isActive(),
            starting: this.starting,
            stopping: this.stopping,
            settings: this.settingsCache,
        };
    }

    /**
     * Clear settings cache (useful when settings are updated)
     */
    clearCache() {
        this.settingsCache = null;
        this.settingsCacheTime = 0;
        console.log('🗑️ Mic settings cache cleared');
    }
}

// Export singleton instance
const micStreamHandler = new MicStreamHandler();

module.exports = {
    start: (ws) => micStreamHandler.start(ws),
    stop: () => micStreamHandler.stop(),
    isActive: () => micStreamHandler.isActive(),
    getStatus: () => micStreamHandler.getStatus(),
    clearCache: () => micStreamHandler.clearCache(),
    
    // For testing
    _instance: micStreamHandler,
};
