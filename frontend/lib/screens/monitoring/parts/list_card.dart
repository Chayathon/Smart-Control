// lib/screens/monitoring/parts/list_card.dart
import 'package:flutter/material.dart';
import '../monitoring_mock.dart';

/// ===== ตัวกรอง =====
enum TypeFilter { all, lighting, wave, sim }
enum StatusFilter { all, online, offline }

/// ===== แผงลิสต์ + ส่วนตัวกรอง =====
class MonitoringListPanel extends StatelessWidget {
  final List<MonitoringEntry> items;
  final String? selectedId;
  final Color cardBg, border, accent, textColor;
  final ScrollController listController;

  /// เรียกเมื่อผู้ใช้กดเปิด/ปิดไฟบนไอเท็ม (จะถูกเรียกหลังจากอัปเดต mock แล้ว)
  final void Function(MonitoringEntry) onToggleLighting;

  final void Function(MonitoringEntry) onSelectEntry;

  final TypeFilter typeFilter;
  final ValueChanged<TypeFilter> onChangeTypeFilter;

  final StatusFilter statusFilter;
  final ValueChanged<StatusFilter> onChangeStatusFilter;

  final int totalCount, onlineCount, offlineCount;

  const MonitoringListPanel({
    super.key,
    required this.items,
    required this.selectedId,
    required this.cardBg,
    required this.border,
    required this.accent,
    required this.textColor,
    required this.listController,
    required this.onToggleLighting,
    required this.onSelectEntry,
    required this.typeFilter,
    required this.onChangeTypeFilter,
    required this.statusFilter,
    required this.onChangeStatusFilter,
    required this.totalCount,
    required this.onlineCount,
    required this.offlineCount,
  });

  String _titleFor(MonitoringEntry e) {
    switch (e.kind) {
      case MonitoringKind.lighting:
        return 'ระบบไฟส่องสว่าง';
      case MonitoringKind.wirelessWave:
        return 'ระบบไร้สาย (คลื่น)';
      case MonitoringKind.wirelessSim:
        return 'ระบบไร้สาย (ซิม)';
    }
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
            // ===== แถบตัวกรอง =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  TypeDropdown(
                    value: typeFilter,
                    onChanged: onChangeTypeFilter,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      primary: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('สถานะ:', style: TextStyle(color: Colors.grey[700])),
                          const SizedBox(width: 8),
                          Status3DButton(
                            label: 'ทั้งหมด ($totalCount)',
                            selected: statusFilter == StatusFilter.all,
                            onTap: () => onChangeStatusFilter(StatusFilter.all),
                          ),
                          const SizedBox(width: 8),
                          Status3DButton(
                            label: 'Online ($onlineCount)',
                            selected: statusFilter == StatusFilter.online,
                            onTap: () => onChangeStatusFilter(StatusFilter.online),
                          ),
                          const SizedBox(width: 8),
                          Status3DButton(
                            label: 'Offline ($offlineCount)',
                            selected: statusFilter == StatusFilter.offline,
                            onTap: () => onChangeStatusFilter(StatusFilter.offline),
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
                    final e = items[i];
                    final isSelected = selectedId != null && e.id == selectedId;

                    final wrap = (Widget child) => GestureDetector(
                          onTap: () => onSelectEntry(e),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: isSelected ? Colors.blue[50] : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? Colors.blue : Colors.transparent,
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

                    if (e.kind == MonitoringKind.lighting) {
                      return wrap(
                        LightingTile(
                          entry: e,
                          title: '${e.order} ${_titleFor(e)}',
                          accent: accent,
                          textColor: textColor,
                          border: border,
                          onToggleLighting: onToggleLighting,
                        ),
                      );
                    } else {
                      return wrap(
                        WirelessTile(
                          entry: e,
                          title: '${e.order} ${_titleFor(e)}',
                          accent: accent,
                          textColor: textColor,
                          border: border,
                        ),
                      );
                    }
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

/// ===== ดรอปดาวน์ "แบบเดิม" (ปุ่ม 3D + เมนูกว้างเท่าปุ่ม, ชิดซ้ายปุ่ม) =====
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
    const innerLeftText = 12.0;
    const innerRightText = 10.0;
    const v = 12.0;
    const edge = 10.0;

    PopupMenuEntry<TypeFilter> _item(
      TypeFilter val,
      String text, {
      double topExtra = 0,
      double bottomExtra = 0,
    }) {
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
          final overlay = Overlay.of(boxContext).context.findRenderObject() as RenderBox;
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            position: RelativeRect.fromLTRB(left, top, right, overlay.size.height - top),
            items: _buildItems(menuW),
          );

          if (selected != null) onChanged(selected);
        });
      },
    );
  }
}

/// ปุ่ม 3D แบบเดิม
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
            width: 180,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), offset: Offset(3, 5), blurRadius: 10),
                  BoxShadow(color: Color(0x66FFFFFF), offset: Offset(-3, -3), blurRadius: 10),
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
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.expand_more, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ===== ปุ่มสถานะ 3D =====
class Status3DButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const Status3DButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? Colors.grey[700]! : Colors.white;
    final txt = selected ? Colors.white : Colors.black87;
    final border = selected ? Colors.grey[800]! : Colors.grey[300]!;

    final shadows = selected
        ? <BoxShadow>[
            const BoxShadow(color: Color(0x59000000), offset: Offset(2, 3), blurRadius: 8),
            BoxShadow(color: Colors.white.withOpacity(0.6), offset: const Offset(-2, -2), blurRadius: 6),
          ]
        : const <BoxShadow>[
            BoxShadow(color: Color(0x33000000), offset: Offset(3, 5), blurRadius: 10),
            BoxShadow(color: Color(0xF2FFFFFF), offset: Offset(-3, -3), blurRadius: 10),
          ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
          boxShadow: shadows,
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: txt)),
      ),
    );
  }
}

// ======================= LightingTile =======================
class LightingTile extends StatelessWidget {
  final MonitoringEntry entry;
  final String title;
  final Color accent, textColor, border;

  /// จะถูกเรียก “หลัง” อัปเดต mock แล้ว เพื่อให้หน้าจอแม่ sync state ถ้าต้องการ
  final void Function(MonitoringEntry) onToggleLighting;

  const LightingTile({
    super.key,
    required this.entry,
    required this.title,
    required this.accent,
    required this.textColor,
    required this.border,
    required this.onToggleLighting,
  });

  String _hhmmss(DateTime dt) {
    final t = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<MonitoringEntry>>(
      valueListenable: MonitoringMock.itemsNotifier,
      builder: (context, _, __) {
        final fresh = MonitoringMock.findById(entry.id) ?? entry;
        final d = fresh.data as LightingData;

        // ตรรกะของปุ่ม
        final isLightingOn = d.statusLighting;
        // ถ้าไฟเปิด (true) -> ปุ่มบอกให้ 'ปิดไฟ' (สีเขียว)
        final buttonText = isLightingOn ? 'เปิดไฟ' : 'ปิดไฟ';
        // ถ้าไฟเปิด (true) -> ไอคอนหลอดไฟที่เปิดอยู่ (Outline), ถ้าไฟปิด (false) -> ไอคอนหลอดไฟที่ปิดอยู่ (Solid)
        final buttonIcon = isLightingOn ? Icons.lightbulb : Icons.lightbulb_outline;
        // ถ้าไฟเปิด (true) -> สีเขียว, ถ้าไฟปิด (false) -> สีแดง
        final buttonColor = isLightingOn ? Colors.green[600] : Colors.red[600];


        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 8)),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: .2,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OnlineGlowBadge(isOnline: d.online),
              ]),
              const SizedBox(height: 6),
              Text(
                'อัปเดตล่าสุด ${_hhmmss(fresh.updatedAt)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 10),
              MetricList(items: [
                MetricItem('AC Voltage', '${d.acV.toStringAsFixed(1)} V'),
                MetricItem('AC Current', '${d.acA.toStringAsFixed(2)} A'),
                MetricItem('AC Power', '${d.acW.toStringAsFixed(1)} W'),
                MetricItem('AC Frequency', '${d.acHz.toStringAsFixed(0)} Hz'),
                MetricItem('AC Energy', '${d.acKWh.toStringAsFixed(2)} kWh'),
              ]),
              const SizedBox(height: 10),

              /// ปุ่ม เปิด/ปิด ไฟ
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 1. ข้อความ 'สถานะไฟ' (ปรับ style ให้ตรงกับ Metric Label)
                  Text(
                    'สถานะไฟ',
                    style: TextStyle(
                      color: Colors.grey[700], 
                      fontWeight: FontWeight.w600, 
                    ),
                  ),

                  // 2. ปุ่ม Elevated Button (กำหนดความกว้าง Text เพื่อป้องกันการขยับ)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                      alignment: Alignment.center,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      minimumSize: const Size(120, 44),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onPressed: () {
                      final next = !d.statusLighting;
                      MonitoringMock.updateLightingStatus(entry.id, next);
                      onToggleLighting(fresh);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ไอคอนนำหน้า
                        Icon(buttonIcon, size: 20),
                        const SizedBox(width: 8),
                        
                        // ✅ ล็อกความกว้างของข้อความ (ใช้ SizedBox)
                        SizedBox(
                          width: 45,
                          child: Text(
                            buttonText,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ======================= WirelessTile =======================
class WirelessTile extends StatelessWidget {
  final MonitoringEntry entry;
  final String title;
  final Color accent, textColor, border;

  const WirelessTile({
    super.key,
    required this.entry,
    required this.title,
    required this.accent,
    required this.textColor,
    required this.border,
  });

  String _hhmmss(DateTime dt) {
    final t = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final d = entry.data as WirelessData;
    final isOnline = d.online;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 6))
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: .2,
                  color: Colors.black87,
                  shadows: [Shadow(blurRadius: 6, color: Color(0x22000000), offset: Offset(0, 1))],
                ),
              ),
            ),
            const SizedBox(width: 8),
            OnlineGlowBadge(isOnline: isOnline),
          ]),
          const SizedBox(height: 6),
          Text(
            'Lat ${entry.lat.toStringAsFixed(6)}, Lng ${entry.lng.toStringAsFixed(6)} · อัปเดตล่าสุด ${_hhmmss(entry.updatedAt)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 10),
          MetricList(items: [
            MetricItem('DC Voltage', '${d.dcV.toStringAsFixed(1)} V'),
            MetricItem('DC Current', '${d.dcA.toStringAsFixed(2)} A'),
            MetricItem('DC Power', '${d.dcW.toStringAsFixed(1)} W'),
            MetricItem('On Air Target', d.onAirTarget ? 'ใช่' : 'ไม่ใช่'),
          ]),
        ],
      ),
    );
  }
}

/// ===== แบดจ์ Online/Offline (ดีไซน์ด้านล่าง) =====
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

class MetricList extends StatelessWidget {
  final List<MetricItem> items;
  const MetricList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map((m) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: Text(m.label,
                            style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600))),
                    Text(m.value, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class MetricItem {
  final String label;
  final String value;
  MetricItem(this.label, this.value);
}