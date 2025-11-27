import 'package:flutter/material.dart';

/// ===== ตัวกรองและชนิดอุปกรณ์ =====
/// เก็บ enum เดิมไว้ให้ไฟล์อื่น import ได้เหมือนเดิม
enum TypeFilter { all, lighting, wave, sim }
enum StatusFilter { all, online, offline }
enum MonitoringKind { lighting, wirelessWave, wirelessSim }

typedef Json = Map<String, dynamic>;

/// ===== แผงลิสต์ + ส่วนตัวกรอง (ค่าจริง) =====
class MonitoringListPanel extends StatelessWidget {
  final List<Json> items; // ใช้ Json (ค่าจริง)
  final String? selectedId; // id ของโหนดที่เลือก
  final Color cardBg, border, accent, textColor;
  final ScrollController listController;

  final ValueChanged<Json> onSelectEntry;
  // ยังรับ onToggleLighting ไว้เหมือนเดิมเพื่อไม่ให้ไฟล์อื่น error
  final void Function(Json row, int nextLighting) onToggleLighting;

  // ยังรับ typeFilter / onChangeTypeFilter ไว้เหมือนเดิม
  final TypeFilter typeFilter;
  final ValueChanged<TypeFilter> onChangeTypeFilter;

  final StatusFilter statusFilter;
  final ValueChanged<StatusFilter> onChangeStatusFilter;

  final int totalCount, onlineCount, offlineCount;

  /// helper จากหน้าหลัก
  final MonitoringKind Function(Json row) kindOf;
  final bool Function(Json row) onlineOf;

  const MonitoringListPanel({
    super.key,
    required this.items,
    required this.selectedId,
    required this.cardBg,
    required this.border,
    required this.accent,
    required this.textColor,
    required this.listController,
    required this.onSelectEntry,
    required this.onToggleLighting,
    required this.typeFilter,
    required this.onChangeTypeFilter,
    required this.statusFilter,
    required this.onChangeStatusFilter,
    required this.totalCount,
    required this.onlineCount,
    required this.offlineCount,
    required this.kindOf,
    required this.onlineOf,
  });

  /// ตอนนี้ระบบเหลือแค่ไร้สายแบบซิม → ให้แสดงชื่อระบบเดียว
  String _systemTitle(MonitoringKind k) {
    return 'ระบบไร้สาย (ซิม)';
  }

  String? _idOf(Json row) {
    final meta = row['meta'];
    if (meta is Map) {
      final noMeta = meta['no'];
      if (noMeta is int) {
        return 'no$noMeta';
      }
      if (noMeta is String && noMeta.isNotEmpty) {
        // กรณี backend ส่งมาเป็น "no1"
        return noMeta;
      }
    }

    final rootNo = row['no'];
    if (rootNo is int) {
      return 'no$rootNo';
    }
    if (rootNo is String && rootNo.isNotEmpty) {
      return rootNo;
    }

    return null;
  }

  /// ชื่อที่แสดงในลิสต์
  /// ถ้ามี field name ให้ใช้ name
  /// ถ้าไม่มีก็ใช้เลข no สร้างเป็น "Node <no>"
  String _nameOf(Json row) {
    final name = (row['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;

    dynamic no;
    final meta = row['meta'];
    if (meta is Map && meta['no'] != null) {
      no = meta['no'];
    } else if (row['no'] != null) {
      no = row['no'];
    }

    if (no != null) {
      return 'Node ${no.toString()}';
    }

    // เผื่อกรณีไม่มี no จริง ๆ
    return _idOf(row) ?? '-';
  }

  DateTime? _toDate(dynamic v) {
    try {
      if (v == null) return null;
      if (v is DateTime) return v.toLocal();
      if (v is int) {
        return DateTime.fromMillisecondsSinceEpoch(v).toLocal();
      }
      if (v is String && v.isNotEmpty) return DateTime.parse(v).toLocal();
    } catch (_) {}
    return null;
  }

  String _hhmmss(DateTime dt) {
    final t = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // ===== แถบตัวกรอง (เหลือเฉพาะ All / Online / Offline) =====
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // ตัด TypeDropdown ออกตาม requirement
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      primary: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Status3DButton(
                            type: StatusFilter.all,
                            label: 'All ($totalCount)',
                            selected: statusFilter == StatusFilter.all,
                            onTap: () =>
                                onChangeStatusFilter(StatusFilter.all),
                          ),
                          const SizedBox(width: 8),
                          Status3DButton(
                            type: StatusFilter.online,
                            label: 'Online ($onlineCount)',
                            selected: statusFilter == StatusFilter.online,
                            onTap: () =>
                                onChangeStatusFilter(StatusFilter.online),
                          ),
                          const SizedBox(width: 8),
                          Status3DButton(
                            type: StatusFilter.offline,
                            label: 'Offline ($offlineCount)',
                            selected: statusFilter == StatusFilter.offline,
                            onTap: () =>
                                onChangeStatusFilter(StatusFilter.offline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ===== ลิสต์อุปกรณ์ =====
            Expanded(
              child: Scrollbar(
                controller: listController,
                thumbVisibility: true,
                child: ListView.separated(
                  controller: listController,
                  primary: false,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final row = items[i];
                    final id = _idOf(row);
                    final isSelected =
                        selectedId != null && id == selectedId;

                    final wrap = (Widget child) => GestureDetector(
                          onTap: () => onSelectEntry(row),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: isSelected
                                  ? Colors.blue[50]
                                  : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.blue
                                    : Colors.transparent,
                                width: isSelected ? 1.2 : 0.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.15),
                                        blurRadius: 12,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 4),
                                      )
                                    ]
                                  : [],
                            ),
                            child: child,
                          ),
                        );

                    final k = kindOf(row);
                    final systemTitle = _systemTitle(k);
                    final order = i + 1;

                    // ตอนนี้ทุกอย่างถือเป็นระบบไร้สาย (ซิม) → ใช้ WirelessTile อย่างเดียว
                    return wrap(
                      _WirelessTileReal(
                        row: row,
                        kind: k,
                        order: order,
                        deviceTitle: _nameOf(row),
                        systemTitle: systemTitle,
                        accent: Colors.black87,
                        textColor: Colors.black87,
                        border: border,
                        isOnline: onlineOf(row),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===== ดรอปดาวน์ (ปุ่ม 3D) =====
/// เก็บไว้เฉย ๆ เผื่อไฟล์อื่นใช้ TypeDropdown อยู่ แต่ตอนนี้ไม่ใช้ใน UI แล้ว
class TypeDropdown extends StatelessWidget {
  final TypeFilter value;
  final ValueChanged<TypeFilter> onChanged;
  const TypeDropdown({super.key, required this.value, required this.onChanged});

  String _labelOf(TypeFilter v) {
    switch (v) {
      case TypeFilter.all:
        return 'ทั้งหมด';
      case TypeFilter.lighting:
        return 'ระบบไฟส่องสว่าง';
      case TypeFilter.wave:
        return 'ระบบไร้สายแบบคลื่น';
      case TypeFilter.sim:
        return 'ระบบไร้สายแบบซิม';
    }
  }

  List<PopupMenuEntry<TypeFilter>> _buildItems(double w) {
    const innerLeftText = 10.0;
    const innerRightText = 8.0;
    const v = 10.0;
    const edge = 8.0;

    PopupMenuEntry<TypeFilter> _item(TypeFilter val, String text,
        {double topExtra = 0, double bottomExtra = 0}) {
      return PopupMenuItem(
        value: val,
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: w,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              innerLeftText,
              v + topExtra,
              innerRightText,
              v + bottomExtra,
            ),
            child: Text(text, overflow: TextOverflow.ellipsis),
          ),
        ),
      );
    }

    return [
      _item(TypeFilter.all, 'ทั้งหมด', topExtra: edge),
      _item(TypeFilter.lighting, 'ระบบไฟส่องสว่าง'),
      _item(TypeFilter.wave, 'ระบบไร้สายแบบคลื่น'),
      _item(TypeFilter.sim, 'ระบบไร้สายแบบซิม', bottomExtra: edge),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return _TypeDropdownButton3D(
      label: _labelOf(value),
      onTap: (boxContext) async {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final box = boxContext.findRenderObject() as RenderBox;
          final overlay =
              Overlay.of(boxContext).context.findRenderObject() as RenderBox;
          final offset = box.localToGlobal(Offset.zero, ancestor: overlay);

          final buttonW = box.size.width;
          final menuW = buttonW;
          final left = offset.dx;
          final top = offset.dy + box.size.height + 4.0;
          final right = overlay.size.width - left - menuW;

          final selected = await showMenu<TypeFilter>(
            context: boxContext,
            color: Colors.white,
            elevation: 8,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            position: RelativeRect.fromLTRB(
              left,
              top,
              right,
              overlay.size.height - top,
            ),
            items: _buildItems(menuW),
          );

          if (selected != null) onChanged(selected);
        });
      },
    );
  }
}

/// ปุ่ม 3D ของ dropdown
class _TypeDropdownButton3D extends StatelessWidget {
  final String label;
  final void Function(BuildContext buttonContext) onTap;

  const _TypeDropdownButton3D({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) {
        return InkWell(
          onTap: () => onTap(buttonContext),
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 150, // ปุ่มตัวกรองชนิด
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    offset: Offset(3, 5),
                    blurRadius: 10,
                  ),
                  BoxShadow(
                    color: Color(0x66FFFFFF),
                    offset: Offset(-3, -3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.expand_more, size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ===== ปุ่มสถานะ 3D (เลือกสีตามชนิดสถานะ) =====
class Status3DButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final StatusFilter type; // all / online / offline

  const Status3DButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    Color baseSelected;
    switch (type) {
      case StatusFilter.online:
        baseSelected = Colors.green[600]!;
        break;
      case StatusFilter.offline:
        baseSelected = Colors.red[600]!;
        break;
      case StatusFilter.all:
      default:
        baseSelected = const Color(0xFF48CAE4);
        break;
    }

    final bg = selected ? baseSelected : Colors.white;
    final txt = selected ? Colors.white : Colors.black87;
    final border = selected
        ? baseSelected.withOpacity(.95)
        : Colors.grey[300]!;
    final shadow = selected
        ? <BoxShadow>[
            BoxShadow(
              color: baseSelected.withOpacity(.35),
              offset: const Offset(2, 3),
              blurRadius: 10,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(.55),
              offset: const Offset(-2, -2),
              blurRadius: 6,
            ),
          ]
        : const <BoxShadow>[
            BoxShadow(
              color: Color(0x33000000),
              offset: Offset(3, 5),
              blurRadius: 10,
            ),
            BoxShadow(
              color: Color(0xF2FFFFFF),
              offset: Offset(-3, -3),
              blurRadius: 10,
            ),
          ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
          boxShadow: shadow,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: txt,
          ),
        ),
      ),
    );
  }
}

/// ======================= Wireless Tile (ค่าจริง) =======================
class _WirelessTileReal extends StatelessWidget {
  final Json row;
  final MonitoringKind kind;
  final int order; // เลขลำดับ
  final String deviceTitle; // บรรทัดบนสุด
  final String systemTitle; // ต่อท้ายชื่ออุปกรณ์
  final Color accent, textColor, border;
  final bool isOnline;

  const _WirelessTileReal({
    required this.row,
    required this.kind,
    required this.order,
    required this.deviceTitle,
    required this.systemTitle,
    required this.accent,
    required this.textColor,
    required this.border,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    final lat = row['lat'];
    final lng = row['lng'];
    final ts = row['timestamp'];
    final t = _toDate(ts);
    final timeLabel = t != null ? _hhmmss(t) : '-';

    final rawOat = row['oat'];
    // ถ้า Offline ให้แสดง On Air Target เป็น 0 ทันที
    final oat = isOnline ? rawOat : 0;

    // ✅ AC/DC metrics จาก backend ใหม่
    final vac = row['vac'];
    final iac = row['iac'];
    final wac = row['wac'];
    final acfreq = row['acfreq'];
    final acenergy = row['acenergy'];

    final vdc = row['vdc'];
    final idc = row['idc'];
    final wdc = row['wdc'];

    const vGapBetweenTitleAndBelow = 8.0;

    final titleTextStyle = const TextStyle(
      fontWeight: FontWeight.w900,
      fontSize: 20,
      letterSpacing: .2,
      color: Colors.black87,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // (เลข.) ชื่ออุปกรณ์ | ป้ายระบบ | Online
          Row(
            children: [
              Text('$order.', style: titleTextStyle),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  deviceTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleTextStyle,
                ),
              ),
              const SizedBox(width: 8),
              _SystemPill.familyWirelessOrLighting(
                kind: kind,
                text: systemTitle,
              ),
              const SizedBox(width: 8),
              OnlineGlowBadge(isOnline: isOnline),
            ],
          ),

          const SizedBox(height: vGapBetweenTitleAndBelow),

          // Meta Row
          _MetaRowLeftLatLngRightTime(
            lat: lat,
            lng: lng,
            timeLabel: timeLabel,
          ),

          const SizedBox(height: vGapBetweenTitleAndBelow),

          // Metrics → AC 5 + DC 3 + OAT
          MetricList(
            items: [
              // AC side
              MetricItem('AC Voltage', _fmtNum(vac, suffix: ' V')),
              MetricItem('AC Current', _fmtNum(iac, suffix: ' A')),
              MetricItem('AC Power', _fmtNum(wac, suffix: ' W')),
              MetricItem('AC Freq', _fmtNum(acfreq, suffix: ' Hz')),
              MetricItem('AC Energy', _fmtNum(acenergy, suffix: ' kWh')),

              // DC side
              MetricItem('DC Voltage', _fmtNum(vdc, suffix: ' V')),
              MetricItem('DC Current', _fmtNum(idc, suffix: ' A')),
              MetricItem('DC Power', _fmtNum(wdc, suffix: ' W')),

              // OAT (On Air Target)
              MetricItem('On Air Target', _fmtNum(oat)),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtNum(dynamic v, {String suffix = ''}) {
    if (v == null) return '-';
    if (v is num) {
      final isInt = v is int || v == v.roundToDouble();
      return isInt
          ? '${v.toString()}$suffix'
          : '${v.toStringAsFixed(2)}$suffix';
    }
    return '$v$suffix';
  }

  DateTime? _toDate(dynamic v) {
    try {
      if (v == null) return null;
      if (v is DateTime) return v.toLocal();
      if (v is int) {
        return DateTime.fromMillisecondsSinceEpoch(v).toLocal();
      }
      if (v is String && v.isNotEmpty) return DateTime.parse(v).toLocal();
    } catch (_) {}
    return null;
  }

  String _hhmmss(DateTime dt) {
    final t = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

/// ===== แถว Meta: (ซ้าย) Lat/Lng | (ขวา) เวลาอัปเดต =====
class _MetaRowLeftLatLngRightTime extends StatelessWidget {
  final dynamic lat;
  final dynamic lng;
  final String timeLabel;

  const _MetaRowLeftLatLngRightTime({
    required this.lat,
    required this.lng,
    required this.timeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final metaStyle = TextStyle(
      fontSize: 12,
      color: Colors.grey[800],
      fontWeight: FontWeight.w600,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // LEFT: Lat/Lng
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.place, size: 16, color: Colors.red[600]),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  (lat is num && lng is num)
                      ? 'Lat ${lat.toStringAsFixed(6)}, Lng ${lng.toStringAsFixed(6)}'
                      : 'ตำแหน่ง -',
                  style: metaStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // RIGHT: Updated time
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 16, color: Colors.blue[600]),
            const SizedBox(width: 6),
            Text(
              timeLabel != '-' ? 'อัปเดต $timeLabel' : 'อัปเดต -',
              style: metaStyle,
            ),
          ],
        ),
      ],
    );
  }
}

/// ===== ป้ายชื่อระบบแบบ “มีไอคอนนำหน้า” =====
class _SystemPill extends StatelessWidget {
  final String text;
  final Gradient gradient;
  final IconData icon;
  const _SystemPill({
    required this.text,
    required this.gradient,
    required this.icon,
  });

  factory _SystemPill.familyWirelessOrLighting({
    required MonitoringKind kind,
    required String text,
  }) {
    // ตอนนี้เหลือแค่ระบบไร้สาย (ซิม) → ใช้สไตล์เดียวตลอด
    return _SystemPill(
      text: text,
      icon: Icons.sim_card,
      gradient: const LinearGradient(
        colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)], // ฟ้าไล่เฉด
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }
}

/// ===== แบดจ์ Online/Offline =====
class OnlineGlowBadge extends StatelessWidget {
  final bool isOnline;
  const OnlineGlowBadge({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final base = isOnline ? Colors.green[600]! : Colors.red[600]!;
    final glow = isOnline ? Colors.green[300]! : Colors.red[300]!;
    final label = isOnline ? 'Online' : 'Offline';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: base.withOpacity(0.85)),
        boxShadow: [
          BoxShadow(
            color: glow.withOpacity(0.7),
            blurRadius: 14,
            spreadRadius: 1.5,
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: .2,
        ),
      ),
    );
  }
}

/// ===== รายการ Metric ธรรมดา (label + value) =====
class MetricList extends StatelessWidget {
  final List<MetricItem> items;

  const MetricList({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (m) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      m.label,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    m.value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class MetricItem {
  final String label;
  final String value;

  MetricItem(this.label, this.value);
}
