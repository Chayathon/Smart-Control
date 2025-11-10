const router = require("express").Router();
const ctrl = require("../controllers/schedule.controller");
const { authenticateToken } = require("../middleware/auth");

router.get("/", authenticateToken, ctrl.getSchedules);
router.get("/:id", authenticateToken, ctrl.getScheduleById);
router.post("/save", authenticateToken, ctrl.saveSchedule);
router.put("/update/:id", authenticateToken, ctrl.updateSchedule);
router.patch("/change-status/:id", authenticateToken, ctrl.changeScheduleStatus);
router.delete("/delete/:id", authenticateToken, ctrl.deleteSchedule);

module.exports = router;