const Song = require('../models/Song');
const path = require('path');
const fs = require('fs');

async function getSongList() {
    return await Song.find().sort({ no: 1 }).lean();
}

async function uploadSongFile(file, filename) {
    const savedFileName = path.basename(file.filename, '.mp3');

    const song = new Song({
        name: filename || file.originalname.replace(/\.mp3$/i, ''),
        url: file.filename
    });
    await song.save();

    return savedFileName;
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

module.exports = { getSongList, uploadSongFile, uploadSongYT, deleteSong };