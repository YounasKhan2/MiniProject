import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import 'dart:io'; // For file operations

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    debugPrint("Initializing database - it was null");

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      debugPrint("Starting database initialization");
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'expenses.db');

      // Make sure we close any existing connections before opening a new one
      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      debugPrint("Opening database at: $path");

      return await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          debugPrint("Creating new expenses table");
          await db.execute('''
            CREATE TABLE expenses (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT,
              category TEXT,
              amount REAL,
              date TEXT,
              isShared INTEGER
            )
          ''');
          debugPrint("Expenses table created successfully");

          await db.execute('''
            CREATE TABLE splits (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              totalAmount REAL
            )
          ''');
          await db.execute('''
            CREATE TABLE split_details (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              splitId INTEGER,
              name TEXT,
              percentage REAL,
              FOREIGN KEY (splitId) REFERENCES splits (id)
            )
          ''');
        },
        onOpen: (db) {
          debugPrint("Database opened successfully");
        },
      );
    } catch (e) {
      debugPrint("Database initialization failed with error: $e");
      Fluttertoast.showToast(msg: 'Database initialization failed: $e');
      rethrow;
    }
  }

  Future<void> debugDatabase() async {
    try {
      final db = await database;
      final dbPath = await getDatabasesPath();
      debugPrint("Database path: $dbPath");
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      debugPrint("Tables in the database: $tables");
    } catch (e) {
      debugPrint("Error while debugging database: $e");
    }
  }

  Future<int> insertExpense(Map<String, dynamic> expense) async {
    final db = await database;
    return await db.insert('expenses', expense);
  }

  Future<List<Map<String, dynamic>>> getExpenses() async {
    final db = await database;
    return await db.query('expenses');
  }

  Future<int> updateExpense(int id, Map<String, dynamic> expense) async {
    final db = await database;
    return await db.update('expenses', expense, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllExpenses() async {
    final db = await database;
    await db.delete('expenses');
    debugPrint("All expenses deleted successfully");
  }

  Future<int> insertSplit(Map<String, dynamic> split) async {
    final db = await database;
    final splitId = await db.insert('splits', {'totalAmount': split['totalAmount']});
    for (var detail in split['splitDetails']) {
      await db.insert('split_details', {
        'splitId': splitId,
        'name': detail['name'],
        'percentage': detail['percentage'],
      });
    }
    return splitId;
  }

  Future<List<Map<String, dynamic>>> getSplits() async {
    final db = await database;
    final splits = await db.query('splits');
    final List<Map<String, dynamic>> result = [];
    for (var split in splits) {
      final splitId = split['id'];
      final details = await db.query('split_details', where: 'splitId = ?', whereArgs: [splitId]);
      result.add({
        ...split, // Copy existing split data
        'details': details, // Add details as a new key
      });
    }
    return result;
  }
}
