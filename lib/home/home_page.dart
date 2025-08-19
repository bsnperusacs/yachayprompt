// lib/home/home_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:collection/collection.dart';
import 'package:share_plus/share_plus.dart';
import 'package:yachay_prompts/services/pdf_export_service.dart';
import 'package:yachay_prompts/auth/auth_service.dart';
import 'package:yachay_prompts/auth/login_page.dart';
import 'package:yachay_prompts/models/education_data.dart';
import 'package:yachay_prompts/models/language_data.dart';
import 'package:yachay_prompts/models/prompt_model.dart';
import 'package:yachay_prompts/models/template_model.dart';
import 'package:yachay_prompts/models/plan_model.dart';
import 'package:yachay_prompts/pages/history_prompts_page.dart';
import 'package:yachay_prompts/pages/planes_page.dart';
import 'package:yachay_prompts/pages/template_library_page.dart';
import 'package:yachay_prompts/pages/support_contact_page.dart';
import 'package:yachay_prompts/pages/my_profile_page.dart';

import 'dart:async'; // ¡IMPORTANTE! Añadir esta importación

class HomeScreen extends StatefulWidget {
  final PlantillaPrompt? plantillaSeleccionada;
  const HomeScreen({super.key, this.plantillaSeleccionada});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- STATE & CONTROLLERS ---
  final _formKey = GlobalKey<FormState>();
  final _objetivoCtrl = TextEditingController();
  final _promptGeneradoCtrl = TextEditingController();
  final _asignaturaCtrl = TextEditingController();

  String _userName = "Usuario", _userApellido = "", _saludoHora = "Hola";
  String? _profilePictureUrl;
  bool _isGenerating = false, _isSaving = false;
  bool get _isFormularioSucio =>
      _selectedNivel != null ||
      _objetivoCtrl.text.isNotEmpty ||
      _promptGeneradoCtrl.text.isNotEmpty;

  // --- Estado para planes y formatos de respuesta ---
  String _userPlan = 'docente'; // Por defecto, el plan más básico
  bool _generarTexto = true; // Por defecto, generar texto siempre
  bool _generarImagen = false;
 
  // NUEVAS VARIABLES PARA CRÉDITOS RESTANTES
  int _promptsRestantes = 0; // Para prompts de texto
  int _imagenesRestantes = 0; // Para imágenes

  StreamSubscription? _userSubscription; // Para escuchar cambios en el usuario del AuthService

  // --- DATA ---
  final List<NivelEducativo> _nivelesEducativos = [
    NivelEducativo(id: 'inicial', nombre: 'Inicial'),
    NivelEducativo(id: 'primaria', nombre: 'Primaria'),
    NivelEducativo(id: 'secundaria', nombre: 'Secundaria'),
    NivelEducativo(id: 'tecnica', nombre: 'Técnica'),
  ];
  List<Asignatura> _asignaturas = [];
  List<Language> _idiomas = [];

  NivelEducativo? _selectedNivel;
  Asignatura? _selectedAsignatura;
  Language? _selectedIdioma;
  String? _selectedVarianteQuechua;
  final _variantesQuechua = [
    'Quechua Sureño (Estándar)',
    'Quechua Central (Ancash)',
    'Quechua Norteño',
    'Quechua Amazónico'
  ];

  // --- LIFECYCLE ---
    @override
  void initState() {
    super.initState();
    _loadInitialData();
    if (widget.plantillaSeleccionada != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _precargarPlantilla(widget.plantillaSeleccionada!);
      });
    }

    // Suscribirse a los cambios del usuario desde AuthService
    _userSubscription = AuthService().user.listen((userApp) {
      if (userApp != null && mounted) {
        setState(() {
          _userName = userApp.name.split(' ').first;
          _userApellido = userApp.paternalLastName?.split(' ').first ?? "";
          _userPlan = userApp.planContratado ?? 'demo'; // Usar 'demo' como default para planes
          _promptsRestantes = userApp.promptsRestantes ?? 0; // Ahora cargamos promptsRestantes
          _imagenesRestantes = userApp.imagenesRestantes ?? 0;
          _profilePictureUrl = userApp.profilePictureUrl;
        });
      }
    });
  }

  @override
  void dispose() {
    _objetivoCtrl.dispose();
    _promptGeneradoCtrl.dispose();
    _asignaturaCtrl.dispose();
    _userSubscription?.cancel(); // CANCELAR LA SUSCRIPCIÓN
    super.dispose();
  }

  // --- DATA & LOGIC METHODS ---
  Future<void> _loadInitialData() async {
    _updateGreeting();
    await Future.wait([_loadUserData(), _loadAsignaturas(), _loadIdiomas()]);
  }

    Future<void> _loadUserData() async {
    final userApp = AuthService().currentUserApp;

    if (userApp == null) return; 

    if (mounted) {
      setState(() {
        _userName = userApp.name.split(' ').first;
        _userApellido = userApp.paternalLastName?.split(' ').first ?? "";
        _userPlan = userApp.planContratado ?? 'demo'; // Usar 'demo' como default para planes
        _promptsRestantes = userApp.promptsRestantes ?? 0; // Asegurarse de que se cargan
        _imagenesRestantes = userApp.imagenesRestantes ?? 0;
      });
    }
  }

  Future<void> _fetchCollection<T>({
    required String collectionName,
    required T Function(Map<String, dynamic>, String) fromJson,
    required void Function(List<T>) onLoaded,
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(collectionName)
          .orderBy(collectionName == 'idiomas' ? 'name' : 'nombre')
          .get();
      if (mounted) {
        final items =
            snapshot.docs.map((doc) => fromJson(doc.data(), doc.id)).toList();
        onLoaded(items);
      }
    } catch (e) {
      _showSnackBar('Error al cargar $collectionName: $e', isError: true);
    }
  }

  Future<void> _loadAsignaturas() => _fetchCollection<Asignatura>(
        collectionName: 'asignaturas',
        fromJson: (data, id) => Asignatura.fromJson(data..['id'] = id),
        onLoaded: (items) => setState(() => _asignaturas = items),
      );

  Future<void> _loadIdiomas() => _fetchCollection<Language>(
        collectionName: 'idiomas',
        fromJson: Language.fromFirestore,
        onLoaded: (items) => setState(() {
          _idiomas = items;
          _selectedIdioma ??=
              _idiomas.firstWhereOrNull((lang) => lang.name == 'Español') ??
                  (_idiomas.isNotEmpty ? _idiomas.first : null);
        }),
      );

  Future<void> _addNewAsignatura(String newName) async {
    if (newName.isEmpty) return;
    if (_selectedNivel == null) {
      _showSnackBar('Por favor, selecciona un nivel educativo primero.',
          isError: true);
      return;
    }

    final id = newName.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    final docId = '${_selectedNivel!.id}_$id';
    final data = {'nombre': newName, 'idNivel': _selectedNivel!.id};

    try {
      await FirebaseFirestore.instance
          .collection('asignaturas')
          .doc(docId)
          .set(data);
      _showSnackBar('Asignatura "$newName" añadida.');
      await _loadAsignaturas();

      setState(() {
        _selectedAsignatura =
            _asignaturas.firstWhereOrNull((a) => a.id == docId);
        if (_selectedAsignatura != null) {
          _asignaturaCtrl.text = _selectedAsignatura!.nombre;
        }
      });
      FocusManager.instance.primaryFocus?.unfocus();
    } catch (e) {
      _showSnackBar('Error al añadir asignatura: $e', isError: true);
    }
  }

Future<void> _generarPrompt() async {
  FocusManager.instance.primaryFocus?.unfocus();
  if (!(_formKey.currentState?.validate() ?? false)) {
    _showSnackBar('Por favor, completa los campos requeridos.',
        isError: true);
    return;
  }

  // --- OBTENER INFORMACIÓN DEL USUARIO ACTUAL Y SU PLAN ---
  final currentUserApp = AuthService().currentUserApp;
  if (currentUserApp == null) {
    _showSnackBar('Error: No se pudo obtener la información del usuario.', isError: true);
    setState(() => _isGenerating = false);
    return;
  }

  final currentPlanId = currentUserApp.planContratado ?? 'demo';
  int promptsRestantesPlan = currentUserApp.promptsRestantes ?? 0;
  int promptsPaqueteDocenteRestantes = currentUserApp.promptsPaqueteDocenteRestantes ?? 0;
  int promptsPaqueteCreativoRestantes = currentUserApp.promptsPaqueteCreativoRestantes ?? 0;
  int imagenesRestantes = currentUserApp.imagenesRestantes ?? 0;
  
  // Determinar si el plan es grupal (si su ID empieza con 'grupal' o 'espacial_grupal')
  final bool esPlanGrupal = currentPlanId.startsWith('grupal') || currentPlanId.startsWith('espacial_grupal');
  
  final Plan planActual = (Plan.planesDisponibles ?? []).firstWhere(
    (p) => p.id == currentPlanId,
    orElse: () => (Plan.planesDisponibles ?? []).firstWhere((p) => p.id == 'demo'),
  );

  // --- VERIFICACIÓN DE VIGENCIA DEL PLAN ---
  final bool planVigente = planActual.esDePrueba || (currentUserApp.diasRestantes ?? 0) > 0;

  if (!planVigente) {
    _showSnackBar('Tu plan no está vigente. Renueva tu suscripción para continuar usando la aplicación.', isError: true);
    setState(() => _isGenerating = false);
    return;
  }

  // --- DETERMINAR CAMPO A CONSUMIR PARA PROMPTS ---
  String? campoPromptsAConsumir = ''; 
  int promptsDisponiblesTotales = 0; // Para mensajes de error más claros

  if (esPlanGrupal) {
    // Clientes de plan grupal: Prioridad a paquetes, luego plan.
    if (promptsPaqueteDocenteRestantes > 0) {
      campoPromptsAConsumir = 'promptsPaqueteDocenteRestantes';
      promptsDisponiblesTotales = promptsPaqueteDocenteRestantes;
    } else if (promptsPaqueteCreativoRestantes > 0) {
      campoPromptsAConsumir = 'promptsPaqueteCreativoRestantes';
      promptsDisponiblesTotales = promptsPaqueteCreativoRestantes;
    } else if (promptsRestantesPlan > 0) {
      campoPromptsAConsumir = 'promptsRestantes';
      promptsDisponiblesTotales = promptsRestantesPlan;
    } else {
      _showSnackBar('Has agotado tus créditos. Adquiere un paquete o revisa tu plan grupal.', isError: true);
      setState(() => _isGenerating = false);
      return;
    }
  } else {
    // Clientes de planes individuales/demo: Prioridad a plan, luego paquetes.
    if (promptsRestantesPlan > 0) {
      campoPromptsAConsumir = 'promptsRestantes';
      promptsDisponiblesTotales = promptsRestantesPlan;
    } else if (promptsPaqueteDocenteRestantes > 0) {
      campoPromptsAConsumir = 'promptsPaqueteDocenteRestantes';
      promptsDisponiblesTotales = promptsPaqueteDocenteRestantes;
    } else if (promptsPaqueteCreativoRestantes > 0) {
      campoPromptsAConsumir = 'promptsPaqueteCreativoRestantes';
      promptsDisponiblesTotales = promptsPaqueteCreativoRestantes;
    } else {
      _showSnackBar('Has agotado tus créditos. Adquiere un plan o compra un paquete para continuar.', isError: true);
      setState(() => _isGenerating = false);
      return;
    }
  }

  // --- VERIFICACIÓN DE CRÉDITOS PARA IMÁGENES (SI SE PIDIÓ) ---
  final bool planPermiteImagen = planActual.imagenesMax > 0;
  if (_generarImagen) {
    if (!planPermiteImagen) {
      _showSnackBar('Tu plan actual no permite la generación de imágenes.', isError: true);
      setState(() => _isGenerating = false);
      return;
    }
    if (imagenesRestantes <= 0) {
      _showSnackBar('No te quedan créditos de imágenes.', isError: true);
      setState(() => _isGenerating = false);
      return;
    }
  }

  // --- VERIFICACIÓN FINAL ANTES DE GENERAR (por si los contadores son 0 después de la lógica) ---
  if (promptsDisponiblesTotales <= 0) {
    _showSnackBar('No tienes prompts disponibles. Compra un paquete o renueva tu plan.', isError: true);
    setState(() => _isGenerating = false);
    return;
  }

  setState(() => _isGenerating = true);

  final List<String> formatos = [];
  if (_generarTexto) formatos.add('un texto detallado');
  if (_generarImagen) formatos.add('una imagen relevante');

  if (formatos.isEmpty) {
    formatos.add('un texto detallado');
  }

  final promptText = """
Actúa como un experto en pedagogía y creador de contenido educativo. Tu tarea es generar un recurso de aprendizaje detallado basado en los siguientes parámetros:

- **Nivel Educativo:** ${_selectedNivel!.nombre}
- **Asignatura:** ${_selectedAsignatura!.nombre}
- **Idioma de Salida:** ${_selectedIdioma!.name}
${_selectedIdioma?.name == 'Quechua' && _selectedVarianteQuechua != null ? "- **Variante de Quechua:** $_selectedVarianteQuechua" : ''}
- **Formato de Salida Solicitado:** ${formatos.join(' y ')}

**Objetivo Principal del Contenido:**
"${_objetivoCtrl.text.trim()}"

Por favor, desarrolla el material de forma clara, estructurada y adecuada para el público objetivo. Si se solicitó una imagen, describe la imagen ideal en detalle.
  """;

  // --- DECREMENTAR CRÉDITOS Y GUARDAR EN FIRESTORE ---
  try {
    // Decrementar el campo de prompts determinado por la lógica de priorización
    await FirebaseFirestore.instance.collection('users').doc(currentUserApp.uid).update({
      campoPromptsAConsumir: FieldValue.increment(-1), // Usamos el campo determinado
    });

    // Decrementar imagenesRestantes si se generó una imagen
    if (_generarImagen) {
      await FirebaseFirestore.instance.collection('users').doc(currentUserApp.uid).update({
        'imagenesRestantes': FieldValue.increment(-1),
      });
    }
    
    // Recargar los datos del usuario en AuthService para que la UI se actualice
    await AuthService().reloadUserFromFirestore();

    if (mounted) {
      setState(() {
        _promptGeneradoCtrl.text = promptText;
        _isGenerating = false;
      });
    }
  } catch (e) {
    _showSnackBar('Error al generar o actualizar créditos: $e', isError: true);
    if (mounted) setState(() => _isGenerating = false);
  }
}

  Future<void> _guardarPrompt() async {
    final user = AuthService().currentUser;
    if (user == null || _promptGeneradoCtrl.text.isEmpty) {
      _showSnackBar('Inicia sesión y genera un prompt para guardar.',
          isError: true);
      return;
    }

    final titulo = await _showInputDialog(
        title: 'Guardar Prompt', hintText: 'Título del prompt (opcional)');
    if (titulo == null) return; // Usuario canceló

    setState(() => _isSaving = true);
    try {
      final newPrompt = PromptGenerado(
        userId: user.uid,
        nivelEducativo: _selectedNivel?.nombre ?? 'N/A',
        asignatura: _selectedAsignatura?.nombre ?? 'N/A',
        objetivoContenido: _objetivoCtrl.text.trim(),
        idiomaPrompt: _selectedIdioma?.name ?? 'N/A',
        varianteQuechua: _selectedVarianteQuechua,
        textoPromptFinal: _promptGeneradoCtrl.text,
        tituloPersonalizado: titulo.isEmpty ? null : titulo,
        fechaCreacion: DateTime.now(),
        fechaModificacion: DateTime.now(),
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('prompts')
          .add(newPrompt.toFirestore());
      _showSnackBar('Prompt guardado exitosamente!');
    } catch (e) {
      _showSnackBar('Error al guardar prompt: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Limpia manualmente el formulario al ser llamado por el botón.
  void _limpiarFormulario() {
  FocusManager.instance.primaryFocus?.unfocus();
  setState(() {
    _formKey.currentState?.reset();
    _objetivoCtrl.clear();
    _promptGeneradoCtrl.clear();
    _asignaturaCtrl.clear();
    _selectedNivel = null;
    _selectedAsignatura = null;
    _selectedVarianteQuechua = null;
    _selectedIdioma = null; 
    _generarTexto = true;
    _generarImagen = false;
  });
  _showSnackBar('Listo para un nuevo prompt.');
}


  void _precargarPlantilla(PlantillaPrompt p) {
    if (!mounted) return; // Añadida guardia al inicio
    if (_idiomas.isEmpty || _asignaturas.isEmpty) {
      _showSnackBar('Espera a que los datos carguen para usar una plantilla.');
      return;
    }
    // Limpiamos antes de cargar para no mezclar estados.
    _limpiarFormulario();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      setState(() {
        _selectedNivel = _nivelesEducativos
            .firstWhereOrNull((n) => n.id == p.idNivelSugerido);
        _objetivoCtrl.text = p.descripcionPlantilla ?? '';
        _promptGeneradoCtrl.clear();
        _selectedIdioma = _idiomas.firstWhereOrNull((lang) => lang.id == p.idiomaPlantilla);
        _selectedAsignatura = _asignaturas.firstWhereOrNull(
          (a) => a.id == p.idAsignaturaSugerida || a.nombre.toLowerCase() == p.idAsignaturaSugerida?.toLowerCase()
        );
        if (_selectedAsignatura != null) {
          _asignaturaCtrl.text = _selectedAsignatura!.nombre;
        } else {
          _asignaturaCtrl.text = p.idAsignaturaSugerida ?? '';
        }
        
        // Ajustar los checkboxes de formato según el tipo de plantilla si es necesario
        // Por defecto, las plantillas generan texto. Si la plantilla es de imagen, se marcaría.
        _generarTexto = true; // Por defecto siempre se genera texto
        _generarImagen = p.tituloPlantilla.toLowerCase().contains('imagen') || 
                         p.tituloPlantilla.toLowerCase().contains('creativo');
      });
      _showSnackBar('Plantilla "${p.tituloPlantilla}" cargada.');
    });
  }

void _precargarDesdePromptGuardado(PromptGenerado prompt) {
  if (!mounted) return; // Añadida guardia al inicio
  _limpiarFormulario(); // Limpiamos el formulario antes de cargar el guardado

  setState(() {
    _promptGeneradoCtrl.text = prompt.textoPromptFinal; // Asegurarse de cargar el texto final
    _objetivoCtrl.text = prompt.objetivoContenido;
    _selectedVarianteQuechua = prompt.varianteQuechua;

    _selectedNivel = _nivelesEducativos
        .firstWhereOrNull((n) => n.nombre == prompt.nivelEducativo);

    _selectedIdioma = _idiomas
        .firstWhereOrNull((lang) => lang.name == prompt.idiomaPrompt);

    _selectedAsignatura = null;
    if (_selectedNivel != null) {
      _selectedAsignatura = _asignaturas.firstWhereOrNull((a) =>
          a.nombre.trim().toLowerCase() == prompt.asignatura.trim().toLowerCase() &&
          a.idNivel == _selectedNivel!.id);
    }

    _asignaturaCtrl.text = prompt.asignatura;

    // Asumir que un prompt guardado solo tiene texto. Si tuviera un indicador de imagen,
    // se podría añadir lógica para _generarImagen. Por ahora, asumimos solo texto.
    _generarTexto = true;
    _generarImagen = false;
  });

  _showSnackBar('Prompt "${prompt.tituloPersonalizado ?? 'guardado'}" cargado.');
}

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    setState(() => _saludoHora = hour < 12
        ? 'Buenos días'
        : (hour < 18 ? 'Buenas tardes' : 'Buenas noches'));
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Remueve cualquier snackbar anterior para evitar apilamiento
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Theme.of(context).colorScheme.secondary, // Colores más claros para éxito
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating, // Para que flote sobre el FAB
      ),
    );
  }

  Future<String?> _showInputDialog(
      {required String title, required String hintText}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: hintText),
            autofocus: true),
        actions: [
          TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop()),
          ElevatedButton(
              child: const Text('Aceptar'),
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim())),
        ],
      ),
    );
  }

  void _signOut() async {
    await AuthService().signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false);
    }
  }

  // --- WIDGET BUILDERS ---

  Widget _buildOfertaDescuento() {
    return Card(
      color: Colors.amber.shade100,
      margin: const EdgeInsets.only(bottom: 24.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.sell, color: Colors.brown),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                '¡Activa tu primer plan con un super descuento!',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.brown),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PlanesPage())),
              child: const Text('Ver Planes'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F0),
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Muestra el banner de oferta SOLO si el plan es 'demo'
              if (_userPlan == 'demo') _buildOfertaDescuento(),
              _buildInputCard(),
              const SizedBox(height: 24),
              _buildGenerateButton(),
              const SizedBox(height: 24),
              if (_promptGeneradoCtrl.text.isNotEmpty || _isGenerating)
                _buildOutputCard(),
            ],
          ),
        ),
      ),
     );
  }

  AppBar _buildAppBar() {
    final theme = Theme.of(context);
    return AppBar(
      toolbarHeight: 80,
      title: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$_saludoHora,',
                style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimary.withAlpha(204))),
            Text('$_userName $_userApellido',
                style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      elevation: 8,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Limpiar y empezar de nuevo',
          onPressed: _isFormularioSucio ? _limpiarFormulario : null,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Drawer _buildDrawer() {
    final theme = Theme.of(context);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text('$_userName $_userApellido',
                style:
                    theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
            accountEmail: Text(AuthService().currentUser?.email ?? 'No email',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.white70)),
                                currentAccountPicture: CircleAvatar(
                      backgroundColor: theme.colorScheme.onPrimary,
                      backgroundImage: (_profilePictureUrl != null && _profilePictureUrl!.isNotEmpty)
                          ? NetworkImage(_profilePictureUrl!)
                          : null,
                      child: (_profilePictureUrl == null || _profilePictureUrl!.isEmpty)
                          ? Icon(Icons.person, color: theme.colorScheme.primary)
                          : null,
                    ),
          ),
                    _buildDrawerItem(
            icon: Icons.account_circle, 
            title: 'Mi Perfil', 
            onTap: () {
              Navigator.pop(context); 
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MyProfilePage())); 
            },
          ),
          _buildDrawerItem(
              icon: Icons.auto_awesome,
              title: 'Generar Prompt',
              onTap: () => Navigator.pop(context)),
          _buildDrawerItem(
            icon: Icons.history,
            title: 'Historial',
            onTap: () async {
              Navigator.pop(context);
              final resultado = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryPromptsPage()),
              );
              if (!mounted) return;
              if (resultado is PromptGenerado) {
               _precargarDesdePromptGuardado(resultado);
              }
            },
          ),
          _buildDrawerItem(
              icon: Icons.library_books,
              title: 'Biblioteca',
              onTap: () async {
                Navigator.pop(context); // Cierra el Drawer
                // 🔥 ESTE ES EL CAMBIO CLAVE: Esperar el resultado como un Map 🔥
                final Map<String, dynamic>? plantillaData = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(builder: (_) => const TemplateLibraryPage()),
                );
                
                // ✅ Verificar si el widget aún está montado antes de usar 'context'
                if (!mounted) return; 

                // Si se recibieron datos de plantilla (es decir, se presionó "Usar esta plantilla")
                if (plantillaData != null) {
                  // Convertimos el Map a tu modelo PlantillaPrompt
                  // ¡IMPORTANTE! Asegúrate que los nombres de las claves (ej. 'titulo', 'contenido')
                  // coincidan exactamente con cómo están en Firestore y en tu modelo PlantillaPrompt.
                  final PlantillaPrompt plantillaSeleccionada = PlantillaPrompt(
                      id: plantillaData['id'] as String, // <-- ¡AÑADE ESTA LÍNEA!
                      tituloPlantilla: plantillaData['titulo'] ?? '',
                      descripcionPlantilla: plantillaData['descripcion'] ?? '',
                      textoPlantillaBase: plantillaData['contenido'] ?? '',
                      idiomaPlantilla: plantillaData['idioma'] ?? '',
                      idNivelSugerido: plantillaData['nivel_sugerido'],
                      idAsignaturaSugerida: plantillaData['asignatura_sugerida'],
                      tags: List<String>.from(plantillaData['tags'] ?? []),
                      idAutorPlantilla: plantillaData['autor_plantilla'],
                    );
                  _precargarPlantilla(plantillaSeleccionada);
                }
              }),

          _buildDrawerItem(
              icon: Icons.star,
              title: 'Planes',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PlanesPage())),
              color: Colors.amber.shade700),

            
          _buildDrawerItem(
            icon: Icons.support_agent, 
            title: 'Soporte y Contacto', 
            onTap: () {
              Navigator.pop(context); 
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SupportContactPage())); 
            },
          ),

          const Divider(),
          _buildDrawerItem(
              icon: Icons.logout, title: 'Cerrar Sesión', onTap: _signOut),
        ],
      ),
    );
  }

  ListTile _buildDrawerItem(
      {required IconData icon,
      required String title,
      required VoidCallback onTap,
      Color? color}) {
    return ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        onTap: onTap,
        dense: true);
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required String Function(T) itemAsString,
    bool enabled = true,
    bool isRequired = true,
  }) {
    return DropdownButtonFormField2<T>(
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      value: value,
      items: items
          .map((item) => DropdownMenuItem<T>(
                value: item,
                child: Text(itemAsString(item)),
              ))
          .toList(),
      onChanged: enabled ? onChanged : null,
      validator: (val) {
        if (val == null && isRequired) {
          return 'Este campo es requerido.';
        }
        return null;
      },
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }

  Widget _buildInputCard() {
    final theme = Theme.of(context);
    return Card(
      elevation: 8.0,
      shadowColor: const Color.fromARGB(255, 0, 0, 0).withAlpha(78),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Define los Parámetros',
                style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.black87, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildDropdown<NivelEducativo>(
                label: 'Nivel Educativo*',
                value: _selectedNivel,
                items: _nivelesEducativos,
                onChanged: (v) => setState(() {
                      _selectedNivel = v;
                      _selectedAsignatura = null;
                      _asignaturaCtrl.clear();
                    }),
                itemAsString: (i) => i.nombre),
            const SizedBox(height: 16),
            if (_selectedNivel != null)
              _buildAsignaturaAutocomplete()
            else
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Asignatura*',
                  hintText: 'Selecciona un nivel educativo primero',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                enabled: false,
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _objetivoCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Objetivo del Contenido / Tema*',
                hintText: 'Ej: Explicar el ciclo del agua a niños de 8 años.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Ingresa el objetivo.'
                  : null,
            ),
            const SizedBox(height: 16),
            _buildDropdown<Language>(
                label: 'Idioma*',
                value: _selectedIdioma,
                items: _idiomas,
                onChanged: (v) => setState(() {
                      _selectedIdioma = v;
                      if (v?.name != 'Quechua') _selectedVarianteQuechua = null;
                    }),
                itemAsString: (i) => i.name),
            if (_selectedIdioma?.name == 'Quechua') ...[
              const SizedBox(height: 16),
              _buildDropdown<String>(
                  label: 'Variante Quechua (Opcional)',
                  value: _selectedVarianteQuechua,
                  items: _variantesQuechua,
                  onChanged: (v) =>
                      setState(() => _selectedVarianteQuechua = v),
                  itemAsString: (s) => s,
                  isRequired: false),
            ],
            const SizedBox(height: 20),
            // La visibilidad de este bloque ahora depende del plan
            // El plan 'docente' ya no debería permitir checkboxes
            if (_userPlan != 'docente') _buildTipoRespuestaCheckboxes(), 
          ],
        ),
      ),
    );
  }

// En lib/home/home_page.dart

  Widget _buildAsignaturaAutocomplete() {
    return Autocomplete<Asignatura>(
      displayStringForOption: (Asignatura option) => option.nombre,
      optionsBuilder: (TextEditingValue textEditingValue) {
        // --- CORRECCIÓN CLAVE AQUÍ: Asegurar que el nivel está seleccionado ---
        // Si no hay un nivel educativo seleccionado, no podemos ofrecer sugerencias de asignaturas.
        if (_selectedNivel == null) {
          return const Iterable<Asignatura>.empty(); // Devuelve una lista vacía de sugerencias
        }

        // Filtra todas las asignaturas que 
        final asignaturasDisponibles = _asignaturas;// Convertimos a lista para poder filtrar por texto a continuación.

        // Si el usuario no ha escrito nada, mostramos todas las asignaturas de ese nivel.
        if (textEditingValue.text.isEmpty) {
           return _asignaturas;
        }

        // Filtra las asignaturas de ese nivel que coinciden con el texto que el usuario está escribiendo.
       return asignaturasDisponibles.where((Asignatura option) {
          return option.nombre
              .trim()
              .toLowerCase()
              .contains(textEditingValue.text
                  .trim()
                  .toLowerCase());
        });
      },
      onSelected: (Asignatura selection) {
        setState(() {
          _selectedAsignatura = selection;
          _asignaturaCtrl.text = selection.nombre;
        });
        FocusManager.instance.primaryFocus?.unfocus();
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        textEditingController.text = _asignaturaCtrl.text; // Asegura que el controlador del campo de vista tenga el texto del controlador principal
        return TextFormField(
          controller: textEditingController, // Este es el controlador del TextFormField del Autocomplete
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Asignatura*',
            hintText: 'Haz clic para ver o escribe para buscar...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.green),
              tooltip: 'Crear nueva asignatura',
              onPressed: () {
                // --- CAMBIO CLAVE AQUÍ: Usar textEditingController para obtener el texto actual del campo ---
                final text = textEditingController.text.trim(); 

                // Si no hay un nivel seleccionado, no se puede añadir una asignatura.
                if (_selectedNivel == null) {
                  _showSnackBar('Por favor, selecciona un nivel educativo primero para añadir asignaturas.', isError: true);
                  return;
                }
                // Si el campo de texto está vacío, no se puede añadir.
                if (text.isEmpty) {
                  _showSnackBar('Por favor, escribe el nombre de la asignatura para añadirla.', isError: true);
                  return;
                }

                // Comprueba si la asignatura YA EXISTE para el nivel seleccionado.
                final exists = _asignaturas.any((a) =>
                    a.nombre.toLowerCase() == text.toLowerCase() &&
                    a.idNivel == _selectedNivel!.id); 

                if (!exists) { // Si NO existe, entonces la añadimos.
                  _addNewAsignatura(text);
                } else { // Si SÍ existe (según la comprobación), mostramos el mensaje.
                  _showSnackBar('Esa asignatura ya existe para este nivel.');
                }
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Busca o crea una asignatura.';
            }
            // --- CORRECCIÓN CLAVE AQUÍ: Comprobación en el validador ---
            // Si no hay nivel seleccionado, la validación falla.
            if (_selectedNivel == null) {
              return 'Selecciona un nivel educativo primero.';
            }
            // --- FIN DE LA CORRECCIÓN ---

            // Busca si la asignatura existe exactamente para el nivel actual.
            final existingAsignatura = _asignaturas.firstWhereOrNull((a) =>
            a.nombre.toLowerCase() == value.toLowerCase());


            if (existingAsignatura == null) { // Si no la encuentra, significa que no existe o no es para ese nivel.
              return 'Asignatura no existe para este nivel. Usa el botón "+" para crearla.';
            }

            // Si la asignatura existe y es válida, aseguramos que _selectedAsignatura esté asignada.
            _selectedAsignatura = existingAsignatura;
            return null;
          },
        );
      },
    );
  }

  Widget _buildTipoRespuestaCheckboxes() {
    final theme = Theme.of(context);
    final int selectedCount = (_generarTexto ? 1 : 0) + (_generarImagen ? 1 : 0);
    
    final Plan planActual = (Plan.planesDisponibles ?? []).firstWhere(
      (p) => p.id == _userPlan,
      orElse: () => (Plan.planesDisponibles ?? []).firstWhere((p) => p.id == 'demo'),
    );
    final bool planPermiteImagen = planActual.imagenesMax > 0; 

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Formato de Respuesta Solicitado:',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        // 🔥 CONTADORES INTEGRADOS EN LOS CheckboxListTile 🔥
        Column( // Este Column mantiene las casillas una debajo de la otra
          children: [
            CheckboxListTile(
              // ✅ Contador de Prompts al lado del texto "Texto"
              title: Text('Texto ($_promptsRestantes restante${_promptsRestantes == 1 ? '' : 's'})'),
              secondary: const Icon(Icons.description_outlined),
              value: _generarTexto,
              onChanged: (value) {
                if (value == false && selectedCount == 1) return;
                setState(() => _generarTexto = value!);
              },
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              // ✅ Contador de Imágenes al lado del texto "Imagen"
              title: Text('Imagen ($_imagenesRestantes restante${_imagenesRestantes == 1 ? '' : 's'})'), //
              secondary: const Icon(Icons.image_outlined),
              value: _generarImagen,
              onChanged: (value) {
                if (!planPermiteImagen || (_imagenesRestantes <= 0 && value == true)) {
                  if (value == true) {
                    _showSnackBar(planPermiteImagen
                        ? 'No te quedan créditos de imagen.'
                        : 'Tu plan actual no incluye generación de imágenes.',
                        isError: true);
                  }
                  return;
                }
                if (value == false && selectedCount == 1) return;
                setState(() => _generarImagen = value!);
              },
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildGenerateButton() {
    // Determinar si el plan actual permite generar imagen (basado en imagenesMax > 0)
    final Plan planActual = (Plan.planesDisponibles ?? []).firstWhere(
      (p) => p.id == _userPlan,
      orElse: () => (Plan.planesDisponibles ?? []).firstWhere((p) => p.id == 'demo'),
    );
    final bool planPermiteImagen = planActual.imagenesMax > 0;

    // La validación de formato aquí es para asegurar que al menos un checkbox esté marcado
    // Y que si _generarImagen está activado, el plan lo permita.
    final bool isFormatoValido = (_generarTexto || (_generarImagen && planPermiteImagen));
        
    return ElevatedButton.icon(
      onPressed: (_isGenerating || !isFormatoValido || _promptsRestantes <= 0) ? null : _generarPrompt,
      icon: _isGenerating
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.auto_awesome),
      label: Text(_isGenerating
          ? 'GENERANDO...'
          : (isFormatoValido
              ? (_promptsRestantes <= 0 ? 'Sin créditos. Compra un paquete' : '2. GENERAR PROMPT')
              : 'Selecciona un formato')),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildOutputCard() {
    final theme = Theme.of(context);
    return Card(
      elevation: 8.0,
      shadowColor: Colors.black.withAlpha(78),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('3. Resultado',
                style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.black87, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _promptGeneradoCtrl,
              readOnly: true,
              maxLines: 10,
              minLines: 5,
              decoration: InputDecoration(
                hintText: 'Tu prompt generado aparecerá aquí.',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    bool isPromptEmpty = _promptGeneradoCtrl.text.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isPromptEmpty || _isSaving ? null : _guardarPrompt,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Guardando...' : 'Guardar'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.outlined(
                icon: const Icon(Icons.share),
                tooltip: 'Compartir Prompt',
                onPressed: isPromptEmpty
                    ? null
                    : () {
                      // ignore: deprecated_member_use
                      Share.share(_promptGeneradoCtrl.text); 
                      }),
            IconButton.outlined(
              icon: const Icon(Icons.download),
              tooltip: 'Descargar como PDF',
              onPressed: isPromptEmpty
                  ? null
                  : () => PdfExportService.descargarPdf(
                      context: context,
                      promptText: _promptGeneradoCtrl.text,
                      titulo: 'Prompt Personalizado'),
            ),
          ],
        ),
      ],
    );
  }
}