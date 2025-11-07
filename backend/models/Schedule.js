const mongoose = require('mongoose');

const scheduleSchema = new mongoose.Schema(
    {
        id_song: { type: mongoose.Schema.Types.ObjectId, ref: 'Song', required: true },
        days_of_week: { type: [Number], required: true },
        time: { type: String, required: true },
        description: { type: String },
        is_active: { type: Boolean, default: true },
    },
    { timestamps: true }
);

module.exports = mongoose.model('Schedule', scheduleSchema);