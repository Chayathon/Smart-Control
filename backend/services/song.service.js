const Song = require('../models/Song');
const path = require('path');
const fs = require('fs');
const multer = require('multer')

// ===== Utils =====
function ensureDir(dir) {
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
}

// อนุญาตอักษรไทย/อังกฤษ/ตัวเลข/ขีด/ขีดล่าง/ช่องว่าง
function sanitizeBaseName(input) {
    const trimmed = (input || '').toString().trim();
    const cleaned = trimmed.replace(/[^a-zA-Z0-9ก-๙\-_ ]/g, '');
    // กันกรณีว่างเปล่าหลัง sanitize
    return cleaned.length ? cleaned : `song-${Date.now()}`;
}

const UPLOAD_DIR = path.join(__dirname, '../uploads');
ensureDir(UPLOAD_DIR);

// ===== Multer config =====
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, UPLOAD_DIR);
    },
    filename: function (req, file, cb) {
        const base = sanitizeBaseName(req.body.filename || path.parse(file.originalname).name);
        const unique = Math.random().toString(36).slice(2);
        // บังคับ .mp3 เสมอ
        cb(null, `${base}-${unique}.mp3`);
    }
});

// ยอมรับทั้ง mimetype 'audio/mpeg' และกรณี browser ให้เป็น 'audio/mp3'
const fileFilter = (req, file, cb) => {
    const okMime = file.mimetype === 'audio/mpeg' || file.mimetype === 'audio/mp3';
    const ext = path.extname(file.originalname || '').toLowerCase();
    const okExt = ext === '.mp3';
    if (okMime && okExt) return cb(null, true);
    return cb(new Error('Only MP3 files are allowed!'), false);
};

// จำกัดขนาดไฟล์ (เช่น 25MB) ปรับได้ตามต้องการ
const upload = multer({
    storage,
    fileFilter,
    limits: { fileSize: 25 * 1024 * 1024 }
});

async function getSongList() {
    return await Song.find().sort({ no: 1 }).lean();
}

async function uploadSongFile(file, givenName) {
    const safeDisplayName = sanitizeBaseName(givenName || path.parse(file.originalname).name);
    const fileNameOnDisk = file.filename;
    const urlPath = `/uploads/${fileNameOnDisk}`;

    const doc = new Song({
        name: safeDisplayName,
        url: fileNameOnDisk
    });

    await doc.save();

    return {
        id: doc._id,
        name: doc.name,
        fileName: fileNameOnDisk,
        url: urlPath
    };
}

async function uploadSongYT(youtubeUrl, filename) {
    const uploadDir = path.join(__dirname, '../uploads');
    if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir);

    const safeName = filename
        ? filename.replace(/[^a-zA-Z0-9ก-๙\-_ ]/g, '')
        : `song-${Date.now()}`;

    const outputName = `${safeName}-${Math.random().toString(36).slice(2)}.mp3`;
    const outputPath = path.join(uploadDir, outputName);
    const tempFile = path.join(uploadDir, `temp-${Date.now()}.m4a`);

    await ytdlp(youtubeUrl, {
        output: tempFile,
        extractAudio: true,
        audioFormat: 'm4a',
        audioQuality: 0,
    });

    await new Promise((resolve, reject) => {
        ffmpeg(tempFile)
            .audioCodec('libmp3lame')
            .audioBitrate(192)
            .save(outputPath)
            .on('end', resolve)
            .on('error', reject);
    });

    fs.unlinkSync(tempFile);

    const song = new Song({ name: safeName, url: outputName });
    await song.save();
    return outputName;
}

async function deleteSong(id) {
    try {
        const song = await Song.findById(id);
        if (!song) {
            console.log(`Song with id ${id} not found`);
            return;
        }

        const filePath = path.join(process.cwd(), 'uploads', song.url);

        await Song.findByIdAndDelete(id);
        console.log(`Song with id ${id} deleted from DB`);

        fs.unlink(filePath, (err) => {
            if (err) {
                console.error(`Error deleting file ${filePath}:`, err);
            } else {
                console.log(`File ${filePath} deleted successfully`);
            }
        });

    } catch (error) {
        console.error(`Error deleting song with id ${id}:`, error);
    }
}

module.exports = { upload, UPLOAD_DIR, getSongList, uploadSongFile, uploadSongYT, deleteSong };