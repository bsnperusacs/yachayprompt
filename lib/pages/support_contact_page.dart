import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yachay_prompts/auth/auth_service.dart'; // Importar AuthService
import 'package:yachay_prompts/models/user_model.dart'; // Importar UserApp
import 'package:cloud_firestore/cloud_firestore.dart'; // Importar Firestore
// import 'package:collection/collection.dart'; // Removido: No se usa firstWhereOrNull directamente aquí en esta version
import 'package:intl/intl.dart'; // Para formatear fechas
import 'package:uuid/uuid.dart'; // Para generar IDs únicos para reclamos
// Removidas las importaciones de PDF y file_opener ya que no se usan en esta pantalla
// import 'package:path_provider/path_provider.dart'; 
// import 'package:open_filex/open_filex.dart'; 
// import 'package:pdf/pdf.dart'; 
// import 'package:pdf/widgets.dart' as pw; 


class SupportContactPage extends StatefulWidget {
  const SupportContactPage({super.key});

  @override
  State<SupportContactPage> createState() => _SupportContactPageState();
}

class _SupportContactPageState extends State<SupportContactPage> {
  final _contactFormKey = GlobalKey<FormState>();
  final _claimFormKey = GlobalKey<FormState>();

  // Controladores para formulario de contacto general
  final TextEditingController _contactNameCtrl = TextEditingController();
  final TextEditingController _contactMessageCtrl = TextEditingController();

  // Controladores para formulario de Libro de Reclamaciones
  final TextEditingController _consumerNameCtrl = TextEditingController();
  final TextEditingController _consumerDocTypeCtrl = TextEditingController(); // Tipo de Documento
  final TextEditingController _consumerDocNumCtrl = TextEditingController(); // Número de Documento (DNI/CE/RUC)
  final TextEditingController _consumerAddressCtrl = TextEditingController(); // Dirección de calle
  final TextEditingController _consumerDeptCtrl = TextEditingController(); // Departamento
  final TextEditingController _consumerProvCtrl = TextEditingController(); // Provincia
  final TextEditingController _consumerDistCtrl = TextEditingController(); // Distrito (Ciudad de registro)
  final TextEditingController _consumerPhoneCtrl = TextEditingController();
  final TextEditingController _consumerEmailCtrl = TextEditingController();

  // Bien Contratado
  final TextEditingController _productDescCtrl = TextEditingController();
  final TextEditingController _productAmountCtrl = TextEditingController();
  final TextEditingController _productDateCtrl = TextEditingController();
  String? _selectedGoodsType; // 'Producto' o 'Servicio'

  // Detalle del Reclamo
  final TextEditingController _claimDescriptionCtrl = TextEditingController();
  final TextEditingController _consumerRequestCtrl = TextEditingController();
  String? _selectedClaimType; // 'Reclamo' o 'Queja'

  bool _isSendingClaim = false;
  bool _agreedToTerms = false;
  bool _showClaimForm = false; // Controla la visibilidad del formulario de reclamaciones
  UserApp? _currentUserApp; // Para datos del usuario logueado

  // Listas para Dropdowns
  final List<String> _docTypes = ['DNI', 'CE', 'Pasaporte', 'RUC']; // Añadido RUC
  final List<String> _goodsTypes = ['Producto', 'Servicio'];
  final List<String> _claimTypes = ['Reclamo', 'Queja']; 

  @override
  void initState() {
    super.initState();
    _loadUserDataAndPrepopulateForm();
  }

  @override
  void dispose() {
    _contactNameCtrl.dispose();
    _contactMessageCtrl.dispose();
    _consumerNameCtrl.dispose();
    _consumerDocTypeCtrl.dispose();
    _consumerDocNumCtrl.dispose();
    _consumerAddressCtrl.dispose();
    _consumerDeptCtrl.dispose();
    _consumerProvCtrl.dispose();
    _consumerDistCtrl.dispose();
    _consumerPhoneCtrl.dispose();
    _consumerEmailCtrl.dispose();
    _productDescCtrl.dispose();
    _productAmountCtrl.dispose();
    _productDateCtrl.dispose();
    _claimDescriptionCtrl.dispose();
    _consumerRequestCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserDataAndPrepopulateForm() async {
    _currentUserApp = AuthService().currentUserApp;
    if (_currentUserApp != null) {
      // Precarga de datos del consumidor: Nombre y Correo (siempre readOnly)
      _consumerNameCtrl.text = _currentUserApp!.name; 
      _consumerEmailCtrl.text = _currentUserApp!.email; 

      // Número de Celular: Precargado si existe en el perfil, editable si está vacío.
      _consumerPhoneCtrl.text = _currentUserApp!.numeroCelular ?? '';

      // Tipo de Documento: Precargado si existe en el perfil, sino 'DNI' por defecto.
      // Será de solo lectura si el número de documento ya existe.
      _consumerDocTypeCtrl.text = _currentUserApp!.documentType ?? 'DNI'; 
      // Número de Documento: Precargado con el DNI/CE/RUC registrado del usuario.
      // Será de solo lectura si ya existe.
      _consumerDocNumCtrl.text = _currentUserApp!.dni ?? ''; 

      // Dirección (Calle, Av.): Precargado si existe en el perfil. Si no, queda en blanco y será editable.
      _consumerAddressCtrl.text = _currentUserApp!.fullAddress ?? ''; 

      // Departamento y Provincia: Precargados si existen en el perfil. Si no, quedan en blanco y serán editables.
      _consumerDeptCtrl.text = _currentUserApp!.department ?? '';
      _consumerProvCtrl.text = _currentUserApp!.province ?? '';

      // Distrito: Precargado con la 'ciudadResidencia' del registro. Siempre tendrá un valor y será de solo lectura.
      _consumerDistCtrl.text = _currentUserApp!.ciudadResidencia ?? ''; 
    }
  }

  // Métodos de lanzamiento (WhatsApp, Email, Política)
  Future<void> _launchWhatsApp() async {
    final uri = Uri.parse("https://wa.me/51900120286");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar('No se pudo abrir WhatsApp. Asegúrate de tener la aplicación instalada.');
    }
  }

  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'soporte@yachayprompts.com',
      query: 'subject=Soporte&body=Hola, necesito ayuda con...',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar('No se pudo abrir el cliente de correo. Verifica que tengas uno configurado.');
    }
  }

  Future<void> _launchPolicy() async {
    final uri = Uri.parse("https://yachay-prompts.web.app/index.html"); 
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar('No se pudo abrir la política de privacidad. Verifica tu conexión a internet o la URL.');
    }
  }

void _sendMessage() async {
  if (_contactFormKey.currentState!.validate()) {
    final nombre = _contactNameCtrl.text.trim();
    final mensaje = _contactMessageCtrl.text.trim(); 

    // 🔥 NÚMERO DE WHATSAPP PARA SUGERENCIAS 🔥
    const String suggestionsPhoneNumber = "51942518632"; // ¡CAMBIA ESTE NÚMERO AL DE SUGERENCIAS!

    final String whatsappMessage = "Hola, mi nombre es $nombre. Tengo la siguiente sugerencia: $mensaje";
    final String encodedMessage = Uri.encodeComponent(whatsappMessage); 

    // 🔥 Usar el número de sugerencias aquí 🔥
    final Uri whatsappUri = Uri.parse("https://wa.me/$suggestionsPhoneNumber?text=$encodedMessage");

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        _showSnackBar("Abriendo WhatsApp con tu sugerencia. Por favor, envía desde allí.");
        _contactNameCtrl.clear();
        _contactMessageCtrl.clear();
      } else {
        _showSnackBar('No se pudo abrir WhatsApp. Asegúrate de tener la aplicación instalada y conéctate a internet.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error al intentar abrir WhatsApp: ${e.toString()}', isError: true);
    }
  }
}
  Future<void> _submitReclamacion() async { 
    if (!_claimFormKey.currentState!.validate()) {
      _showSnackBar('Por favor, completa todos los campos obligatorios del libro de reclamaciones.', isError: true);
      return;
    }
    if (!_agreedToTerms) {
      _showSnackBar('Debes aceptar la declaración de veracidad para enviar la reclamación.', isError: true);
      return;
    }

    if (_currentUserApp == null) {
      _showSnackBar('Error: No se pudo obtener la información de tu usuario. Por favor, inicia sesión de nuevo.', isError: true);
      return;
    }

    setState(() {
      _isSendingClaim = true;
    });

    try {
      final uuid = const Uuid();
      final reclamacionId = uuid.v4(); 
      
      final String numeroReclamo = 'REC-${reclamacionId.substring(0,8).toUpperCase()}'; 

      // Datos del consumidor (tomados de los controladores)
      final String consumerName = _consumerNameCtrl.text.trim();
      final String consumerEmail = _consumerEmailCtrl.text.trim();
      final String consumerPhone = _consumerPhoneCtrl.text.trim();
      final String consumerDocType = _consumerDocTypeCtrl.text.trim(); 
      final String consumerDocNum = _consumerDocNumCtrl.text.trim();
      final String consumerAddress = _consumerAddressCtrl.text.trim(); 
      final String consumerDept = _consumerDeptCtrl.text.trim();       
      final String consumerProv = _consumerProvCtrl.text.trim();       
      final String consumerDist = _consumerDistCtrl.text.trim();       

      // Datos del bien/servicio
      final String productDesc = _productDescCtrl.text.trim();
      final String productAmount = _productAmountCtrl.text.trim();
      final String productDate = _productDateCtrl.text.trim();
      final String selectedGoodsType = _selectedGoodsType ?? 'Servicio'; 

      // Detalles del reclamo
      final String claimDescription = _claimDescriptionCtrl.text.trim();
      final String consumerRequest = _consumerRequestCtrl.text.trim();
      final String selectedClaimType = _selectedClaimType ?? 'Reclamo'; 

      // 2. Crear documento de reclamación en Firestore
      await FirebaseFirestore.instance.collection('reclamaciones').doc(reclamacionId).set({
        'userId': _currentUserApp!.uid,
        'claimId': reclamacionId, 
        'numeroReclamo': numeroReclamo, 
        'status': 'Pendiente', 
        'submissionDate': FieldValue.serverTimestamp(),
        // Datos del consumidor
        'consumerName': consumerName,
        'consumerEmail': consumerEmail,
        'consumerPhone': consumerPhone,
        'consumerDocType': consumerDocType,
        'consumerDocNum': consumerDocNum,
        'consumerAddress': consumerAddress,
        'consumerDept': consumerDept,
        'consumerProv': consumerProv,
        'consumerDist': consumerDist, 
        // Datos del bien/servicio
        'goodsType': selectedGoodsType,
        'productDescription': productDesc,
        'productAmount': productAmount,
        'productDate': productDate,
        // Detalles del reclamo
        'claimType': selectedClaimType,
        'claimDescription': claimDescription,
        'consumerRequest': consumerRequest,
        // Campos para respuesta del proveedor (inicialmente vacíos)
        'providerResponse': '',
        'responseDate': null,
      });

      // 3. Actualizar el perfil del usuario con los nuevos datos, si fueron ingresados/modificados
      Map<String, dynamic> userProfileUpdates = {};
      
      // Número de Celular: Actualizar si cambió o si se ingresó por primera vez
      if ((_currentUserApp!.numeroCelular ?? '') != _consumerPhoneCtrl.text.trim()) {
        userProfileUpdates['numeroCelular'] = _consumerPhoneCtrl.text.trim();
      }

      // DNI: Actualizar si cambió o si se ingresó por primera vez
      if ((_currentUserApp!.dni ?? '') != _consumerDocNumCtrl.text.trim()) {
        userProfileUpdates['dni'] = _consumerDocNumCtrl.text.trim();
      }
      
      // Tipo de Documento: Actualizar si cambió o se ingresó por primera vez
      if ((_currentUserApp!.documentType ?? '') != _consumerDocTypeCtrl.text.trim()) {
        userProfileUpdates['documentType'] = _consumerDocTypeCtrl.text.trim();
      }

      // Dirección (calle): Actualizar si cambió o se ingresó por primera vez
      if ((_currentUserApp!.fullAddress ?? '') != _consumerAddressCtrl.text.trim()) {
        userProfileUpdates['fullAddress'] = _consumerAddressCtrl.text.trim();
      }

      // Departamento: Actualizar si cambió o se ingresó por primera vez
      if ((_currentUserApp!.department ?? '') != _consumerDeptCtrl.text.trim()) {
        userProfileUpdates['department'] = _consumerDeptCtrl.text.trim();
      }

      // Provincia: Actualizar si cambió o se ingresó por primera vez
      if ((_currentUserApp!.province ?? '') != _consumerProvCtrl.text.trim()) {
        userProfileUpdates['province'] = _consumerProvCtrl.text.trim();
      }
      
      // Distrito (Ciudad de registro): Actualizar si cambió o si se ingresó por primera vez
      if ((_currentUserApp!.ciudadResidencia ?? '') != _consumerDistCtrl.text.trim()) {
         userProfileUpdates['ciudadResidencia'] = _consumerDistCtrl.text.trim();
      }

      if (userProfileUpdates.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(_currentUserApp!.uid).update(userProfileUpdates);
        await AuthService().reloadUserFromFirestore(); 
      }

      _showSnackBar('¡Reclamación enviada con éxito! Número de reclamo: $numeroReclamo', isError: false);
      
      _claimFormKey.currentState?.reset();
      setState(() {
        _agreedToTerms = false;
        _productDateCtrl.clear(); 
        _selectedGoodsType = null;
        _selectedClaimType = null;
        _showClaimForm = false; 
      });
      await _loadUserDataAndPrepopulateForm(); 

    } catch (e) {
      _showSnackBar('Error al enviar la reclamación: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSendingClaim = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError
          ? Theme.of(context).colorScheme.error
          : Theme.of(context).colorScheme.secondary,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // --- WIDGETS AUXILIARES GENERALES ---

  Widget _infoCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(title),
          subtitle: Text(subtitle),
          onTap: onTap,
        ),
      ), // Cierre del Card
    ); // Cierre del Padding
  } // Cierre del método _infoCard

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple),
      ),
    );
  }

  // Este es para campos que SIEMPRE son readOnly y solo muestran el valor del perfil
  Widget _buildReadOnlyTextField({
    required TextEditingController controller,
    required String label,
    required String value,
    bool isRequired = false,
  }) {
    controller.text = value; 
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: true, 
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey[100], 
        ),
        validator: isRequired && value.isEmpty ? (val) => '$label es obligatorio.' : null,
      ),
    );
  }

  // Este es para campos que pueden ser editables SI el valor del perfil está vacío
  // O que son siempre editables si no se precargan (como DNI si no está en UserApp, etc.)
  Widget _buildEditableOrReadOnlyTextField({
    required TextEditingController controller,
    required String label,
    required String value, 
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = false,
  }) {
    // Si el valor que viene del perfil está vacío (o es null), el campo es editable.
    // De lo contrario (si hay valor), es de solo lectura.
    final bool readOnly = value.isNotEmpty; 
    
    // Solo precargar el controlador si está vacío o si el valor es diferente
    // para evitar sobrescribir lo que el usuario está escribiendo si el campo es editable.
    if (controller.text.isEmpty || (readOnly && controller.text != value)) {
        controller.text = value; 
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly, 
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: readOnly ? Colors.grey[100] : Colors.white, 
        ),
        validator: (val) {
          if (isRequired && (val == null || val.isEmpty)) {
            return '$label es obligatorio.';
          }
          // Validación específica para DNI en Número de Documento
          if (label == 'Número de Documento' && _consumerDocTypeCtrl.text == 'DNI' && val != null && val.isNotEmpty) {
            if (val.length != 8 || !RegExp(r'^\d{8}$').hasMatch(val)) {
              return 'El DNI debe tener 8 dígitos numéricos.';
            }
          }
          return null;
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return '$label es obligatorio.';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdownFormField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
    bool isRequired = false,
    bool readOnly = false, // Nuevo parámetro para hacerlo de solo lectura
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: readOnly ? Colors.grey[100] : Colors.white, 
        ),
        value: value,
        onChanged: readOnly ? null : onChanged, // Si es readOnly, onChanged es null para deshabilitarlo
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(item),
          );
        }).toList(),
        validator: (val) {
          if (isRequired && (val == null || val.isEmpty)) {
            return '$label es obligatorio.';
          }
          return validator?.call(val);
        },
        isExpanded: true,
      ),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        onTap: () async {
          DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
          );
          if (pickedDate != null) {
            controller.text = DateFormat('dd/MM/yyyy').format(pickedDate);
          }
        },
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return '$label es obligatorio.';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Si el usuario no está logueado o sus datos no se cargaron, mostrar mensaje
    if (_currentUserApp == null && _isSendingClaim == false) { 
      return Scaffold(
        appBar: AppBar(title: const Text("Soporte y Contacto")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_off, size: 60, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Por favor, inicia sesión para acceder a todas las funcionalidades de soporte.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); 
                  },
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        )
        );
      }

      // Si el usuario está logueado, construir el layout principal
      return Scaffold(
        appBar: AppBar(
          title: const Text("Soporte y Contacto"),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Sección de Información de Contacto ---
              Card(
                margin: const EdgeInsets.only(bottom: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Información de Contacto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const Divider(height: 20),
                      _infoCard(
                        icon: Icons.email,
                        color: Colors.blue,
                        title: "Correo de soporte",
                        subtitle: "soporte@yachayprompts.com",
                        onTap: _launchEmail,
                      ),
                      _infoCard(
                        icon: Icons.phone,
                        color: Colors.green,
                        title: "WhatsApp / Teléfono",
                        subtitle: "+51 900 120 286",
                        onTap: _launchWhatsApp,
                      ),
                        _infoCard(
                        icon: Icons.privacy_tip,
                        color: Colors.indigo,
                        title: "Política de privacidad",
                        subtitle: "Ver términos y condiciones",
                        onTap: _launchPolicy,
                      ),
                    ],
                  ),
                ),
              ),

              // --- Sección de Formulario de Mensaje General ---
              Card(
                margin: const EdgeInsets.only(bottom: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "¿Tienes alguna sugerencia? Escríbenos:",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const Divider(height: 20),
                      Form(
                        key: _contactFormKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _contactNameCtrl,
                              decoration: const InputDecoration(
                                labelText: "Tu nombre",
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty ? "Ingresa tu nombre" : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _contactMessageCtrl,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: "Sugerencia",
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty ? "Escribe tu sugerencia" : null,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _sendMessage,
                              icon: const Icon(Icons.send),
                              label: const Text("Enviar mensaje"),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // --- Botón/Sección para el Libro de Reclamaciones ---
              Card(
                margin: const EdgeInsets.only(bottom: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "¿Tienes un reclamo o queja?",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const Divider(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showClaimForm = !_showClaimForm; // Alternar visibilidad
                          });
                        },
                        icon: Icon(_showClaimForm ? Icons.keyboard_arrow_up : Icons.menu_book),
                        label: Text(_showClaimForm ? "Ocultar Formulario de Reclamación" : "Abrir Libro de Reclamaciones"),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56), 
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                      ),
                      
                      // --- FORMULARIO DE LIBRO DE RECLAMACIONES (VISIBILIDAD CONTROLADA) ---
                      // El Formulario de Reclamaciones ahora está dentro de un Column condicional
                      // para que el linter detecte su uso.
                      if (_showClaimForm) 
                        Form( // El formulario de reclamaciones debe tener su propia clave
                          key: _claimFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 30),
                              const Text('Libro de Reclamaciones Virtual - Yachay Prompts', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                              const Divider(height: 30),

                              // --- SECCIÓN: IDENTIFICACIÓN DEL CONSUMIDOR ---
                              _buildSectionTitle('1. Identificación del Consumidor'),
                              // Nombre y Correo son siempre readOnly, asumimos que siempre están en UserApp
                              _buildReadOnlyTextField(
                                  controller: _consumerNameCtrl,
                                  label: 'Nombre Completo',
                                  value: _currentUserApp!.name, 
                                  isRequired: true),
                              _buildReadOnlyTextField(
                                  controller: _consumerEmailCtrl,
                                  label: 'Correo Electrónico',
                                  value: _currentUserApp!.email, 
                                  isRequired: true),
                              
                              // Número de Celular: Precargado si existe en el perfil, editable si está vacío.
                              _buildEditableOrReadOnlyTextField(
                                  controller: _consumerPhoneCtrl,
                                  label: 'Número de Celular',
                                  value: _currentUserApp!.numeroCelular ?? '', 
                                  keyboardType: TextInputType.phone,
                                  isRequired: true),
                              
                              // Tipo de Documento: Siempre 'DNI' por defecto y de solo lectura.
                              _buildDropdownFormField(
                                label: 'Tipo de Documento',
                                value: _consumerDocTypeCtrl.text, // Usa el valor precargado 'DNI'
                                items: _docTypes, 
                                onChanged: (value) => setState(() => _consumerDocTypeCtrl.text = value!),
                                validator: (value) => value == null || value.isEmpty ? 'Selecciona tipo de documento' : null,
                                isRequired: true,
                                readOnly: true, // Siempre de solo lectura
                              ),
                              // Número de Documento: Precargado con el DNI/CE/RUC registrado y de solo lectura.
                              _buildReadOnlyTextField( 
                                  controller: _consumerDocNumCtrl,
                                  label: 'Número de Documento',
                                  value: _currentUserApp!.dni ?? '', // Precarga el DNI registrado
                                  isRequired: true),

                              // Dirección (Calle, Av.): Precargado si existe en el perfil, editable si está vacío.
                              _buildEditableOrReadOnlyTextField( 
                                  controller: _consumerAddressCtrl,
                                  label: 'Dirección (Calle, Av. etc.)',
                                  value: _currentUserApp!.fullAddress ?? '', // Precarga de fullAddress
                                  isRequired: true),
                              
                              // Departamento: Precargado si existe en el perfil, editable si está vacío.
                              _buildEditableOrReadOnlyTextField( 
                                  controller: _consumerDeptCtrl,
                                  label: 'Departamento',
                                  value: _currentUserApp!.department ?? '', // Precarga de department
                                  isRequired: true),
                              // Provincia: Precargado si existe en el perfil, editable si está vacío.
                              _buildEditableOrReadOnlyTextField( 
                                  controller: _consumerProvCtrl,
                                  label: 'Provincia',
                                  value: _currentUserApp!.province ?? '', // Precarga de province
                                  isRequired: true),
                              
                              // Distrito (Ciudad de Registro): Precargado de 'ciudadResidencia' y de solo lectura.
                              _buildReadOnlyTextField( 
                                  controller: _consumerDistCtrl,
                                  label: 'Distrito o Ciudad',
                                  value: _currentUserApp!.ciudadResidencia ?? '', 
                                  isRequired: true),
                              
                              const SizedBox(height: 20),

                              // --- SECCIÓN: IDENTIFICACIÓN DEL BIEN CONTRATADO ---
                              _buildSectionTitle('2. Identificación del Producto o Servicio'),
                              _buildDropdownFormField(
                                label: 'Tipo de Bien Contratado',
                                value: _selectedGoodsType,
                                items: _goodsTypes,
                                onChanged: (value) => setState(() => _selectedGoodsType = value!),
                                validator: (value) => value == null ? 'Selecciona tipo de bien' : null,
                                isRequired: true,
                              ),
                              _buildTextField(
                                  controller: _productDescCtrl,
                                  label: 'Descripción del Bien/Servicio (detalles de la suscripción, etc.)',
                                  maxLines: 3,
                                  isRequired: true),
                              _buildTextField(
                                  controller: _productAmountCtrl,
                                  label: 'Monto Reclamado (Opcional)',
                                  keyboardType: TextInputType.number,
                                  isRequired: false),
                              _buildDateField(
                                  controller: _productDateCtrl,
                                  label: 'Fecha de Adquisición/Transacción (Opcional)',
                                  isRequired: false),
                              
                              const SizedBox(height: 20),

                              // --- SECCIÓN: DETALLE DEL RECLAMO O QUEJA ---
                              _buildSectionTitle('3. Detalle del Reclamo o Queja'),
                              _buildDropdownFormField(
                                label: 'Tipo de Solicitud',
                                value: _selectedClaimType,
                                items: _claimTypes, 
                                onChanged: (value) => setState(() => _selectedClaimType = value!),
                                validator: (value) => value == null ? 'Selecciona tipo de solicitud' : null,
                                isRequired: true,
                              ),
                              _buildTextField(
                                  controller: _claimDescriptionCtrl,
                                  label: 'Descripción detallada de los hechos',
                                  maxLines: 5,
                                  isRequired: true),
                              _buildTextField(
                                  controller: _consumerRequestCtrl,
                                  label: 'Pedido del Consumidor (¿Qué solución esperas?)',
                                  maxLines: 3,
                                  isRequired: true),
                              
                              const SizedBox(height: 20),

                              // --- MECANISMOS DE CONFORMIDAD ---
                              Row(
                                children: [
                                  Checkbox(
                                    value: _agreedToTerms,
                                    onChanged: (bool? newValue) {
                                      setState(() {
                                        _agreedToTerms = newValue!;
                                      });
                                    },
                                  ),
                                  const Expanded(
                                    child: Text(
                                      'Declaro que la información proporcionada es verídica y completa.',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Botón de envío
                              _isSendingClaim
                                  ? const Center(child: CircularProgressIndicator())
                                  : ElevatedButton.icon(
                                      onPressed: _submitReclamacion, 
                                      icon: const Icon(Icons.send),
                                      label: const Text('Enviar Reclamación'),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(double.infinity, 50),
                                      ),
                                    ),
                              const SizedBox(height: 50) , // Espacio al final
                            ],
                          ),
                        ),
                                        ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } // <--- ESTA ES LA LLAVE QUE CIERRA EL MÉTODO build
} // <--- ESTA ES LA LLAVE QUE CIERRA LA CLASE _SupportContactPageState