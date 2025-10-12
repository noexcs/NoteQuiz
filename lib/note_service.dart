import 'package:shared_preferences/shared_preferences.dart';
import 'notes/note_new.dart';

class NoteService {
  static const String _notesKey = 'notes';
  
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<List<Note>> loadNotes() async {
    final String? notesJson = _prefs.getString(_notesKey);
    if (notesJson == null || notesJson.isEmpty) {
      return [];
    }
    return NoteList.fromJson(notesJson);
  }

  Future<void> saveNotes(List<Note> notes) async {
    final String notesJson = NoteList.toJson(notes);
    await _prefs.setString(_notesKey, notesJson);
  }

  Future<void> addNote(Note note) async {
    final List<Note> notes = await loadNotes();
    notes.add(note);
    await saveNotes(notes);
  }

  Future<void> updateNote(Note note) async {
    final List<Note> notes = await loadNotes();
    final index = notes.indexWhere((element) => element.id == note.id);
    if (index != -1) {
      notes[index] = note;
      await saveNotes(notes);
    }
  }

  Future<void> deleteNote(String id) async {
    final List<Note> notes = await loadNotes();
    notes.removeWhere((note) => note.id == id);
    await saveNotes(notes);
  }
}