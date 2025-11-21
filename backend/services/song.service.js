const Song = require('../models/Song');
const Playlist = require('../models/Playlist');

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const multer = require('multer');
const { json } = require('body-parser');

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

function checkNameExists(name, excludeId = null) {
  const query = { name: name };

  if (excludeId) {
    query._id = { $ne: excludeId };
  }

  return Song.exists(query);
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
    return await Song.find().sort({ name: 1 }).lean();
}

async function getSongById(id) {
  try {
    const song = await Song.findById(id).lean();
    return song;
  } catch (error) {
    return error;
  }
}

async function getSongExceptInPlaylist() {
    const playlistSongs = await Playlist.find().distinct('id_song');
    return await Song.find({ _id: { $nin: playlistSongs } }).sort({ no: 1 }).lean();
}

async function uploadSongFile(file, filename) {
  const safeDisplayName = sanitizeBaseName(filename || path.parse(file.originalname).name);
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

async function updateSongName(id, newName) {
  try {
    const isPlaylisted = await Playlist.exists({ id_song: id });

    if (isPlaylisted) {
      const err = new Error('ไม่สามารถแก้ไขชื่อเพลงนี้ได้ เนื่องจากมีการใช้งานในเพลย์ลิสต์');
      err.status = 400;
      throw err;
    }

    // Load the existing song to get the current filename
    const song = await Song.findById(id);
    if (!song) {
      const err = new Error('ไม่พบเพลงที่ระบุ');
      err.status = 404;
      throw err;
    }
    if (song.name === newName) {
      const err = new Error('ไม่พบการเปลี่ยนแปลงชื่อเพลง');
      err.status = 400;
      throw err;
    }

    const unique = Math.random().toString(36).slice(2);
    const safeName = sanitizeBaseName(newName);
    const newUrl = `${safeName}-${unique}.mp3`;
    const oldUrl = song.url;

    const oldPath = path.join(UPLOAD_DIR, oldUrl || '');
    const newPath = path.join(UPLOAD_DIR, newUrl);

    // Rename on disk first (if the source file exists and names differ)
    try {
      if (oldUrl && oldUrl !== newUrl && fs.existsSync(oldPath)) {
        // use promise API so we can await
        await fs.promises.rename(oldPath, newPath);
      } else if (oldUrl && !fs.existsSync(oldPath)) {
        console.warn('Old file not found, will update DB anyway:', oldPath);
      }
    } catch (err) {
      console.error('Error renaming file:', err);
      const e = new Error('ไม่สามารถเปลี่ยนชื่อเพลงได้');
      e.status = 500;
      throw e;
    }

    // Update DB to point to the new filename
    const updated = await Song.findByIdAndUpdate(
      id,
      { name: safeName, url: newUrl },
      { new: true, runValidators: true }
    );

    return updated;
  } catch (error) {
    throw error;
  }
}

async function deleteSong(id) {
  const isPlaylisted = await Playlist.exists({ id_song: id });

  if (isPlaylisted) {
    const err = new Error('ไม่สามารถลบเพลงนี้ได้ เนื่องจากมีการใช้งานในเพลย์ลิสต์');
    err.status = 400;
    throw err;
  }

  const song = await Song.findById(id);
  if (!song) return;

  const filePath = path.join(UPLOAD_DIR, song.url);
  await Song.findByIdAndDelete(id);

  fs.unlink(filePath, err => {
    if (err) console.error('Error deleting file:', err);
  });
}

module.exports = {
    upload, UPLOAD_DIR,
    checkNameExists,
    getSongList,
    getSongById,
    getSongExceptInPlaylist,
    uploadSongFile,
    uploadSongYT,
    updateSongName,
    deleteSong
};
