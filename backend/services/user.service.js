const User = require("../models/User")
const argon2 = require('argon2');
const jwt = require('jsonwebtoken');

async function registerUser(username, password) {
    const findUser = await User.findOne({ username })

    if (findUser) {
        return "มีผู้ใช้งานนี้แล้ว"
    }

    const hash = await argon2.hash(password);
    const newUser = new User({
        username,
        password: hash
    })

    await newUser.save()

    return "สมัครสมาชิกสำเร็จ"
}

async function loginUser(username, password) {
    const findUser = await User.findOne({ username })

    if (!findUser) {
        return "ไม่พบผู้ใช้งาน"
    }

    const checkPassword = await argon2.verify(findUser.password, password)

    if (!checkPassword) {
        return { error: true, message: "รหัสผ่านไม่ถูกต้อง" };
    }

    const accessToken = jwt.sign(
        { userId: findUser._id, username: findUser.username },
        process.env.ACCESS_TOKEN_SECRET,
        { expiresIn: "15m" }
    );

    const refreshToken = jwt.sign(
        { userId: findUser._id, username: findUser.username },
        process.env.REFRESH_TOKEN_SECRET,
        { expiresIn: "7d" }
    );

    // Allow multiple sessions per user. Keep backward compat with existing field.
    try {
        if (!Array.isArray(findUser.refreshTokens)) {
            findUser.refreshTokens = [];
        }
        findUser.refreshTokens.push(refreshToken);
        // Optionally limit number of concurrent sessions (keep latest 5)
        if (findUser.refreshTokens.length > 5) {
            findUser.refreshTokens = findUser.refreshTokens.slice(-5);
        }
        // Clear legacy single refreshToken if present but not in list
        if (findUser.refreshToken && !findUser.refreshTokens.includes(findUser.refreshToken)) {
            findUser.refreshTokens.push(findUser.refreshToken);
        }
        findUser.refreshToken = undefined;
    } catch (_) {
        // Fallback: legacy behavior
        findUser.refreshToken = refreshToken;
    }

    await findUser.save();



    return {
        message: "เข้าสู่ระบบสำเร็จ",
        accessToken,
        refreshToken,
        username: findUser.username
    };
}

module.exports = {
    registerUser,
    loginUser
};