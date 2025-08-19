// Archivo: lib/pages/my_profile_page.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:yachay_prompts/auth/auth_service.dart';
import 'package:yachay_prompts/models/user_model.dart';


class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  UserApp? _currentUserApp;
  bool _isLoading = true;
  // bool _isUploadingPhoto = false; // Puedes eliminar este estado si el CircularProgressIndicator en Stack es suficiente
  bool _isSavingTheme = false;
  Color? _selectedThemeColor;
  Color? _initialThemeColor;

  final Color _defaultAppColor = const Color(0xFF673AB7); // Morado por defecto

  late final List<Color> _availableColors;

  @override
  void initState() {
    super.initState();
    _availableColors = [
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      _defaultAppColor, // Ahora sí se puede usar aquí.
    ];
    _loadUserProfile();
  }

  Color _colorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF$hexColor";
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          setState(() {
            _currentUserApp = UserApp.fromFirestore(doc);
            if (_currentUserApp!.preferredColor != null && _currentUserApp!.preferredColor!.isNotEmpty) {
              try {
                _selectedThemeColor = _colorFromHex(_currentUserApp!.preferredColor!);
                _initialThemeColor = _selectedThemeColor;
              } catch (e) {
                // En caso de que el color en Firestore sea inválido, usa el por defecto
                _selectedThemeColor = _defaultAppColor;
                _initialThemeColor = _defaultAppColor;
                _showSnackBar('Error al leer color guardado. Usando color por defecto.', isError: true);
              }
            } else {
              _selectedThemeColor = _defaultAppColor;
              _initialThemeColor = _defaultAppColor;
            }
          });
        } else {
          // ¡CORREGIDO! Si el documento no existe, inicializa UserApp con valores por defecto
          // y el color por defecto, para evitar nulls y que el tema se aplique.
          setState(() {
            _currentUserApp = UserApp(
              uid: user.uid,
              email: user.email ?? 'email_no_disponible@example.com',
              name: user.displayName ?? 'Usuario Nuevo',
              role: 'docente', // O un rol por defecto
              preferredColor: _colorToHex(_defaultAppColor), // Establece el color por defecto
            );
            _selectedThemeColor = _defaultAppColor;
            _initialThemeColor = _defaultAppColor;
          });
          _showSnackBar('No se encontraron datos de perfil. Perfil inicializado.', isError: false);
          // Opcional: Podrías guardar este perfil básico en Firestore aquí para que exista
          // await FirebaseFirestore.instance.collection('users').doc(user.uid).set(_currentUserApp!.toFirestore());
        }
      } else {
        _showSnackBar('Usuario no autenticado.', isError: true);
        setState(() {
          _currentUserApp = null;
        });
      }
    } catch (e) {
      _showSnackBar('Error al cargar el perfil: $e', isError: true);
      setState(() {
        _currentUserApp = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


Future<void> _pickAndUploadImage() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  // NO ES NECESARIO verificar _currentUserApp!.dni aquí si user.uid se usa para la ruta de Storage.
  // Si el DNI es un campo obligatorio para cualquier otra acción, debe validarse en su lugar apropiado.

  final picker = ImagePicker();
  final picked = await picker.pickImage(source: ImageSource.gallery);
  if (picked == null) return;

  File imageFile = File(picked.path);

  // Ruta en Firebase Storage: profile_pictures/{user.uid}/profile.jpg
  final storageRef = FirebaseStorage.instance
      .ref()
      .child('profile_pictures') // Carpeta principal para todas las fotos de perfil
      .child(user.uid)           // Subcarpeta única para cada usuario (usando su UID)
      .child('profile.jpg');     // Nombre fijo para el archivo, así siempre se sobrescribe el anterior

  try {
    // setState(() { _isUploadingPhoto = true; }); // Si quieres mostrar un indicador de carga específico para la foto

    await storageRef.putFile(imageFile);
    final String downloadUrl = await storageRef.getDownloadURL();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'profilePictureUrl': downloadUrl});

    // Actualizar la URL de la foto de perfil directamente en la cuenta de Firebase Auth (opcional pero bueno)
    await user.updatePhotoURL(downloadUrl);
    await user.reload(); // Recargar el usuario para que los cambios se reflejen

    if (mounted) {
      setState(() {
        _currentUserApp = _currentUserApp!.copyWith(
          profilePictureUrl: downloadUrl,
        );
      });
      _showSnackBar("Foto de perfil actualizada exitosamente.");
      // AuthService().reloadUserFromFirestore(); // Si tu AuthService maneja una copia observable del usuario
    }
  } catch (e) {
    if (!mounted) return;
    String errorMessage = "Error al subir foto: $e";
    if (e is FirebaseException && e.plugin == "firebase_storage") {
      errorMessage = "Error de Storage: ${e.message ?? 'Permiso denegado o error desconocido.'}";
    }
    _showSnackBar(errorMessage, isError: true);
  } finally {
    // setState(() { _isUploadingPhoto = false; }); // Si usas el estado de carga
  }
}


  Future<void> _saveThemeColor() async {
    setState(() {
      _isSavingTheme = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _selectedThemeColor != null) {
        final hexColor = _colorToHex(_selectedThemeColor!);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'preferredColor': hexColor});

        setState(() {
          _initialThemeColor = _selectedThemeColor;
          _currentUserApp = _currentUserApp!.copyWith(
            preferredColor: hexColor,
          );
        });

        _showSnackBar('Color del tema guardado exitosamente.');

        AuthService().reloadUserFromFirestore(); // LLAMADA CLAVE AQUÍ
      }
    } catch (e) {
      _showSnackBar('Error al guardar el color del tema: $e', isError: true);
    } finally {
      setState(() {
        _isSavingTheme = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildProfileRow(String label, String? value) {
    if (value == null || value == 'N/A' || value == 'Ninguno' || value.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialtiesChips(String label, List<String>? specialties) {
    if (specialties == null || specialties.isEmpty) {
      return const SizedBox.shrink();
    }
    final validSpecialties = specialties.where((s) => s.isNotEmpty && s != 'N/A' && s != 'Ninguno').toList();
    if (validSpecialties.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 6.0,
              runSpacing: 6.0,
              children: validSpecialties.map((specialty) => Chip(
                          label: Text(specialty),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
            ),
          ),
        ],
      ),
    );
  }

  bool get _isApplyButtonEnabled {
    return _selectedThemeColor != null &&
           _initialThemeColor != null &&
           _selectedThemeColor!.toARGB32() != _initialThemeColor!.toARGB32();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_currentUserApp == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi Perfil')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No se pudo cargar el perfil del usuario. Asegúrate de que el usuario esté autenticado y tenga un documento en Firestore.'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadUserProfile,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección de Foto de Perfil
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 80,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _currentUserApp!.profilePictureUrl != null &&
                        _currentUserApp!.profilePictureUrl!.isNotEmpty
                        ? NetworkImage(_currentUserApp!.profilePictureUrl!)
                        : null,
                    child: _currentUserApp!.profilePictureUrl == null ||
                            _currentUserApp!.profilePictureUrl!.isEmpty
                        ? Icon(
                            Icons.person,
                            size: 100,
                            color: Colors.grey[600],
                          )
                        : null,
                  ),
                  // if (_isUploadingPhoto) // Si usas el estado de carga _isUploadingPhoto
                  //   const Positioned.fill(
                  //     child: Center(
                  //       child: CircularProgressIndicator(),
                  //     ),
                  //   ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: FloatingActionButton.small(
                      onPressed: _pickAndUploadImage,
                      heroTag: 'changePhotoBtn',
                      child: const Icon(Icons.camera_alt),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sección de Datos Personales
            const Text(
              'Datos Personales',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildProfileRow('Nombre Completo', _currentUserApp!.name),
            _buildProfileRow('Apellido Paterno', _currentUserApp!.paternalLastName),
            _buildProfileRow('Apellido Materno', _currentUserApp!.maternalLastName),
            _buildProfileRow('Correo Electrónico', _currentUserApp!.email),
            _buildProfileRow('Rol', _currentUserApp!.role),
            _buildProfileRow('Años de Servicio', _currentUserApp!.anosDeServicio != null && _currentUserApp!.anosDeServicio! > 0 ? _currentUserApp!.anosDeServicio.toString() : 'N/A'),
            _buildProfileRow('Especialidad Principal', _currentUserApp!.especialidadPrincipal),
            _buildProfileRow('Especialidad Secundaria', _currentUserApp!.especialidadSecundaria),
            _buildSpecialtiesChips('Otras Especialidades', _currentUserApp!.otrasEspecialidades),
            _buildProfileRow('Número de Celular', _currentUserApp!.numeroCelular),
            _buildProfileRow('Ciudad de Residencia', _currentUserApp!.ciudadResidencia),
            _buildProfileRow('Nacionalidad', _currentUserApp!.nacionalidad),
            const SizedBox(height: 24),

            // Sección de Suscripción
            const Text(
              'Suscripción',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
                        const Divider(),
            _buildProfileRow('Plan Contratado', _currentUserApp!.planContratado),
            _buildProfileRow('Días Restantes', _currentUserApp!.diasRestantes?.toString() ?? '0'),
            _buildProfileRow('Prompts Totales (Plan)', _currentUserApp!.promptsContratados?.toString() ?? '0'),
            _buildProfileRow('Texto Restante', _currentUserApp!.promptsRestantes?.toString() ?? '0'),
            _buildProfileRow('Imagen Restante', _currentUserApp!.imagenesRestantes?.toString() ?? '0'),
            const SizedBox(height: 24),
            const Text(
              'Adicionales',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildProfileRow('Paquete Prompt Docente', _currentUserApp!.promptsPaqueteDocenteRestantes?.toString() ?? '0'),
            _buildProfileRow('Paquete Prompt Creativo', _currentUserApp!.promptsPaqueteCreativoRestantes?.toString() ?? '0'),
            _buildProfileRow('Vigencia Paquetes', 'NO CADUCA'),
            const SizedBox(height: 24),


            // Sección de Personalización de Interfaz (Color del Tema)
            const Text(
              'Personalización de Interfaz',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Color Principal del Tema:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10.0,
              runSpacing: 10.0,
              children: _availableColors.map((color) {
                final isSelected = _selectedThemeColor == color;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedThemeColor = color;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isSelected ? 50 : 40,
                    height: isSelected ? 50 : 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.transparent,
                        width: 2.0,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedThemeColor = _defaultAppColor;
                      });
                    },
                    child: const Text('Restablecer a color por defecto'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isApplyButtonEnabled && !_isSavingTheme
                        ? _saveThemeColor
                        : null,
                    child: _isSavingTheme
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          )
                        : const Text('Aplicar Color'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}