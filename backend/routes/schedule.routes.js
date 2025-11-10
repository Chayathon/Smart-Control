const router = require("express").Router();
const ctrl = require("../controllers/schedule.controller");
const { authenticateToken } = require("../middleware/auth");

router.get("/", authenticateToken, ctrl.getSchedules);
router.post("/save", authenticateToken, ctrl.saveSchedule);
router.put("/change-status", authenticateToken, ctrl.changeScheduleStatus);

module.exports = router;