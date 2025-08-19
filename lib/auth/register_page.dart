// Archivo: lib/auth/register_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';
import 'package:yachay_prompts/auth/verify_email_view.dart';
import 'package:yachay_prompts/auth/login_page.dart';
import 'package:yachay_prompts/auth/auth_service.dart';
import 'package:yachay_prompts/models/user_model.dart'; // Asegúrate de que UserApp esté aquí


/// Pantalla de registro para Docentes en Yachay Prompts.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _dniController;
  late final TextEditingController _nombresController;
  late final TextEditingController _apellidoPaternoController;
  late final TextEditingController _apellidoMaternoController;
  late final TextEditingController _fechaNacimientoController;
  late final TextEditingController _ciudadController;
  late final TextEditingController _especialidadController; // Especialidad Principal
  late final TextEditingController _cargoController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;

  // ¡NUEVOS CONTROLADORES PARA CAMPOS ADICIONALES DEL FORMULARIO!
  late final TextEditingController _nacionalidadController;
  late final TextEditingController _anosDeServicioController;
  late final TextEditingController _especialidadSecundariaController;
  late final TextEditingController _otrasEspecialidadesController; // Para "Otras Especialidades"

  PhoneNumber? _celularPhoneNumber;

  bool _isRegistering = false;
  bool _isConsultandoDni = false;

  bool _dniBloqueado = false;
  bool _nombresBloqueado = false;
  bool _apellidoPaternoBloqueado = false;
  bool _apellidoMaternoBloqueado = false;

  @override
  void initState() {
    super.initState();
    _dniController = TextEditingController();
    _nombresController = TextEditingController();
    _apellidoPaternoController = TextEditingController();
    _apellidoMaternoController = TextEditingController();
    _fechaNacimientoController = TextEditingController();
    _ciudadController = TextEditingController();
    _especialidadController = TextEditingController();
    _cargoController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();

    // Inicialización de los NUEVOS CONTROLADORES
    _nacionalidadController = TextEditingController();
    _anosDeServicioController = TextEditingController();
    _especialidadSecundariaController = TextEditingController();
    _otrasEspecialidadesController = TextEditingController();

    _dniController.addListener(_onDniChanged);
  }

  @override
  void dispose() {
    _dniController.removeListener(_onDniChanged);
    _dniController.dispose();
    _nombresController.dispose();
    _apellidoPaternoController.dispose();
    _apellidoMaternoController.dispose();
    _fechaNacimientoController.dispose();
    _ciudadController.dispose();
    _especialidadController.dispose();
    _cargoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    // Disponer los NUEVOS CONTROLADORES
    _nacionalidadController.dispose();
    _anosDeServicioController.dispose();
    _especialidadSecundariaController.dispose();
    _otrasEspecialidadesController.dispose();

    super.dispose();
  }

  void _onDniChanged() {
    if (_dniBloqueado ||
        _nombresBloqueado ||
        _apellidoPaternoBloqueado ||
        _apellidoMaternoBloqueado) {
      _resetearBloqueoCamposDNI();
    }
  }

  void _resetearBloqueoCamposDNI() {
    if (mounted) {
      setState(() {
        _dniBloqueado = false;
        _nombresBloqueado = false;
        _apellidoPaternoBloqueado = false;
        _apellidoMaternoBloqueado = false;
      });
    }
  }

  Future<void> _consultarDniDocente() async {
    final dni = _dniController.text.trim();
    if (dni.length != 8 || !RegExp(r'^\d{8}$').hasMatch(dni)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un DNI válido de 8 dígitos.')),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isConsultandoDni = true;
        _resetearBloqueoCamposDNI();
      });
    }

    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('consultarDNI');
      final HttpsCallableResult result = await callable
          .call<Map<String, dynamic>>({'dni': dni});
      final data = result.data;

      if (mounted) {
        if (data != null && data['nombres'] != null) {
          _nombresController.text = data['nombres'] ?? '';
          _apellidoPaternoController.text = data['apellidoPaterno'] ?? '';
          _apellidoMaternoController.text = data['apellidoMaterno'] ?? '';

          setState(() {
            _dniBloqueado = true;
            _nombresBloqueado = _nombresController.text.isNotEmpty;
            _apellidoPaternoBloqueado =
                _apellidoPaternoController.text.isNotEmpty;
            _apellidoMaternoBloqueado =
                _apellidoMaternoController.text.isNotEmpty;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Datos de DNI cargados.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se encontraron datos para el DNI. Ingresa manualmente.',
              ),
            ),
          );
        }
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) {
        return;
      }
      String message;
      if (e.code == 'not-found') {
        message = 'DNI no encontrado o no disponible.';
      } else if (e.code == 'unauthenticated') {
        message =
            'Error de autenticación con el servicio DNI (token API inválido).';
      } else if (e.code == 'invalid-argument') {
        message = 'DNI inválido o formato incorrecto para la consulta.';
      } else if (e.code == 'resource-exhausted') {
        message = 'Límite de consultas DNI excedido. Intenta más tarde.';
      } else {
        message =
            'Error al consultar DNI: ${e.message ?? 'Error desconocido'}.';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (ex) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ocurrió un error inesperado al consultar DNI: ${ex.toString()}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isConsultandoDni = false);
      }
    }
  }

  Future<void> _tryRegister() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, corrige los errores del formulario.'),
        ),
      );
      return;
    }

    if (_celularPhoneNumber == null || _celularPhoneNumber!.number.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresa un número de celular válido.'),
        ),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden.')),
      );
      return;
    }

    if (mounted) {
      setState(() => _isRegistering = true);
    }

    // Datos obtenidos de los controladores
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final dni = _dniController.text.trim(); // DNI obtenido del campo
    final nombres = _nombresController.text.trim();
    final apellidoPaterno = _apellidoPaternoController.text.trim();
    final apellidoMaterno = _apellidoMaternoController.text.trim();
    final fechaNacimiento = _fechaNacimientoController.text.trim();
    final ciudad = _ciudadController.text.trim();
    final especialidad = _especialidadController.text.trim();
    final cargo = _cargoController.text.trim();
    final celularCompleto = _celularPhoneNumber!.completeNumber;

    // ¡NUEVOS DATOS DE LOS CONTROLADORES!
    final nacionalidad = _nacionalidadController.text.trim();
    final anosDeServicio = int.tryParse(_anosDeServicioController.text.trim()); // Convertir a int
    final especialidadSecundaria = _especialidadSecundariaController.text.trim();
    final otrasEspecialidadesRaw = _otrasEspecialidadesController.text.trim();
    // Convertir la cadena de "otras especialidades" a una lista, separando por comas
    List<String> otrasEspecialidadesList = otrasEspecialidadesRaw.isNotEmpty
        ? otrasEspecialidadesRaw.split(',').map((s) => s.trim()).toList()
        : ['Ninguna']; // Si está vacío, usar 'Ninguna'

    final String fullName = '$nombres $apellidoPaterno $apellidoMaterno'.trim();

    try {
      UserCredential userCredential = await AuthService().registerWithEmailAndPassword(
            name: fullName,
            email: email,
            password: password,
            role: 'Docente', // Rol por defecto
          );

      final user = userCredential.user;

      if (user != null) {
        if (_nombresController.text.trim().isNotEmpty) {
          await user.updateDisplayName(_nombresController.text.trim()); // Actualizar DisplayName con solo nombres
        }

        // Crear una instancia de tu UserApp con TODOS los datos del formulario Y VALORES AUTOMÁTICOS
        final newUserApp = UserApp(
          uid: user.uid,
          email: email,
          name: fullName,
          role: 'Docente', // Rol por defecto
          isActive: true,
          // ¡Campos llenados por el usuario!
          anosDeServicio: anosDeServicio ?? 0, // Usar el valor parseado, o 0 si falla
          especialidadPrincipal: especialidad.isNotEmpty ? especialidad : null,
          especialidadSecundaria: especialidadSecundaria.isNotEmpty ? especialidadSecundaria : 'Ninguna',
          otrasEspecialidades: otrasEspecialidadesList,
          numeroCelular: celularCompleto.isNotEmpty ? celularCompleto : null,
          ciudadResidencia: ciudad.isNotEmpty ? ciudad : null,
          nacionalidad: nacionalidad.isNotEmpty ? nacionalidad : 'Peruana', // Usar el valor del campo, o 'Peruana'
          
          // --- INICIO DE MODIFICACIÓN CLAVE: GUARDAR DNI Y TIPO DE DOCUMENTO ---
          dni: dni.isNotEmpty ? dni : null, // Guardar el DNI obtenido del formulario
          documentType: dni.isNotEmpty ? 'DNI' : null, // Asumir 'DNI' si el campo DNI se llenó
          cargo: cargo.isNotEmpty ? cargo : null, // AÑADIR ESTA LÍNEA
          paternalLastName: apellidoPaterno.isNotEmpty ? apellidoPaterno : null, // AÑADIR ESTA LÍNEA
          maternalLastName: apellidoMaterno.isNotEmpty ? apellidoMaterno : null, // AÑADIR ESTA LÍNEA
          // --- FIN DE MODIFICACIÓN CLAVE ---

          // ¡Campos llenados automáticamente con valores específicos para el plan DEMO!
          planContratado: 'demo', // Automático: 'demo' (minúsculas)
          diasRestantes: 7, // Automático: 7 días de prueba
          promptsContratados: 0, // El total contratado para el demo (puedes ajustar si es necesario)
          promptsRestantes: 5, // Créditos iniciales de prompts para el demo
          imagenesRestantes: 1, // Créditos iniciales de imágenes para el demo
          profilePictureUrl: null, // Automático: null
          preferredColor: '#FF673AB7', // Automático: color morado por defecto
        );

        // Guardar el nuevo documento del usuario en Firestore.
        // Se usa set para crear el documento con todos los campos de UserApp.
        // newUserApp.toFirestore() AHORA INCLUYE EL DNI Y DOCUMENTTYPE.
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(newUserApp.toFirestore());

        // --- INICIO DE MODIFICACIÓN: ELIMINAR EL UPDATE REDUNDANTE DE DNI ---
        // Este update ya no es necesario para 'dni' porque ya se incluyó en newUserApp.toFirestore()
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'fechaNacimiento': fechaNacimiento,
              'cargo': cargo, // Campo adicional del formulario
              'fechaRegistro': FieldValue.serverTimestamp(), // Automático: fecha del servidor
              'tipoUsuario': 'Docente', // Automático: 'docente'
            });
        // --- FIN DE MODIFICACIÓN ---


        // Enviar verificación de email si el correo no está verificado
        if (!user.emailVerified) {
          await user.sendEmailVerification();
        }

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const VerifyEmailView(),
            ),
            (Route<dynamic> route) => false,
          );
        }
      } else {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Error: Usuario Firebase no creado después del registro.',
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      String message;
      if (e.code == 'weak-password') {
        message = 'La contraseña es demasiado débil. Ingresa una más fuerte.';
      } else if (e.code == 'email-already-in-use') {
        message = 'El correo ya está en uso. Intenta iniciar sesión.';
      } else if (e.code == 'invalid-email') {
        message = 'El formato del correo electrónico es inválido.';
      } else {
        message = 'Error de registro: ${e.message ?? 'Error desconocido'}.';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (ex) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ocurrió un error inesperado: ${ex.toString()}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRegistering = false);
      }
    }
  }

  // --- Widgets Auxiliares de Formularios ---

  Widget _buildTextFieldWithSearch({
    required TextEditingController controller,
    required String label,
    required TextInputType keyboardType,
    required String? Function(String?) validator,
    required Future<void> Function() onSearchPressed,
    required bool isSearching,
    required bool isFieldLocked,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: isFieldLocked ? Colors.grey[200] : Colors.white,
          suffixIcon:
              isFieldLocked
                  ? null
                  : (isSearching
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(strokeWidth: 2.0),
                        ),
                      )
                      : IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: onSearchPressed,
                        tooltip: 'Consultar',
                      )),
        ),
        keyboardType: keyboardType,
        readOnly: isFieldLocked,
        validator: validator,
        maxLength: maxLength,
      ),
    );
  }

  Widget _buildNormalTextField({
    required TextEditingController controller,
    required String label,
    bool readOnly = false,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: readOnly ? Colors.grey[200] : Colors.white,
        ),
        readOnly: readOnly,
        validator: validator,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        obscureText: obscureText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro de Docente')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Crea tu Cuenta de Docente',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              // --- SECCIÓN: Datos Personales ---
              const Text(
                "Datos Personales",
                textAlign: TextAlign.left,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              _buildTextFieldWithSearch(
                controller: _dniController,
                label: 'DNI (8 dígitos)',
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Ingresa DNI';
                  }
                  if (v.length != 8 || !RegExp(r'^\d{8}$').hasMatch(v)) {
                    return 'DNI debe tener 8 dígitos numéricos';
                  }
                  return null;
                },
                onSearchPressed: _consultarDniDocente,
                isSearching: _isConsultandoDni,
                isFieldLocked: _dniBloqueado,
                maxLength: 8,
              ),

              _buildNormalTextField(
                controller: _nombresController,
                label: 'Nombres*',
                readOnly: _nombresBloqueado,
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Ingresa tus nombres';
                  }
                  return null;
                },
              ),
              _buildNormalTextField(
                controller: _apellidoPaternoController,
                label: 'Apellido Paterno*',
                readOnly: _apellidoPaternoBloqueado,
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Ingresa tu apellido paterno';
                  }
                  return null;
                },
              ),
              _buildNormalTextField(
                controller: _apellidoMaternoController,
                label: 'Apellido Materno*',
                readOnly: _apellidoMaternoBloqueado,
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Ingresa tu apellido materno';
                  }
                  return null;
                },
              ),

              // Campo de fecha de nacimiento con validación de formato DD/MM/AAAA
              _buildNormalTextField(
                controller: _fechaNacimientoController,
                label: 'Fecha de Nacimiento (DD/MM/AAAA)*',
                keyboardType: TextInputType.datetime,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Ingresa tu fecha de nacimiento';
                  }
                  final dateRegExp = RegExp(r'^\d{2}/\d{2}/\d{4}$');
                  if (!dateRegExp.hasMatch(v)) {
                    return 'Formato debe ser DD/MM/AAAA';
                  }
                  try {
                    final parts = v.split('/');
                    final day = int.parse(parts[0]);
                    final month = int.parse(parts[1]);
                    final year = int.parse(parts[2]);
                    final selectedDate = DateTime(year, month, day);

                    if (selectedDate.isAfter(DateTime.now())) {
                      return 'La fecha de nacimiento no puede ser futura';
                    }
                  } catch (e) {
                    return 'Fecha inválida';
                  }
                  return null;
                },
              ),

              _buildNormalTextField(
                controller: _ciudadController,
                label: 'Ciudad*',
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Ingresa tu ciudad';
                  }
                  return null;
                },
              ),
              // ¡NUEVO CAMPO: NACIONALIDAD!
              _buildNormalTextField(
                controller: _nacionalidadController,
                label: 'Nacionalidad*',
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Ingresa tu nacionalidad';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // --- SECCIÓN: Datos Profesionales ---
              const Text(
                "Datos Profesionales", // Título actualizado
                textAlign: TextAlign.left,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              _buildNormalTextField(
                controller: _especialidadController,
                label: 'Especialidad Principal*',
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Ingresa tu especialidad principal';
                  }
                  return null;
                },
              ),
              // ¡NUEVO CAMPO: ESPECIALIDAD SECUNDARIA!
              _buildNormalTextField(
                controller: _especialidadSecundariaController,
                label: 'Especialidad Secundaria*',
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Ingresa tu especialidad secundaria';
                  }
                  return null;
                },
              ),
              // ¡NUEVO CAMPO: OTRAS ESPECIALIDADES!
              _buildNormalTextField(
                controller: _otrasEspecialidadesController,
                label: 'Otras Especialidades (separar por comas, máx 5)*',
                textCapitalization: TextCapitalization.sentences, // Puede ser útil para listas
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Ingresa otras especialidades o "Ninguna"';
                  }
                  final specialtiesList = v.split(',').map((s) => s.trim()).toList();
                  if (specialtiesList.length > 5) {
                    return 'Máximo 5 especialidades';
                  }
                  return null;
                },
              ),
              _buildNormalTextField(
                controller: _cargoController,
                label: 'Cargo*',
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Ingresa tu cargo';
                  }
                  return null;
                },
              ),
              // ¡NUEVO CAMPO: AÑOS DE SERVICIO!
              _buildNormalTextField(
                controller: _anosDeServicioController,
                label: 'Años de Servicio*',
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Ingresa tus años de servicio';
                  }
                  if (int.tryParse(v) == null || int.parse(v) < 0) {
                    return 'Debe ser un número entero positivo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // --- SECCIÓN: Datos de Contacto y Cuenta ---
              const Text(
                "Datos de Contacto y Cuenta", // Título actualizado
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              IntlPhoneField(
                decoration: const InputDecoration(
                  labelText: 'Celular*',
                  border: OutlineInputBorder(borderSide: BorderSide()),
                ),
                languageCode: "es",
                initialCountryCode: 'PE',
                onChanged: (phone) {
                  _celularPhoneNumber = phone;
                },
                onCountryChanged: (country) {
                  // _selectedCountryName = country.name;
                },
                validator: (phoneNumber) {
                  if (phoneNumber == null || phoneNumber.number.isEmpty) {
                    return 'Ingresa un número de celular';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              _buildNormalTextField(
                controller: _emailController,
                label: 'Correo Electrónico (para iniciar sesión)*',
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Ingresa correo';
                  }
                  if (!v.contains('@') || !v.contains('.')) {
                    return 'Email inválido';
                  }
                  return null;
                },
              ),
              _buildNormalTextField(
                controller: _passwordController,
                label: 'Contraseña (mín. 6 caracteres)*',
                keyboardType: TextInputType.visiblePassword,
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Ingresa contraseña';
                  }
                  if (v.length < 6) {
                    return 'Mínimo 6 caracteres';
                  }
                  return null;
                },
              ),
              _buildNormalTextField(
                controller: _confirmPasswordController,
                label: 'Confirmar Contraseña*',
                keyboardType: TextInputType.visiblePassword,
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Confirma tu contraseña';
                  }
                  if (v != _passwordController.text) {
                    return 'Las contraseñas no coinciden';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24.0),
              ElevatedButton(
                onPressed: _isRegistering ? null : _tryRegister,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15.0),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child:
                    _isRegistering
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                        : const Text('Registrar Docente'),
              ),
              const SizedBox(height: 10.0),
              TextButton(
                onPressed: () {
                  if (mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  }
                },
                child: const Text('¿Ya tienes cuenta? Inicia sesión aquí'),
              ),
              const SizedBox(height: 50), // Espacio extra al final para scroll
            ],
          ),
        ),
      ),
    );
  }
}
