import 'package:drift/drift.dart';

import 'pending_sessions_connection_web.dart'
    if (dart.library.io) 'pending_sessions_connection_native.dart';

QueryExecutor openConnection() => createConnection();
