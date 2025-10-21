const Song = require('../models/Song');

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const multer = require('multer');

// -------- Utils --------
function ensureDir(dir) {
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function sanitizeBaseName(input) {
    const trimmed = (input || '').toString().trim();
    const cleaned = trimmed.replace(/[^a-zA-Z0-9ก-๙\-_ ]/g, '');
    return cleaned.length ? cleaned : `song-${Date.now()}`;
}

// promise wrapper สำหรับคำสั่ง CLI
function runCmd(cmd, args, opts = {}) {
    return new Promise((resolve, reject) => {
        const p = spawn(cmd, args, { stdio: ['ignore', 'pipe', 'pipe'], ...opts });
        let stdout = '';
        let stderr = '';
        p.stdout.on('data', d => (stdout += d.toString()));
        p.stderr.on('data', d => (stderr += d.toString()));
        p.on('error', reject);
        p.on('close', code => (code === 0 ? resolve({ stdout, stderr }) : reject(new Error(stderr || `Exit ${code}`))));
    });
}

const UPLOAD_DIR = path.join(__dirname, '../uploads');
ensureDir(UPLOAD_DIR);

const storage = multer.diskStorage({
    destination: (_, __, cb) => cb(null, UPLOAD_DIR),
    filename: (req, file, cb) => {
        const base = sanitizeBaseName(req.body.filename || path.parse(file.originalname).name);
        const unique = Math.random().toString(36).slice(2);
        cb(null, `${base}-${unique}.mp3`); // บังคับ .mp3
    }
});

const fileFilter = (req, file, cb) => {
    const okMime = file.mimetype === 'audio/mpeg' || file.mimetype === 'audio/mp3';
    const ext = path.extname(file.originalname || '').toLowerCase();
    if (okMime && ext === '.mp3') return cb(null, true);
    return cb(new Error('Only MP3 files are allowed!'), false);
};

const upload = multer({ storage, fileFilter, limits: { fileSize: 10 * 1024 * 1024 } });

async function getSongList() {
    return await Song.find().sort({ no: 1 }).lean();
}

async function uploadSongFile(file, givenName) {
  const safeDisplayName = sanitizeBaseName(givenName || path.parse(file.originalname).name);
  const fileNameOnDisk = file.filename;
  const urlPath = `/uploads/${fileNameOnDisk}`;

  const doc = new Song({ name: safeDisplayName, url: fileNameOnDisk });
  await doc.save();

  return { id: doc._id, name: doc.name, fileName: fileNameOnDisk, url: urlPath };
}

async function uploadSongYT(youtubeUrl, filename) {
  // ตั้งค่า
  const safeBase = sanitizeBaseName(filename);
  const unique = Math.random().toString(36).slice(2);
  const outputName = `${safeBase}-${unique}.mp3`;
  const outputPath = path.join(UPLOAD_DIR, outputName);

  // ไฟล์ชั่วคราว (m4a / opus แล้วแต่ source)
  const tmpBase = `tmp-${Date.now()}-${Math.random().toString(36).slice(2)}`;
  const tmpAudio = path.join(UPLOAD_DIR, `${tmpBase}.m4a`);

  const MAX_DURATION_SEC = 10 * 60;

  // ดึงเมตาดาต้า (เอา title ถ้าไม่ได้ส่ง filename)
  let title = safeBase;

  if (!filename) {
    const { stdout: metaOut } = await runCmd('yt-dlp', ['--no-warnings', '--print', '%(title)s', youtubeUrl]);
    title = sanitizeBaseName(metaOut.split('\n')[0] || safeBase);
  }

  // ดาวน์โหลดเสียงด้วย yt-dlp (บังคับ bestaudio เฉพาะเสียง)
  const ytdlpArgs = [
    '-f', 'bestaudio[ext=m4a]/bestaudio/bestaudio*', // พยายาม m4a ก่อน
    '-x', '--audio-format', 'm4a',
    '--no-playlist',
    '--no-warnings',
    '--force-overwrites',
    '-N', '1',
    '--max-filesize', '200M',
    '--match-filter', `duration <= ${MAX_DURATION_SEC}`,
    '-o', tmpAudio,
    youtubeUrl
  ];
  await runCmd('yt-dlp', ytdlpArgs);

  // แปลงเป็น MP3 ด้วย ffmpeg
  await runCmd('ffmpeg', [
    '-y',
    '-i', tmpAudio,
    '-vn',
    '-acodec', 'libmp3lame',
    '-b:a', '192k',
    outputPath
  ]);

  // ลบไฟล์ชั่วคราว
  try { fs.unlinkSync(tmpAudio); } catch (_) {}

  const doc = new Song({
    name: title,
    url: outputName
  });
  await doc.save();

  return {
    id: doc._id.toString(),
    name: doc.name,
    fileName: outputName,
    url: `/uploads/${outputName}`
  };
}

async function deleteSong(id) {
  const doc = await Song.findById(id);
  if (!doc) return;

  const filePath = path.join(UPLOAD_DIR, doc.url);
  await Song.findByIdAndDelete(id);

  fs.unlink(filePath, err => {
    if (err) console.error('Error deleting file:', err);
  });
}

module.exports = {
    upload, UPLOAD_DIR,
    getSongList,
    uploadSongFile,
    uploadSongYT,
    deleteSong
};
