import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TodoItem {
  final String id;
  String title;
  bool isDone;

  TodoItem({required this.id, required this.title, this.isDone = false});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<TodoItem> _todos = [
    TodoItem(id: '1', title: 'Écouter le nouveau album de Daft Punk'),
    TodoItem(id: '2', title: 'Créer une playlist workout'),
    TodoItem(id: '3', title: 'Découvrir des artistes indie', isDone: true),
  ];

  final TextEditingController _controller = TextEditingController();

  void _addTodo() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _todos.add(TodoItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: text,
      ));
      _controller.clear();
    });
  }

  void _toggleTodo(String id) {
    setState(() {
      final todo = _todos.firstWhere((t) => t.id == id);
      todo.isDone = !todo.isDone;
    });
  }

  void _deleteTodo(String id) {
    setState(() => _todos.removeWhere((t) => t.id == id));
  }

  void _showEditDialog(TodoItem todo) {
    final editController = TextEditingController(text: todo.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Modifier', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: editController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primary),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final newText = editController.text.trim();
              if (newText.isNotEmpty) {
                setState(() => todo.title = newText);
              }
              Navigator.pop(context);
            },
            child: const Text('Sauvegarder', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  List<TodoItem> get _pending => _todos.where((t) => !t.isDone).toList();
  List<TodoItem> get _done => _todos.where((t) => t.isDone).toList();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes tâches'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_pending.length} restante${_pending.length > 1 ? 's' : ''}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _InputBar(controller: _controller, onAdd: _addTodo),
          Expanded(
            child: _todos.isEmpty
                ? const _EmptyState()
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      if (_pending.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ..._pending.map((todo) => _TodoTile(
                              todo: todo,
                              onToggle: () => _toggleTodo(todo.id),
                              onDelete: () => _deleteTodo(todo.id),
                              onEdit: () => _showEditDialog(todo),
                            )),
                      ],
                      if (_done.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const _SectionLabel(label: 'Terminé'),
                        const SizedBox(height: 8),
                        ..._done.map((todo) => _TodoTile(
                              todo: todo,
                              onToggle: () => _toggleTodo(todo.id),
                              onDelete: () => _deleteTodo(todo.id),
                              onEdit: () => _showEditDialog(todo),
                            )),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onAdd;

  const _InputBar({required this.controller, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: AppTheme.background,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onAdd(),
              decoration: InputDecoration(
                hintText: 'Ajouter une tâche...',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: AppTheme.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodoTile extends StatelessWidget {
  final TodoItem todo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _TodoTile({
    required this.todo,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(todo.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: GestureDetector(
        onLongPress: onEdit,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: todo.isDone ? Colors.white10 : AppTheme.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: todo.isDone ? AppTheme.primary : Colors.transparent,
                    border: Border.all(
                      color: todo.isDone ? AppTheme.primary : Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: todo.isDone
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  todo.title,
                  style: TextStyle(
                    color: todo.isDone ? Colors.grey : Colors.white,
                    fontSize: 15,
                    decoration: todo.isDone ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.drag_handle,
                color: Colors.white.withValues(alpha: 0.2),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: Colors.grey,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.white12),
          SizedBox(height: 16),
          Text(
            'Aucune tâche',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          SizedBox(height: 4),
          Text(
            'Ajoute ta première tâche ci-dessus',
            style: TextStyle(color: Colors.white24, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
