// services/uart.handle.js
const { SerialPort } = require('serialport');
const EventEmitter = require('events');

console.log('[UART] uart.handle.js loaded');

// ====== ค่า UART จาก .env (แมปจาก config.py เดิม) ======
const UART_PORT = process.env.UART_PORT || '/dev/ttyUSB0';
const UART_BAUDRATE = parseInt(process.env.UART_BAUDRATE || '9600', 10);
const UART_TIMEOUT = parseInt(process.env.UART_TIMEOUT || '3', 10); // ยังไม่ได้ใช้ตรง ๆ

const UART_XONXOFF = (process.env.UART_XONXOFF || 'false') === 'true';
const UART_RTSCTS = (process.env.UART_RTSCTS || 'false') === 'true';
const UART_DSRDTR = (process.env.UART_DSRDTR || 'false') === 'true';

const UART_BYTESIZE = parseInt(process.env.UART_BYTESIZE || '8', 10); // 5/6/7/8
const UART_PARITY = (process.env.UART_PARITY || 'N').toUpperCase();   // N/E/O/M/S
const UART_STOPBITS = parseFloat(process.env.UART_STOPBITS || '1');   // 1 / 1.5 / 2

const UART_FRAME_DELIMITER = process.env.UART_FRAME_DELIMITER || '';  // None -> ว่าง
const UART_IDLE_FLUSH_MS = parseInt(process.env.UART_IDLE_FLUSH_MS || '60', 10);

console.log('[UART] CONFIG:', {
  UART_PORT,
  UART_BAUDRATE,
  UART_BYTESIZE,
  UART_PARITY,
  UART_STOPBITS,
  UART_FRAME_DELIMITER,
  UART_IDLE_FLUSH_MS,
});

const emitter = new EventEmitter();

let port = null;
let isOpening = false;
let rxBuffer = Buffer.alloc(0);
let lastRx = Date.now();
const delim = UART_FRAME_DELIMITER
  ? Buffer.from(UART_FRAME_DELIMITER, 'utf-8')
  : null;

// timer สำหรับ idle flush (แบบไม่มี delimiter)
let idleFlushTimer = null;

// ใช้กันยิงซ้ำคำสั่งเดิมภายในช่วงเวลาสั้น ๆ
let lastWriteBuf = null;
let lastWriteTs = 0;

// แปลง config เป็น options ของ serialport
function getSerialOptions() {
  const parityMap = {
    N: 'none',
    E: 'even',
    O: 'odd',
    M: 'mark',
    S: 'space',
  };

  let stopBits = 1;
  if (UART_STOPBITS === 1.5) stopBits = 1.5;
  else if (UART_STOPBITS === 2) stopBits = 2;

  return {
    path: UART_PORT,
    baudRate: UART_BAUDRATE,
    dataBits: UART_BYTESIZE,
    parity: parityMap[UART_PARITY] || 'none',
    stopBits: stopBits,
    autoOpen: true,          // เปิดเองอัตโนมัติ
    xoff: UART_XONXOFF,
    xon: UART_XONXOFF,
    rtscts: UART_RTSCTS,
  };
}

// เปิดพอร์ต
async function openPort() {
  console.log('[UART] openPort() called, current port:', !!port, 'isOpening:', isOpening);

  if (port && port.isOpen) {
    console.log('[UART] port already open');
    return true;
  }
  if (isOpening) {
    console.log('[UART] already opening, skip');
    return false;
  }

  isOpening = true;

  return new Promise((resolve) => {
    const opts = getSerialOptions();
    console.log('[UART] Creating SerialPort with opts:', opts);

    let sp;
    try {
      sp = new SerialPort(opts); // autoOpen: true
    } catch (e) {
      console.error('[UART] ❌ Error creating SerialPort:', e.message);
      port = null;
      isOpening = false;
      return resolve(false);
    }

    // เก็บตัวที่เพิ่งสร้างไว้เป็น current port
    port = sp;

    let resolved = false;
    const done = (ok) => {
      if (resolved) return;
      resolved = true;
      isOpening = false;
      resolve(ok);
    };

    sp.once('open', () => {
      console.log(
        `[UART] ✅ OPEN event for ${UART_PORT} @ ${UART_BAUDRATE} (parity=${UART_PARITY}, stop=${UART_STOPBITS})`
      );

      try {
        sp.flush();
      } catch (e) {
        console.warn('[UART] flush error (ignored):', e.message);
      }

      setupPortEvents(sp);
      done(true);
    });

    sp.once('error', (err) => {
      console.error('[UART] ❌ ERROR event while opening:', err.message);
      try {
        sp.close();
      } catch (_) {}
      // ถ้า error นี้มาจากตัวที่เป็น current port อยู่ → เคลียร์ทิ้ง
      if (port === sp) {
        port = null;
      }
      done(false);
    });

    // กันกรณี driver แปลก ๆ ไม่มีทั้ง open/error
    setTimeout(() => {
      if (!resolved) {
        console.error('[UART] ❌ openPort timeout: no open/error event in 3s');
        try {
          sp && sp.close();
        } catch (_) {}
        if (port === sp) {
          port = null;
        }
        isOpening = false;
        resolve(false);
      }
    }, 3000);
  });
}

function setupPortEvents(sp) {
  if (!sp) {
    console.warn('[UART] setupPortEvents() called with null port');
    return;
  }

  console.log('[UART] setupPortEvents()');

  sp.removeAllListeners('data');
  sp.removeAllListeners('close');
  sp.removeAllListeners('error');

  sp.on('data', (chunk) => {
    rxBuffer = Buffer.concat([rxBuffer, chunk]);
    lastRx = Date.now();
    console.log('[UART] RX <-', chunk.toString('ascii'));

    if (delim) {
      while (true) {
        const idx = rxBuffer.indexOf(delim);
        if (idx === -1) break;

        const frame = rxBuffer.slice(0, idx); // ไม่รวม delimiter
        rxBuffer = rxBuffer.slice(idx + delim.length);

        if (frame.length > 0) {
          emitter.emit('frame', frame);
        }
      }
    }
  });

  sp.on('error', (err) => {
    console.error('[UART] error (after open):', err.message);
  });

  sp.on('close', () => {
    console.warn('[UART] port closed.');
    if (idleFlushTimer) {
      clearInterval(idleFlushTimer);
      idleFlushTimer = null;
    }
    if (port === sp) {
      port = null;
    }
    // ❌ ตัด auto-reopen ที่นี่ทิ้ง แล้วให้ openPort() เป็นตัวตัดสิน
  });

  // idle flush กรณีไม่มี delimiter
  if (!delim) {
    if (idleFlushTimer) {
      clearInterval(idleFlushTimer);
      idleFlushTimer = null;
    }

    idleFlushTimer = setInterval(() => {
      if (
        rxBuffer.length > 0 &&
        Date.now() - lastRx >= UART_IDLE_FLUSH_MS
      ) {
        const frame = rxBuffer;
        rxBuffer = Buffer.alloc(0);
        emitter.emit('frame', frame);
      }
    }, 10);
  }
}

// public: initialize
async function initialize() {
  console.log('[UART] initialize() called');
  const ok = await openPort();
  console.log('[UART] initialize() done, ok =', ok);
  return ok;
}

function registerRxCallback(cb) {
  console.log('[UART] registerRxCallback()');
  emitter.removeAllListeners('frame');
  if (typeof cb === 'function') {
    emitter.on('frame', cb);
  }
}

// ====== writeRaw / writeString ======
async function writeRaw(buffer) {
  console.log('[UART] writeRaw() called with', buffer.length, 'bytes');

  if (!Buffer.isBuffer(buffer)) {
    throw new TypeError('writeRaw payload must be Buffer');
  }

  const now = Date.now();

  // กันยิงซ้ำภายใน 300ms
  if (
    lastWriteBuf &&
    (now - lastWriteTs) < 300 &&
    lastWriteBuf.length === buffer.length &&
    lastWriteBuf.equals(buffer)
  ) {
    console.log('[UART] ⚠️ skip duplicate TX within 300ms:', buffer.toString('ascii'));
    return buffer.length;
  }

  const ok = await openPort();
  if (!ok || !port) {
    console.error('[UART] writeRaw(): port not open');
    return 0;
  }

  const sp = port;

  return new Promise((resolve) => {
    sp.write(buffer, (err) => {
      if (err) {
        console.error('[UART] write error:', err.message);
        try {
          sp.close();
        } catch (_) {}
        if (port === sp) {
          port = null;
        }
        return resolve(0);
      }

      sp.drain((err2) => {
        if (err2) {
          console.error('[UART] drain error:', err2.message);
          return resolve(0);
        }

        lastWriteBuf = Buffer.from(buffer); // clone
        lastWriteTs = Date.now();

        console.log('[UART] TX ->', buffer.toString('ascii'));
        resolve(buffer.length);
      });
    });
  });
}

async function writeString(str, encoding = 'ascii') {
  console.log('[UART] writeString() called with:', str);
  const buf = Buffer.from(str, encoding);
  return writeRaw(buf);
}

module.exports = {
  initialize,
  registerRxCallback,
  writeRaw,
  writeString,
};
