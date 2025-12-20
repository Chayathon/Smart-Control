// lib/screens/sos/manage_contacts.dart
//
// หน้าจัดการรายชื่อเบอร์โทร (ใช้แยกจาก SOS screen, ไม่ลิงค์ข้อมูลกัน)

import 'package:flutter/material.dart';

class EditableContact {
  String username;
  String domain;
  String login;
  String password;

  EditableContact({
    required this.username,
    required this.domain,
    required this.login,
    required this.password,
  });
}

typedef DarkInputDecorationBuilder = InputDecoration Function({
  required String label,
  String? hint,
  Widget? prefixIcon,
});

class ManageContactsDialog extends StatefulWidget {
  const ManageContactsDialog({super.key});

  @override
  State<ManageContactsDialog> createState() => _ManageContactsDialogState();
}

class _ManageContactsDialogState extends State<ManageContactsDialog> {
  late List<EditableContact> _contacts;

  int? _editingIndex;
  final TextEditingController _editUsernameController = TextEditingController();
  final TextEditingController _editDomainController = TextEditingController();
  final TextEditingController _editLoginController = TextEditingController();
  final TextEditingController _editPasswordController = TextEditingController();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    // ข้อมูลตัวอย่างในหน้านี้ (ไม่เกี่ยวกับหน้า SOS)
    _contacts = [
      EditableContact(
        username: 'Control Room',
        domain: 'raspberrypi.local',
        login: '2000',
        password: '',
      ),
      EditableContact(
        username: 'Guard 1',
        domain: 'raspberrypi.local',
        login: '3001',
        password: '',
      ),
      EditableContact(
        username: 'Technician',
        domain: 'raspberrypi.local',
        login: '4001',
        password: '',
      ),
    ];

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _editUsernameController.dispose();
    _editDomainController.dispose();
    _editLoginController.dispose();
    _editPasswordController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ---------- CRUD ----------

  void _addContact() {
    setState(() {
      _contacts.add(
        EditableContact(username: '', domain: '', login: '', password: ''),
      );
      final newIndex = _contacts.length - 1;
      _startEdit(newIndex);
    });
  }

  void _removeContact(int index) {
    setState(() {
      _contacts.removeAt(index);
      if (_editingIndex == index) {
        _editingIndex = null;
      } else if (_editingIndex != null && _editingIndex! > index) {
        _editingIndex = _editingIndex! - 1;
      }
    });
  }

  void _startEdit(int index) {
    setState(() {
      _editingIndex = index;
      final c = _contacts[index];
      _editUsernameController.text = c.username;
      _editDomainController.text = c.domain;
      _editLoginController.text = c.login;
      _editPasswordController.text = c.password;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingIndex = null;
      _editUsernameController.clear();
      _editDomainController.clear();
      _editLoginController.clear();
      _editPasswordController.clear();
    });
  }

  void _saveEdit() {
    if (_editingIndex == null) return;
    setState(() {
      final idx = _editingIndex!;
      _contacts[idx].username = _editUsernameController.text.trim();
      _contacts[idx].domain = _editDomainController.text.trim();
      _contacts[idx].login = _editLoginController.text.trim();
      _contacts[idx].password = _editPasswordController.text.trim();
      _editingIndex = null;
      _editUsernameController.clear();
      _editDomainController.clear();
      _editLoginController.clear();
      _editPasswordController.clear();
    });
  }

  void _saveAndClose() {
    Navigator.of(context).pop();
  }

  // ---------- Filter list ----------

  List<int> _filteredIndices() {
    if (_searchQuery.isEmpty) {
      return List<int>.generate(_contacts.length, (i) => i);
    }
    return List<int>.generate(_contacts.length, (i) => i).where((i) {
      final c = _contacts[i];
      final u = c.username.toLowerCase();
      final d = c.domain.toLowerCase();
      final l = c.login.toLowerCase();
      return u.contains(_searchQuery) || d.contains(_searchQuery) || l.contains(_searchQuery);
    }).toList();
  }

  // ---------- Style helpers ----------

  InputDecoration _darkInputDecoration({
    required String label,
    String? hint,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      labelStyle: const TextStyle(
        fontSize: 12,
        color: Colors.white70,
      ),
      hintStyle: const TextStyle(
        fontSize: 12,
        color: Colors.white54,
      ),
      isDense: true,
      filled: true,
      fillColor: Colors.white.withOpacity(0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.18),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: Colors.lightBlueAccent.withOpacity(0.9),
          width: 1.2,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  /// เลเยอร์กลาง
  BoxDecoration get _panelDecoration => BoxDecoration(
        color: Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.55),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.42),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredIndices();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: _ManageContactsDialogShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ManageContactsHeader(
              onAdd: _addContact,
              onClose: _saveAndClose,
            ),
            _ManageContactsDivider(),
            const SizedBox(height: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: _ManageContactsContent(
                  searchController: _searchController,
                  darkInputDecoration: _darkInputDecoration,
                  panelDecoration: _panelDecoration,
                  filteredIndices: filtered,
                  contacts: _contacts,
                  editingIndex: _editingIndex,
                  editUsernameController: _editUsernameController,
                  editDomainController: _editDomainController,
                  editLoginController: _editLoginController,
                  editPasswordController: _editPasswordController,
                  onStartEdit: _startEdit,
                  onCancelEdit: _cancelEdit,
                  onSaveEdit: _saveEdit,
                  onRemoveContact: _removeContact,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================
// Widgets (แยกจาก build หลัก)
// ==============================

class _ManageContactsDialogShell extends StatelessWidget {
  final Widget child;
  const _ManageContactsDialogShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 640,
      height: 580,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF141E30),
            Color(0xFF243B55),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.7),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ManageContactsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.white.withOpacity(0.10),
    );
  }
}

class _ManageContactsHeader extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onClose;

  const _ManageContactsHeader({
    required this.onAdd,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          const Icon(
            Icons.people_alt_outlined,
            size: 26,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage contacts',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'จัดการรายชื่อปลายทางสำหรับโทรออก',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Add contact',
            onPressed: onAdd,
            icon: const Icon(
              Icons.person_add_alt_1_outlined,
              size: 22,
              color: Colors.white70,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white70,
              size: 22,
            ),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _ManageContactsContent extends StatelessWidget {
  final TextEditingController searchController;
  final DarkInputDecorationBuilder darkInputDecoration;
  final BoxDecoration panelDecoration;

  final List<int> filteredIndices;
  final List<EditableContact> contacts;
  final int? editingIndex;

  final TextEditingController editUsernameController;
  final TextEditingController editDomainController;
  final TextEditingController editLoginController;
  final TextEditingController editPasswordController;

  final ValueChanged<int> onStartEdit;
  final VoidCallback onCancelEdit;
  final VoidCallback onSaveEdit;
  final ValueChanged<int> onRemoveContact;

  const _ManageContactsContent({
    required this.searchController,
    required this.darkInputDecoration,
    required this.panelDecoration,
    required this.filteredIndices,
    required this.contacts,
    required this.editingIndex,
    required this.editUsernameController,
    required this.editDomainController,
    required this.editLoginController,
    required this.editPasswordController,
    required this.onStartEdit,
    required this.onCancelEdit,
    required this.onSaveEdit,
    required this.onRemoveContact,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search
        TextField(
          controller: searchController,
          decoration: darkInputDecoration(
            label: 'Search',
            hint: 'Search by username, domain or login',
            prefixIcon: const Icon(
              Icons.search,
              size: 18,
              color: Colors.white70,
            ),
          ),
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),

        // List panel
        Expanded(
          child: Container(
            decoration: panelDecoration,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              itemCount: filteredIndices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, listIdx) {
                final index = filteredIndices[listIdx];
                final contact = contacts[index];
                final bool isEditing = editingIndex == index;

                if (isEditing) {
                  return _ContactEditorCard(
                    darkInputDecoration: darkInputDecoration,
                    editUsernameController: editUsernameController,
                    editDomainController: editDomainController,
                    editLoginController: editLoginController,
                    editPasswordController: editPasswordController,
                    onCancel: onCancelEdit,
                    onSave: onSaveEdit,
                  );
                }

                return _ContactReadCard(
                  contact: contact,
                  onEdit: () => onStartEdit(index),
                  onDelete: () async {
                    final bool? confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF141E30),
                        title: const Text(
                          'Confirm delete',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: const Text(
                          'ต้องการลบรายชื่อนี้หรือไม่?',
                          style: TextStyle(color: Colors.white),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                            ),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      onRemoveContact(index);
                    }
                  },
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ContactEditorCard extends StatelessWidget {
  final DarkInputDecorationBuilder darkInputDecoration;

  final TextEditingController editUsernameController;
  final TextEditingController editDomainController;
  final TextEditingController editLoginController;
  final TextEditingController editPasswordController;

  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _ContactEditorCard({
    required this.darkInputDecoration,
    required this.editUsernameController,
    required this.editDomainController,
    required this.editLoginController,
    required this.editPasswordController,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF141E30),
            Color(0xFF243B55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.lightBlueAccent.withOpacity(0.95),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.65),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: editUsernameController,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  decoration: darkInputDecoration(
                    label: 'Username *',
                    hint: 'เช่น Control Room',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: editDomainController,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  decoration: darkInputDecoration(
                    label: 'Domain *',
                    hint: 'เช่น raspberrypi.local',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: editLoginController,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  decoration: darkInputDecoration(
                    label: 'Login',
                    hint: 'เช่น 2000',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: editPasswordController,
                  obscureText: true,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  decoration: darkInputDecoration(
                    label: 'Password',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onSave,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  backgroundColor: Colors.lightBlueAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  elevation: 3,
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactReadCard extends StatelessWidget {
  final EditableContact contact;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  const _ContactReadCard({
    required this.contact,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasUsername = contact.username.trim().isNotEmpty;
    final Color statusColor = hasUsername ? Colors.greenAccent : Colors.grey;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // จุดสถานะแบบเรืองแสง
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.9),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: statusColor.withOpacity(0.6),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.username.isEmpty ? '(No username)' : contact.username,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Domain: ${contact.domain.isEmpty ? '-' : contact.domain}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.75),
                  ),
                ),
                Text(
                  'Login: ${contact.login.isEmpty ? '-' : contact.login}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.75),
                  ),
                ),
                Text(
                  'Password: ${contact.password.isEmpty ? '-' : '••••••'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(
              Icons.edit_outlined,
              size: 22,
              color: Colors.white70,
            ),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(
              Icons.delete_outline,
              size: 22,
              color: Colors.redAccent,
            ),
            onPressed: () async => onDelete(),
          ),
        ],
      ),
    );
  }
}
