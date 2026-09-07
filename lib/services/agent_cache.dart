import 'package:cloud_firestore/cloud_firestore.dart';

/// Simple in-memory cache for uid → agent name lookups.
/// Prevents re-fetching the same user on every list rebuild.
class AgentCache {
  AgentCache._();
  static final AgentCache instance = AgentCache._();

  final Map<String, String> _cache = {};

  Future<String> getName(String uid) async {
    if (uid.isEmpty) return 'Unknown';
    if (_cache.containsKey(uid)) return _cache[uid]!;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final name = doc.data()?['name'] as String? ?? uid;
      _cache[uid] = name;
      return name;
    } catch (_) {
      return uid;
    }
  }

  void clear() => _cache.clear();
}
