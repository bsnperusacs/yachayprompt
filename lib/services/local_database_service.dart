// Archivo: lib/services/local_database_service.dart

import 'package:sqflite/sqflite.dart'; // Para la base de datos SQLite
import 'package:path/path.dart'; // Para unir rutas de archivos
import 'package:yachay_prompts/models/prompt_model.dart'; // ¡Importa tu modelo PromptGenerado!

class LocalDatabaseService {
  // Patrón Singleton para una única instancia de la base de datos
  static final LocalDatabaseService _instance =
      LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  static Database? _database; // La instancia de la base de datos

  // Getter para obtener la instancia de la base de datos.
  // Si no existe, la inicializa.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  // Inicializa la base de datos
  Future<Database> _initDB() async {
    final databasePath = await getDatabasesPath();
    final path = join(
      databasePath,
      'yachay_prompts.db',
    ); // Nombre de tu archivo de base de datos

    return await openDatabase(
      path,
      version:
          1, // Versión de la base de datos. Incrementa si haces cambios en la estructura.
      onCreate:
          _createDB, // Función que se llama cuando la base de datos es creada por primera vez
    );
  }

  // Crea las tablas de la base de datos
  Future<void> _createDB(Database db, int version) async {
    // Tabla para almacenar los prompts generados
    await db.execute('''
      CREATE TABLE prompts(
        id TEXT PRIMARY KEY,
        userId TEXT,
        nivelEducativo TEXT,
        asignatura TEXT,
        objetivoContenido TEXT,
        idiomaPrompt TEXT,
        varianteQuechua TEXT,
        textoPromptFinal TEXT,
        tituloPersonalizado TEXT,
        idPlantillaOrigen TEXT,
        parametrosIaUsados TEXT, -- Guardar como JSON string
        respuestaIaRecibida TEXT,
        fechaCreacion INTEGER,   -- Guardar como timestamp Unix
        fechaModificacion INTEGER, -- Guardar como timestamp Unix
        favorito INTEGER,        -- 0 para false, 1 para true
        tagsPersonales TEXT,     -- Guardar como JSON string de una lista de strings
        carpetaOrganizacion TEXT
      )
    ''');

    // Puedes añadir más tablas aquí si las necesitas, por ejemplo, para usuarios locales o plantillas
    // Ejemplo: await db.execute('CREATE TABLE users(...)');
  }

  // --- Operaciones CRUD para Prompts ---

  // Insertar un prompt en la base de datos local
  Future<int> insertPrompt(PromptGenerado prompt) async {
    final db = await database;
    return await db.insert(
      'prompts',
      {
        'id': prompt.id, // Generar ID si es nulo
        'userId': prompt.userId,
        'nivelEducativo': prompt.nivelEducativo,
        'asignatura': prompt.asignatura,
        'objetivoContenido': prompt.objetivoContenido,
        'idiomaPrompt': prompt.idiomaPrompt,
        'varianteQuechua': prompt.varianteQuechua,
        'textoPromptFinal': prompt.textoPromptFinal,
        'tituloPersonalizado': prompt.tituloPersonalizado,
        'idPlantillaOrigen': prompt.idPlantillaOrigen,
        'parametrosIaUsados': prompt.parametrosIaUsados != null
            ? (prompt.parametrosIaUsados!.toString())
            : null, // Convertir Map a String
        'respuestaIaRecibida': prompt.respuestaIaRecibida,
        'fechaCreacion': prompt.fechaCreacion.millisecondsSinceEpoch,
        'fechaModificacion': prompt.fechaModificacion.millisecondsSinceEpoch,
        'favorito': prompt.favorito ? 1 : 0,
        'tagsPersonales': prompt.tagsPersonales != null
            ? (prompt.tagsPersonales!.join(','))
            : null, // Convertir List a String CSV
        'carpetaOrganizacion': prompt.carpetaOrganizacion,
      },
      conflictAlgorithm: ConflictAlgorithm.replace, // Reemplaza si ya existe
    );
  }

  // Obtener todos los prompts de la base de datos local
  Future<List<PromptGenerado>> getPrompts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('prompts');

    return List.generate(maps.length, (i) {
      // Nota: Este fromSqlite en PromptGenerado lo tendrás que implementar
      // Si tu PromptGenerado no tiene fromSqlite, necesitarás un constructor
      // o un fromJson/fromMap que pueda manejar los datos de SQLite.
      return PromptGenerado(
        id: maps[i]['id'],
        userId: maps[i]['userId'],
        nivelEducativo: maps[i]['nivelEducativo'],
        asignatura: maps[i]['asignatura'],
        objetivoContenido: maps[i]['objetivoContenido'],
        idiomaPrompt: maps[i]['idiomaPrompt'],
        varianteQuechua: maps[i]['varianteQuechua'],
        textoPromptFinal: maps[i]['textoPromptFinal'],
        tituloPersonalizado: maps[i]['tituloPersonalizado'],
        idPlantillaOrigen: maps[i]['idPlantillaOrigen'],
        parametrosIaUsados: maps[i]['parametrosIaUsados'] != null
            ? {'data': maps[i]['parametrosIaUsados']}
            : null, // Convertir de nuevo de String a Map
        respuestaIaRecibida: maps[i]['respuestaIaRecibida'],
        fechaCreacion: DateTime.fromMillisecondsSinceEpoch(
          maps[i]['fechaCreacion'],
        ),
        fechaModificacion: DateTime.fromMillisecondsSinceEpoch(
          maps[i]['fechaModificacion'],
        ),
        favorito: maps[i]['favorito'] == 1,
        tagsPersonales: maps[i]['tagsPersonales'] != null
            ? (maps[i]['tagsPersonales'] as String).split(',')
            : null, // Convertir de nuevo de CSV a List
        carpetaOrganizacion: maps[i]['carpetaOrganizacion'],
      );
    });
  }

  // Actualizar un prompt existente
  Future<int> updatePrompt(PromptGenerado prompt) async {
    final db = await database;
    return await db.update(
      'prompts',
      {
        'userId': prompt.userId,
        'nivelEducativo': prompt.nivelEducativo,
        'asignatura': prompt.asignatura,
        'objetivoContenido': prompt.objetivoContenido,
        'idiomaPrompt': prompt.idiomaPrompt,
        'varianteQuechua': prompt.varianteQuechua,
        'textoPromptFinal': prompt.textoPromptFinal,
        'tituloPersonalizado': prompt.tituloPersonalizado,
        'idPlantillaOrigen': prompt.idPlantillaOrigen,
        'parametrosIaUsados': prompt.parametrosIaUsados != null
            ? (prompt.parametrosIaUsados!.toString())
            : null,
        'respuestaIaRecibida': prompt.respuestaIaRecibida,
        'fechaCreacion': prompt.fechaCreacion.millisecondsSinceEpoch,
        'fechaModificacion': prompt.fechaModificacion.millisecondsSinceEpoch,
        'favorito': prompt.favorito ? 1 : 0,
        'tagsPersonales': prompt.tagsPersonales != null
            ? (prompt.tagsPersonales!.join(','))
            : null,
        'carpetaOrganizacion': prompt.carpetaOrganizacion,
      },
      where: 'id = ?',
      whereArgs: [prompt.id],
    );
  }

  // Eliminar un prompt de la base de datos local
  Future<int> deletePrompt(String id) async {
    final db = await database;
    return await db.delete('prompts', where: 'id = ?', whereArgs: [id]);
  }

  // Cierra la base de datos (generalmente al cerrar la aplicación)
  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null; // Reiniciar la instancia para futuras aperturas
  }
}
